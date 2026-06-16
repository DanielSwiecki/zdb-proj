# Benchmark obciazeniowy: opoznienie (Y) vs liczba rownoczesnych uzytkownikow (X).
#
# Metodologia (zgodna z wykładem - pomiar pod ograniczeniem zasobow):
# - dyskretne poziomy obciazenia (kazdy poziom = dokladnie N rownoczesnych klientow)
# - timeouty liczone osobno (nie wliczane do sredniego opoznienia sukcesow)
# - 409 Conflict traktowane jako blad danych testowych, nie jako opoznienie
# - automatyczne zatrzymanie przy nasyceniu (timeouty / spadek skutecznosci)
#
# Wymaga: tools/benchmark_pairs.csv (prepare_benchmark_pairs.ps1)

param(
    [string]$BaseUrl = "http://localhost:8081",
    [string]$PairsFile = "",
    [string]$OutputFile = "",
    [int]$StartUsers = 10,
    [int]$StepUsers = 10,
    [int]$MaxUsers = 500,
    [int]$RequestsPerUser = 1,
    [int]$ConnectTimeoutSec = 5,
    [int]$ResponseTimeoutSec = 30,
    [int]$CooldownSec = 5,
    [double]$StopSuccessRateBelow = 85.0,
    [double]$StopTimeoutRateAbove = 15.0,
    [int]$StopP95AboveMs = 25000,
    [switch]$NoAutoStop
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $PairsFile) { $PairsFile = Join-Path $scriptDir "benchmark_pairs.csv" }
if (-not $OutputFile) { $OutputFile = Join-Path $scriptDir "benchmark_latency.csv" }

function Get-Percentile {
    param([double[]]$Values, [double]$Percentile)
    if ($Values.Count -eq 0) { return 0 }
    $sorted = $Values | Sort-Object
    $rank = [math]::Ceiling(($Percentile / 100.0) * $sorted.Count) - 1
    $rank = [math]::Max(0, [math]::Min($rank, $sorted.Count - 1))
    return [math]::Round($sorted[$rank], 2)
}

function Test-ApiAvailable {
    param([string]$Url)
    try {
        $r = Invoke-WebRequest -Uri "$Url/api/course-groups" -Method GET -TimeoutSec 10 -UseBasicParsing
        return $r.StatusCode -eq 200
    } catch {
        return $false
    }
}

# --- wczytanie par ---
if (-not (Test-Path $PairsFile)) {
    Write-Host "Brak $PairsFile - uruchamiam prepare_benchmark_pairs.ps1" -ForegroundColor Yellow
    & (Join-Path $scriptDir "prepare_benchmark_pairs.ps1") -OutputFile $PairsFile
}

$pairRows = Import-Csv $PairsFile
if ($pairRows.Count -eq 0) { throw "Plik par jest pusty: $PairsFile" }

$maxPossibleUsers = [math]::Floor($pairRows.Count / [math]::Max(1, $RequestsPerUser))
if ($MaxUsers -gt $maxPossibleUsers) {
    Write-Warning "MaxUsers obnizone z $MaxUsers do $maxPossibleUsers (limit unikalnych par)."
    $MaxUsers = $maxPossibleUsers
}

$levels = New-Object System.Collections.Generic.List[int]
for ($u = $StartUsers; $u -le $MaxUsers; $u += $StepUsers) { [void]$levels.Add($u) }
if ($levels.Count -eq 0 -or $levels[-1] -ne $MaxUsers) { [void]$levels.Add($MaxUsers) }

if (-not (Test-ApiAvailable $BaseUrl)) {
    throw "API niedostepne pod $BaseUrl. Uruchom: .\mvnw.cmd spring-boot:run"
}

[System.Net.ServicePointManager]::DefaultConnectionLimit = 20000
[System.Net.ServicePointManager]::Expect100Continue = $false

# --- worker C# dla HttpClient (lepsza kontrola timeoutow niz Invoke-RestMethod) ---
$workerSource = @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Net.Http;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

public sealed class EnrollWorker
{
    public sealed class RequestResult
    {
        public int StatusCode;
        public double ElapsedMs;
        public string ErrorKind; // success | timeout | conflict | error
    }

