# Porownanie benchmarku przed/po optymalizacji (etap 2).
#
# Uzycie:
#   1. Skopiuj wyniki sprzed optymalizacji:
#        Copy-Item tools\benchmark_jmeter.csv tools\benchmark_jmeter_przed.csv
#   2. Po optymalizacji uruchom test JMeter (ten sam profil co baseline)
#   3. Porownaj:
#        .\tools\compare_optimization.ps1

param(
    [string]$BeforeFile = "",
    [string]$AfterFile = "",
    [string]$OutputFile = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $BeforeFile) { $BeforeFile = Join-Path $root "benchmark_jmeter_przed.csv" }
if (-not $AfterFile) { $AfterFile = Join-Path $root "benchmark_jmeter.csv" }
if (-not $OutputFile) { $OutputFile = Join-Path $root "benchmark_porownanie.csv" }

foreach ($f in @($BeforeFile, $AfterFile)) {
    if (-not (Test-Path $f)) {
        Write-Host "Brak pliku: $f" -ForegroundColor Red
        exit 1
    }
}

$before = Import-Csv $BeforeFile
$after = Import-Csv $AfterFile

$rows = New-Object System.Collections.Generic.List[object]

foreach ($a in $after) {
    $u = $a.ConcurrentUsers
    $b = $before | Where-Object { $_.ConcurrentUsers -eq $u } | Select-Object -First 1
    if (-not $b) { continue }

    $avgBefore = [double]$b.AvgLatencyMs
    $avgAfter = [double]$a.AvgLatencyMs
    $p95Before = [double]$b.P95LatencyMs
    $p95After = [double]$a.P95LatencyMs
    $improveAvg = if ($avgBefore -gt 0) { [math]::Round(100.0 * ($avgBefore - $avgAfter) / $avgBefore, 1) } else { 0 }
    $improveP95 = if ($p95Before -gt 0) { [math]::Round(100.0 * ($p95Before - $p95After) / $p95Before, 1) } else { 0 }

    [void]$rows.Add([pscustomobject]@{
        ConcurrentUsers   = $u
        AvgPrzedMs        = $avgBefore
        AvgPoMs           = $avgAfter
        AvgPoprawaPct     = $improveAvg
        P95PrzedMs        = $p95Before
        P95PoMs           = $p95After
        P95PoprawaPct     = $improveP95
        SuccessRatePrzed  = $b.SuccessRatePct
        SuccessRatePo     = $a.SuccessRatePct
    })
}

$rows | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  POROWNANIE: przed vs po optymalizacji" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ("  {0,-8} {1,10} {2,10} {3,8} {4,10} {5,10} {6,8}" -f `
    "Userzy", "Avg przed", "Avg po", "Avg %", "P95 przed", "P95 po", "P95 %")
Write-Host ("  {0,-8} {1,10} {2,10} {3,8} {4,10} {5,10} {6,8}" -f `
    "--------", "---------", "------", "-----", "---------", "------", "-----")

foreach ($r in $rows) {
    $color = if ($r.AvgPoprawaPct -gt 0) { "Green" } else { "Yellow" }
    Write-Host ("  {0,-8} {1,10} {2,10} {3,7}% {4,10} {5,10} {6,7}%" -f `
        $r.ConcurrentUsers, $r.AvgPrzedMs, $r.AvgPoMs, $r.AvgPoprawaPct,
        $r.P95PrzedMs, $r.P95PoMs, $r.P95PoprawaPct) -ForegroundColor $color
}

$matched = @($rows)
if ($matched.Count -gt 0) {
    $avgImprove = [math]::Round(($matched | Measure-Object AvgPoprawaPct -Average).Average, 1)
    Write-Host ""
    Write-Host "  Srednia poprawa Avg: ${avgImprove}%" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Zapisano: $OutputFile" -ForegroundColor Green
Write-Host "Wykres w Excelu: ConcurrentUsers vs AvgPrzedMs + AvgPoMs (dwie linie)" -ForegroundColor Cyan
Write-Host ""
