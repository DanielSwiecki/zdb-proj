# Glowny skrypt benchmarku pod raport / wykres opoznienia vs uzytkownicy.
# Uruchomienie (PowerShell, z katalogu projektu):
#   .\tools\run_benchmark.ps1
#
# Wymaga: Docker (Postgres 2GB RAM), Spring Boot na :8081

param(
    [string]$BaseUrl = "http://localhost:8081",
    [int]$StartUsers = 10,
    [int]$StepUsers = 25,
    [int]$MaxUsers = 400,
    [switch]$SkipPrepare,
    [switch]$MonitorDocker
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $root
Set-Location $projectRoot

Write-Host "`n=== ZDB Benchmark: granica obciazenia bazy (2GB RAM) ===`n" -ForegroundColor Cyan

# 1. Postgres
$pg = docker ps --filter "name=zbd_postgres" --format "{{.Names}}" 2>$null
if (-not $pg) {
    Write-Host "Uruchamiam PostgreSQL (docker compose up -d)..." -ForegroundColor Yellow
    docker compose up -d
    Start-Sleep -Seconds 5
}

$memLimit = docker inspect zbd_postgres --format '{{.HostConfig.Memory}}' 2>$null
if ($memLimit -and [long]$memLimit -gt 0) {
    $memGb = [math]::Round([long]$memLimit / 1GB, 2)
    Write-Host "Postgres RAM limit: ${memGb} GB" -ForegroundColor Gray
} else {
    Write-Host "UWAGA: limit RAM kontenera moze nie byc aktywny (sprawdz mem_limit w docker-compose.yml)" -ForegroundColor Yellow
}

# 2. API
try {
    $null = Invoke-WebRequest -Uri "$BaseUrl/api/course-groups" -TimeoutSec 5 -UseBasicParsing
    Write-Host "API dostepne: $BaseUrl" -ForegroundColor Green
} catch {
    Write-Host "API niedostepne. Uruchom w osobnym terminalu:" -ForegroundColor Red
    Write-Host "  .\mvnw.cmd spring-boot:run" -ForegroundColor White
    exit 1
}

# 3. Pary testowe
if (-not $SkipPrepare) {
    & (Join-Path $root "prepare_benchmark_pairs.ps1")
}

# 4. Opcjonalny monitoring zasobow w tle
$monitorJob = $null
if ($MonitorDocker) {
    $monitorFile = Join-Path $root "benchmark_docker_stats.csv"
    "timestamp,container,cpu_pct,mem_usage,mem_limit" | Out-File $monitorFile -Encoding UTF8
    $monitorJob = Start-Job -ScriptBlock {
        param($out)
        while ($true) {
            $line = docker stats zbd_postgres --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemUsage}}"
            if ($line) {
                $ts = (Get-Date).ToString("o")
                "$ts,$line" | Add-Content $out
            }
            Start-Sleep -Seconds 2
        }
    } -ArgumentList $monitorFile
    Write-Host "Monitoring Docker -> $monitorFile" -ForegroundColor Gray
}

try {
    & (Join-Path $root "BenchmarkLoad.ps1") `
        -BaseUrl $BaseUrl `
        -StartUsers $StartUsers `
        -StepUsers $StepUsers `
        -MaxUsers $MaxUsers
} finally {
    if ($monitorJob) {
        Stop-Job $monitorJob -ErrorAction SilentlyContinue
        Remove-Job $monitorJob -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`nPo benchmarku - najwolniejsze zapytania SQL:" -ForegroundColor Cyan
Write-Host '  docker exec zbd_postgres psql -U admin -d zdb -c "SELECT left(query,80), calls, mean_time, max_time FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 5;"'