    public static RequestResult Execute(
        string baseUrl,
        string studentId,
        string groupId,
        int connectTimeoutSec,
        int responseTimeoutSec)
    {
        var sw = Stopwatch.StartNew();
        try
        {
            using (var handler = new HttpClientHandler())
            using (var client = new HttpClient(handler))
            {
                client.Timeout = TimeSpan.FromSeconds(responseTimeoutSec);
                var url = baseUrl.TrimEnd('/') + "/api/course-groups/" + groupId + "/enroll";
                var body = "{\"studentId\":\"" + studentId + "\"}";
                var content = new StringContent(body, Encoding.UTF8, "application/json");
                var cts = new CancellationTokenSource(TimeSpan.FromSeconds(responseTimeoutSec));
                var response = client.PostAsync(url, content, cts.Token).GetAwaiter().GetResult();
                sw.Stop();
                int code = (int)response.StatusCode;
                string kind;
                if (code >= 200 && code < 300) kind = "success";
                else if (code == 409) kind = "conflict";
                else kind = "error";
                return new RequestResult { StatusCode = code, ElapsedMs = sw.Elapsed.TotalMilliseconds, ErrorKind = kind };
            }
        }
        catch (TaskCanceledException)
        {
            if (sw.IsRunning) sw.Stop();
            return new RequestResult { StatusCode = 0, ElapsedMs = responseTimeoutSec * 1000.0, ErrorKind = "timeout" };
        }
        catch (Exception)
        {
            if (sw.IsRunning) sw.Stop();
            return new RequestResult { StatusCode = 0, ElapsedMs = sw.Elapsed.TotalMilliseconds, ErrorKind = "error" };
        }
    }

    public static RequestResult[] RunUser(
        string baseUrl,
        string studentId,
        string[] groupIds,
        int connectTimeoutSec,
        int responseTimeoutSec)
    {
        var results = new List<RequestResult>();
        foreach (var gid in groupIds)
        {
            results.Add(Execute(baseUrl, studentId, gid, connectTimeoutSec, responseTimeoutSec));
        }
        return results.ToArray();
    }
}
'@

Add-Type -TypeDefinition $workerSource -Language CSharp -ErrorAction SilentlyContinue

# --- naglowek CSV ---
$header = [pscustomobject]@{
    ConcurrentUsers = "ConcurrentUsers"
    TotalRequests = "TotalRequests"
    Successful = "Successful"
    Timeouts = "Timeouts"
    Conflicts409 = "Conflicts409"
    OtherErrors = "OtherErrors"
    SuccessRatePct = "SuccessRatePct"
    TimeoutRatePct = "TimeoutRatePct"
    AvgLatencyMs = "AvgLatencyMs"
    P50LatencyMs = "P50LatencyMs"
    P95LatencyMs = "P95LatencyMs"
    P99LatencyMs = "P99LatencyMs"
    MaxLatencyMs = "MaxLatencyMs"
    ThroughputRps = "ThroughputRps"
    DurationSec = "DurationSec"
    Note = "Note"
}
$header | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1 | Out-File -FilePath $OutputFile -Encoding UTF8

Write-Host "============================================================"
Write-Host "  BENCHMARK: opoznienie vs rownoczesni uzytkownicy"
Write-Host "============================================================"
Write-Host "API:              $BaseUrl"
Write-Host "Pary testowe:     $($pairRows.Count) (plik: $PairsFile)"
Write-Host "Poziomy (X):      $($levels -join ', ')"
Write-Host "Zadania/uzytk.:   $RequestsPerUser"
Write-Host "Timeout odp.:     ${ResponseTimeoutSec}s (timeouty osobno na wykresie)"
Write-Host "Docker Postgres:  limit 2GB RAM (docker-compose.yml)"
Write-Host "Wynik (wykres):   $OutputFile"
Write-Host "  Oś X -> ConcurrentUsers"
Write-Host "  Oś Y -> P95LatencyMs (lub AvgLatencyMs)"
Write-Host "============================================================`n"

$pairIndex = 0
$saturationFound = $false

