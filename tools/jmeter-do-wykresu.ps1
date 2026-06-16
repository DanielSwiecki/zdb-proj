# Zamienia wynik JMeter (JTL/CSV) na czytelny raport + plik pod wykres.
#
# Tryb Wyklad:
#   label w JTL = liczba userow (10, 25, 50...)
#   wykres_wyklad.csv     - kolumny pod Excel (X/Y)
#   benchmark_jmeter.csv  - pelny raport jak benchmark_latency.csv
#
# Uzycie:
#   .\tools\jmeter-do-wykresu.ps1 -InputFile wyniki_wyklad.jtl -Mode Wyklad -ShowTable

param(
    [string]$InputFile = "",
    [string]$OutputFile = "",
    [string]$ReportFile = "",
    [ValidateSet("Wyklad", "Stepping")]
    [string]$Mode = "Stepping",
    [int]$MinSamples = 30,
    [int]$StepSize = 25,
    [switch]$ShowTable,
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $root

if (-not $InputFile) {
    $InputFile = if ($Mode -eq "Wyklad") {
        Join-Path $projectRoot "wyniki_wyklad.jtl"
    } else {
        Join-Path $projectRoot "wyniki_zalamania.csv"
    }
}
if (-not $OutputFile) {
    $OutputFile = Join-Path $root "wykres_wyklad.csv"
}
if (-not $ReportFile) {
    $ReportFile = Join-Path $root "benchmark_jmeter.csv"
}

function Get-Percentile {
    param([double[]]$Values, [double]$Percentile)
    if ($Values.Count -eq 0) { return 0 }
    $sorted = $Values | Sort-Object
    $rank = [math]::Ceiling(($Percentile / 100.0) * $sorted.Count) - 1
    $rank = [math]::Max(0, [math]::Min($rank, $sorted.Count - 1))
    return [math]::Round($sorted[$rank], 2)
}

function Get-JmeterSampleKind {
    param([object]$Row)
    if ($Row.success -eq "true") { return "success" }
    $code = "$($Row.responseCode)".Trim()
    if ($code -eq "409") { return "conflict" }
    if ($code -in @("408", "504", "502", "503")) { return "timeout" }
    if ([string]::IsNullOrWhiteSpace($code)) { return "timeout" }
    return "other"
}

function Measure-JmeterWykladLevels {
    param(
        [object[]]$Rows,
        [int]$MinSamples = 30
    )

    $results = New-Object System.Collections.Generic.List[object]
    $grouped = $Rows | Where-Object { $_.label -match '^\d+$' } | Group-Object label | Sort-Object { [int]$_.Name }

    foreach ($g in $grouped) {
        $users = [int]$g.Name
        $okMs = New-Object System.Collections.Generic.List[double]
        $ok = 0; $timeouts = 0; $conflicts = 0; $other = 0
        $tsMin = [long]::MaxValue
        $tsMax = 0L

        foreach ($r in $g.Group) {
            $ts = 0L
            if ([long]::TryParse("$($r.timeStamp)", [ref]$ts)) {
                if ($ts -lt $tsMin) { $tsMin = $ts }
                if ($ts -gt $tsMax) { $tsMax = $ts }
            }

            switch (Get-JmeterSampleKind -Row $r) {
                "success" {
                    $ok++
                    [void]$okMs.Add([double]$r.elapsed)
                }
                "conflict" { $conflicts++ }
                "timeout"  { $timeouts++ }
                default    { $other++ }
            }
        }

        $total = $ok + $timeouts + $conflicts + $other
        if ($total -lt $MinSamples) { continue }

        $okArr = [double[]]$okMs.ToArray()
        $avg = if ($okArr.Count -gt 0) { [math]::Round(($okArr | Measure-Object -Average).Average, 2) } else { 0 }
        $p50 = Get-Percentile -Values $okArr -Percentile 50
        $p95 = Get-Percentile -Values $okArr -Percentile 95
        $p99 = Get-Percentile -Values $okArr -Percentile 99
        $max = if ($okArr.Count -gt 0) { [math]::Round(($okArr | Measure-Object -Maximum).Maximum, 2) } else { 0 }
        $durationSec = if ($tsMin -lt [long]::MaxValue -and $tsMax -gt $tsMin) {
            [math]::Round(($tsMax - $tsMin) / 1000.0, 2)
        } else { 0 }
        $rps = if ($durationSec -gt 0) { [math]::Round($ok / $durationSec, 2) } else { 0 }
        $successRate = if ($total -gt 0) { [math]::Round(100.0 * $ok / $total, 2) } else { 0 }

        $note = ""
        if ($successRate -lt 100) {
            if ($timeouts -gt 0) { $note = "timeouty: $timeouts" }
            elseif ($other -gt 0) { $note = "bledy: $other" }
            elseif ($conflicts -gt 0) { $note = "409: $conflicts" }
        }

        [void]$results.Add([pscustomobject]@{
            ConcurrentUsers = $users
            TotalRequests   = $total
            Successful      = $ok
            Timeouts        = $timeouts
            Conflicts409    = $conflicts
            OtherErrors     = $other
            SuccessRatePct  = $successRate
            AvgLatencyMs    = $avg
            P50LatencyMs    = $p50
            P95LatencyMs    = $p95
            P99LatencyMs    = $p99
            MaxLatencyMs    = $max
            ThroughputRps   = $rps
            DurationSec     = $durationSec
            Note            = $note
        })
    }

    return ,@($results.ToArray())
}

function Show-JmeterReportTable {
    param([object[]]$Levels)

    if ($Levels.Count -eq 0) {
        Write-Host "Brak poziomow do wyswietlenia." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  WYNIKI JMETER (per poziom uzytkownikow)" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ("  {0,-8} {1,8} {2,8} {3,8} {4,8} {5,8} {6,10}" -f `
        "Userzy", "Avg[ms]", "P95[ms]", "RPS", "Zapyt.", "OK[%]", "Czas[s]")
    Write-Host ("  {0,-8} {1,8} {2,8} {3,8} {4,8} {5,8} {6,10}" -f `
        "--------", "-------", "-------", "-----", "------", "-----", "-------")

    foreach ($row in $Levels) {
        $color = "White"
        if ($row.Note) { $color = "Yellow" }
        elseif ($row.P95LatencyMs -ge 500) { $color = "Red" }
        elseif ($row.P95LatencyMs -ge 200) { $color = "DarkYellow" }

        Write-Host ("  {0,-8} {1,8} {2,8} {3,8} {4,8} {5,8} {6,10}" -f `
            $row.ConcurrentUsers,
            $row.AvgLatencyMs,
            $row.P95LatencyMs,
            $row.ThroughputRps,
            $row.TotalRequests,
            $row.SuccessRatePct,
            $row.DurationSec) -ForegroundColor $color

        if ($row.Note) {
            Write-Host "           -> $($row.Note)" -ForegroundColor Yellow
        }
    }

    $first = $Levels[0]
    $last = $Levels[-1]
    $avgGrowth = if ($first.AvgLatencyMs -gt 0) {
        [math]::Round((($last.AvgLatencyMs - $first.AvgLatencyMs) / $first.AvgLatencyMs) * 100, 1)
    } else { 0 }

    Write-Host ""
    Write-Host "  Podsumowanie:" -ForegroundColor Gray
    Write-Host "    Poziomow: $($Levels.Count) | Zapytan lacznie: $(($Levels | Measure-Object TotalRequests -Sum).Sum)"
    Write-Host "    Avg: $($first.ConcurrentUsers) userow = $($first.AvgLatencyMs) ms -> $($last.ConcurrentUsers) userow = $($last.AvgLatencyMs) ms (wzrost ${avgGrowth}%)"

    if ($last.P95LatencyMs -lt 200 -and $last.SuccessRatePct -ge 99) {
        Write-Host "    Wniosek: brak wyraznego nasycenia w badanym zakresie." -ForegroundColor Green
    } elseif ($last.SuccessRatePct -lt 90) {
        Write-Host "    Wniosek: system przeciazony (skutecznosc < 90%)." -ForegroundColor Red
    } else {
        Write-Host "    Wniosek: rosnace opoznienia - sprawdz P95 na wykresie." -ForegroundColor Yellow
    }
    Write-Host "============================================================" -ForegroundColor Cyan
}

