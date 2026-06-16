# Eksport unikalnych par (student, grupa) ktore NIE sa jeszcze w enrollments.
param(
    [string]$ContainerName = "zbd_postgres",
    [string]$OutputFile = "",
    [int]$MaxPairs = 200000,
    [int]$SlotsPerStudent = 15
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $OutputFile) {
    $OutputFile = Join-Path $scriptDir "benchmark_pairs.csv"
}

Write-Host "Przygotowanie par benchmarkowych (max $MaxPairs)..." -ForegroundColor Cyan

$check = docker ps --filter "name=$ContainerName" --format "{{.Names}}" 2>$null
if (-not $check) {
    throw "Kontener '$ContainerName' nie dziala. Uruchom: docker compose up -d"
}

if (Test-Path $OutputFile) {
    Remove-Item $OutputFile -Force
}

# COPY TO STDOUT przez plik SQL w kontenerze (bez \copy - dziala na Windows)
$sqlFile = "/tmp/zdb_export_pairs.sql"
$query = @"
COPY (
    SELECT "studentId", "groupId"
  FROM (
    SELECT
      s.user_id::text AS "studentId",
      cg.id::text AS "groupId",
      row_number() OVER (
        PARTITION BY s.user_id
        ORDER BY md5(s.user_id::text || cg.id::text)
      ) AS rn
    FROM students s
    CROSS JOIN course_groups cg
    WHERE NOT EXISTS (
      SELECT 1 FROM enrollments e
      WHERE e.student_id = s.user_id AND e.course_group_id = cg.id
    )
  ) picked
  WHERE rn <= $SlotsPerStudent
  LIMIT $MaxPairs
) TO STDOUT WITH (FORMAT CSV, HEADER true);
"@

$tempSql = Join-Path $env:TEMP "zdb_export_pairs.sql"
[System.IO.File]::WriteAllText($tempSql, $query.Replace("`r`n", "`n"))

try {
    docker cp $tempSql "${ContainerName}:${sqlFile}" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "docker cp SQL failed" }

    $raw = docker exec $ContainerName psql -U admin -d zdb -q -t -f $sqlFile 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "psql export failed: $raw"
    }

    # psql -t usuwa naglowek COPY - dodaj recznie jesli brak
    $csv = ($raw | Out-String).Trim()
    if ($csv.Length -eq 0) {
        throw "Eksport zwrocil pusty wynik. Czy baza ma studentow i grupy?"
    }

    if ($csv -notmatch "^studentId,") {
        "studentId,groupId`n$csv" | Set-Content -Path $OutputFile -Encoding UTF8
    } else {
        $csv | Set-Content -Path $OutputFile -Encoding UTF8
    }

    docker exec $ContainerName rm -f $sqlFile | Out-Null
} finally {
    Remove-Item $tempSql -ErrorAction SilentlyContinue
}

$lines = (Get-Content $OutputFile | Measure-Object -Line).Lines - 1
if ($lines -le 0) {
    throw "Brak par w $OutputFile. Uruchom seed: .\tools\run_seed_batch.ps1"
}

Write-Host "Zapisano $lines par -> $OutputFile" -ForegroundColor Green