foreach ($users in $levels) {
    $totalReq = $users * $RequestsPerUser
    if ($pairIndex + $totalReq -gt $pairRows.Count) {
        Write-Warning "Skonczyly sie unikalne pary na poziomie $users. Koniec testu."
        break
    }

    Write-Host "-> $users rownoczesnych uzytkownikow ($totalReq zadan)..." -NoNewline

    $workItems = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt $users; $i++) {
        $baseIdx = $pairIndex + ($i * $RequestsPerUser)
        $studentId = $pairRows[$baseIdx].studentId
        $groupIds = New-Object System.Collections.Generic.List[string]
        for ($r = 0; $r -lt $RequestsPerUser; $r++) {
            [void]$groupIds.Add($pairRows[$baseIdx + $r].groupId)
        }
        [void]$workItems.Add([pscustomobject]@{ StudentId = $studentId; GroupIds = [string[]]$groupIds.ToArray() })
    }
    $pairIndex += $totalReq

    $levelStart = Get-Date
    $tasks = New-Object System.Collections.Generic.List[System.Threading.Tasks.Task[object]]]

    foreach ($item in $workItems) {
        $t = [System.Threading.Tasks.Task]::Run({
            param($b, $sid, $gids, $cts, $rts)
            $results = [EnrollWorker]::RunUser($b, $sid, $gids, $cts, $rts)
            return ,$results
        }, $BaseUrl, $item.StudentId, $item.GroupIds, $ConnectTimeoutSec, $ResponseTimeoutSec)
        [void]$tasks.Add($t)
    }

    [System.Threading.Tasks.Task]::WaitAll($tasks.ToArray())
    $durationSec = ((Get-Date) - $levelStart).TotalSeconds

    $successLatencies = New-Object System.Collections.Generic.List[double]
    $success = 0; $timeouts = 0; $conflicts = 0; $other = 0

    foreach ($t in $tasks) {
        foreach ($res in $t.Result) {
            switch ($res.ErrorKind) {
                "success" { $success++; [void]$successLatencies.Add([double]$res.ElapsedMs) }
                "timeout" { $timeouts++ }
                "conflict" { $conflicts++ }
                default { $other++ }
            }
        }
    }

    $successRate = if ($totalReq -gt 0) { [math]::Round(100.0 * $success / $totalReq, 2) } else { 0 }
    $timeoutRate = if ($totalReq -gt 0) { [math]::Round(100.0 * $timeouts / $totalReq, 2) } else { 0 }
    $latArr = [double[]]$successLatencies.ToArray()
    $avg = if ($latArr.Count -gt 0) { [math]::Round(($latArr | Measure-Object -Average).Average, 2) } else { 0 }
    $p50 = Get-Percentile -Values $latArr -Percentile 50
    $p95 = Get-Percentile -Values $latArr -Percentile 95
    $p99 = Get-Percentile -Values $latArr -Percentile 99
    $max = if ($latArr.Count -gt 0) { [math]::Round(($latArr | Measure-Object -Maximum).Maximum, 2) } else { 0 }
    $rps = if ($durationSec -gt 0) { [math]::Round($success / $durationSec, 2) } else { 0 }

    $note = ""
    if (-not $NoAutoStop) {
        if ($timeoutRate -ge $StopTimeoutRateAbove) { $note = "SATURACJA: timeouty >= ${StopTimeoutRateAbove}%" }
        elseif ($successRate -lt $StopSuccessRateBelow) { $note = "SATURACJA: skutecznosc < ${StopSuccessRateBelow}%" }
        elseif ($p95 -ge $StopP95AboveMs) { $note = "SATURACJA: P95 >= ${StopP95AboveMs}ms" }
    }

    [pscustomobject]@{
        ConcurrentUsers = $users
        TotalRequests = $totalReq
        Successful = $success
        Timeouts = $timeouts
        Conflicts409 = $conflicts
        OtherErrors = $other
        SuccessRatePct = $successRate
        TimeoutRatePct = $timeoutRate
        AvgLatencyMs = $avg
        P50LatencyMs = $p50
        P95LatencyMs = $p95
        P99LatencyMs = $p99
        MaxLatencyMs = $max
        ThroughputRps = $rps
        DurationSec = [math]::Round($durationSec, 2)
        Note = $note
    } | Export-Csv -Path $OutputFile -NoTypeInformation -Append -Encoding UTF8

    Write-Host ("  P50={0}ms P95={1}ms | sukces={2}% timeout={3}% | {4}" -f $p50, $p95, $successRate, $timeoutRate, $(if ($note) { $note } else { "OK" }))

    if ($note -like "SATURACJA*") {
        $saturationFound = $true
        Write-Host "`nPunkt nasycenia osiagniety przy $users uzytkownikach. Koniec testu." -ForegroundColor Yellow
        break
    }

    if ($users -lt $levels[-1]) {
        Start-Sleep -Seconds $CooldownSec
    }
}

Write-Host "`n============================================================"
Write-Host "  ZAKONCZONO"
Write-Host "  Plik do wykresu: $OutputFile"
Write-Host "  Excel: wykres liniowy, X=ConcurrentUsers, Y=P95LatencyMs"
if ($saturationFound) {
    Write-Host "  Ostatni wiersz z 'SATURACJA' = szacowana granica obciazenia systemu"
}
Write-Host "============================================================"
