# Test JMeter jak w raporcie z wykladu (dyskretne poziomy, staly czas).
#
# WYMAGANE (osobny terminal):
#   .\mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=benchmark"
#
# Uruchomienie:
#   .\tools\run_jmeter_wyklad.ps1 -LikeColleague -HoldSec 90 -RampSec 15

param(
    [string]$BaseUrl = "http://localhost:8081",
    [int]$HoldSec = 90,
    [int]$RampSec = 10,
    [int]$StartUsers = 25,
    [int]$StepUsers = 25,
    [int]$MaxUsers = 500,
    [int[]]$UserLevels = @(),
    [switch]$LikeColleague,
    [switch]$GenerateMorePairs,
    [switch]$NoLiveProgress,
    [switch]$Gui
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $root
Set-Location $projectRoot

$enrollments = Join-Path $root "enrollments.csv"
$jmx = Join-Path $root "benchmark-wyklad.jmx"
$jtl = Join-Path $projectRoot "wyniki_wyklad.jtl"
$wykres = Join-Path $root "wykres_wyklad.csv"
$report = Join-Path $root "benchmark_jmeter.csv"
$jmeterBat = Join-Path $projectRoot "benchmarks\apache-jmeter-5.6.3\bin\jmeter.bat"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  ZDB Benchmark JMeter: opoznienie vs uzytkownicy" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Metoda: dyskretne poziomy, staly czas kazdego etapu" -ForegroundColor Gray
Write-Host "  Wykres: X=ConcurrentUsers, Y=AvgLatencyMs" -ForegroundColor Gray
Write-Host ""
Write-Host "  UWAGA: uruchom aplikacje z profilem benchmark:" -ForegroundColor Yellow
Write-Host '    .\mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=benchmark"' -ForegroundColor White
Write-Host ""

if (-not (Test-Path $jmeterBat)) {
    Write-Host "Brak JMeter: $jmeterBat" -ForegroundColor Red
    exit 1
}

if (-not (docker ps --filter "name=zbd_postgres" --format "{{.Names}}" 2>$null)) {
    Write-Host "Uruchamiam PostgreSQL..." -ForegroundColor Yellow
    docker compose up -d
    Start-Sleep -Seconds 8
}

$memLimit = docker inspect zbd_postgres --format '{{.HostConfig.Memory}}' 2>$null
if ($memLimit -and [long]$memLimit -gt 0) {
    $memGb = [math]::Round([long]$memLimit / 1GB, 2)
    Write-Host "Postgres RAM limit: ${memGb} GB" -ForegroundColor Gray
}

if ($GenerateMorePairs -or -not (Test-Path $enrollments)) {
    Write-Host "Generuje pary z bazy..." -ForegroundColor Yellow
    docker exec zbd_postgres psql -U admin -d zdb -q -c "TRUNCATE TABLE enrollments;"
    & (Join-Path $root "prepare_benchmark_pairs.ps1") -MaxPairs 500000 -OutputFile $enrollments
}

Write-Host "Czyszcze tabele enrollments (TRUNCATE)..." -ForegroundColor Yellow
docker exec zbd_postgres psql -U admin -d zdb -q -c "TRUNCATE TABLE enrollments;"
$cnt = docker exec zbd_postgres psql -U admin -d zdb -t -A -c "SELECT COUNT(*) FROM enrollments;"
Write-Host "  enrollments po czyszczeniu: $($cnt.Trim())" -ForegroundColor Green

try {
    $null = Invoke-WebRequest -Uri "$BaseUrl/api/health" -TimeoutSec 5 -UseBasicParsing
    $groupCount = (Invoke-RestMethod -Uri "$BaseUrl/api/course-groups/count" -TimeoutSec 10)
    Write-Host "API dostepne: $BaseUrl (grup zajeciowych: $groupCount)" -ForegroundColor Green
} catch {
    Write-Host "API niedostepne. Uruchom aplikacje z profilem benchmark!" -ForegroundColor Red
    exit 1
}

if ($LikeColleague) {
    $levels = @(10, 25, 50, 75, 100, 125, 150, 175, 200, 225, 250)
} elseif ($UserLevels.Count -gt 0) {
    $levels = $UserLevels
} else {
    $levels = New-Object System.Collections.Generic.List[int]
    for ($u = $StartUsers; $u -le $MaxUsers; $u += $StepUsers) { [void]$levels.Add($u) }
}

& (Join-Path $root "Generate-BenchmarkWykladJmx.ps1") `
    -UserLevels @($levels) `
    -HoldSec $HoldSec `
    -RampSec $RampSec `
    -OutputFile $jmx

$estMin = [math]::Ceiling($levels.Count * ($HoldSec + $RampSec + 5) / 60)
Write-Host ""
Write-Host "Konfiguracja testu:" -ForegroundColor Cyan
Write-Host "  Poziomy userow: $($levels -join ', ')"
Write-Host "  Czas kazdego poziomu: ${HoldSec}s (ramp ${RampSec}s) - STALY"
Write-Host "  Szacowany czas: ok. $estMin minut"
Write-Host "  Surowe dane:    wyniki_wyklad.jtl"
Write-Host "  Raport:         tools\benchmark_jmeter.csv"
Write-Host "  Wykres:         tools\wykres_wyklad.csv"
Write-Host ""

if (Test-Path $jtl) { Remove-Item $jtl -Force }

$progressJob = $null
if (-not $Gui -and -not $NoLiveProgress) {
    Write-Host "Postep (po kazdym poziomie):" -ForegroundColor Cyan
    $progressJob = Start-Job -FilePath (Join-Path $root "Watch-JmeterProgress.ps1") -ArgumentList @(
        $jtl,
        [int[]]$levels,
        5
    )
}

Push-Location $root
try {
    if ($Gui) {
        & $jmeterBat -t $jmx
    } else {
        & $jmeterBat -n -t $jmx -l $jtl -j (Join-Path $projectRoot "jmeter.log")
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
} finally {
    Pop-Location
    if ($progressJob) {
        Stop-Job $progressJob -ErrorAction SilentlyContinue
        Receive-Job $progressJob -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }
        Remove-Job $progressJob -Force -ErrorAction SilentlyContinue
    }
}

if (-not $Gui) {
    & (Join-Path $root "jmeter-do-wykresu.ps1") -InputFile $jtl -OutputFile $wykres -ReportFile $report -Mode Wyklad -ShowTable
}

Write-Host ""
Write-Host "Po benchmarku - pg_stat_statements (najwolniejsze zapytania):" -ForegroundColor Cyan
$pgStatSql = @"
SELECT left(query, 80) AS query, calls,
       round(mean_exec_time::numeric, 2) AS mean_ms,
       round(max_exec_time::numeric, 2) AS max_ms
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 5;
"@
docker exec zbd_postgres psql -U admin -d zdb -c $pgStatSql 2>$null

Write-Host ""
Write-Host "Wykresy w Excelu:" -ForegroundColor Cyan
Write-Host "  1) tools\wykres_wyklad.csv       -> ConcurrentUsers vs AvgLatencyMs (glowny)"
Write-Host "  2) tools\benchmark_jmeter.csv    -> pelne metryki + P95/P99/RPS"
Write-Host "  3) wyniki_wyklad.jtl             -> surowe dane JMeter (archiwum)"
Write-Host ""