if (-not (Test-Path $InputFile)) {
    Write-Host "Brak pliku: $InputFile" -ForegroundColor Red
    exit 1
}

if (-not $Quiet) {
    Write-Host "Analiza JTL: $InputFile" -ForegroundColor Gray
}

$rows = Import-Csv $InputFile

if ($Mode -eq "Wyklad") {
    $levels = Measure-JmeterWykladLevels -Rows $rows -MinSamples $MinSamples

    if ($levels.Count -eq 0) {
        Write-Host "Brak danych (label = liczba userow). Sprawdz plan benchmark-wyklad.jmx" -ForegroundColor Red
        exit 1
    }

    $levels | Select-Object ConcurrentUsers, AvgLatencyMs, P95LatencyMs, SuccessRatePct, TotalRequests |
        Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8

    $levels | Export-Csv -Path $ReportFile -NoTypeInformation -Encoding UTF8

    if ($ShowTable -or -not $Quiet) {
        Show-JmeterReportTable -Levels $levels
    }

    if (-not $Quiet) {
        Write-Host ""
        Write-Host "Pliki:" -ForegroundColor Green
        Write-Host "  Surowe dane JMeter:  $InputFile"
        Write-Host "  Wykres (Excel X/Y):    $OutputFile"
        Write-Host "  Pelny raport:          $ReportFile"
        Write-Host ""
        Write-Host "Wykres w Excelu: ConcurrentUsers (X) vs AvgLatencyMs (Y)" -ForegroundColor Cyan
        Write-Host "Alternatywnie P95:     ConcurrentUsers (X) vs P95LatencyMs (Y) z $ReportFile"
        Write-Host ""
    }
    return
}

# tryb Stepping (stary - allThreads)
$postRows = @($rows | Where-Object { $_.label -like "POST Enroll*" })
if ($postRows.Count -gt 0) { $rows = $postRows }

$grouped = $rows | Group-Object allThreads | Sort-Object { [int]$_.Name }
$out2 = New-Object System.Collections.Generic.List[object]

foreach ($g in $grouped) {
    $users = [int]$g.Name
    if ($users -le 0) { continue }
    if ($StepSize -gt 0 -and ($users % $StepSize) -ne 0) { continue }

    $okMs = New-Object System.Collections.Generic.List[double]
    $ok = 0; $fail = 0

    foreach ($r in $g.Group) {
        if ($r.success -eq "true") {
            $ok++
            [void]$okMs.Add([double]$r.elapsed)
        } else {
            $fail++
        }
    }

    $total = $ok + $fail
    if ($total -lt $MinSamples) { continue }

    $okArr = [double[]]$okMs.ToArray()

    [void]$out2.Add([pscustomobject]@{
        ConcurrentUsers = $users
        TotalRequests   = $total
        Successful      = $ok
        SuccessRatePct  = if ($total -gt 0) { [math]::Round(100.0 * $ok / $total, 2) } else { 0 }
        P95LatencyMs    = Get-Percentile -Values $okArr -Percentile 95
    })
}

$out2 | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
if (-not $Quiet) {
    Write-Host "Gotowe: $OutputFile" -ForegroundColor Green
}
