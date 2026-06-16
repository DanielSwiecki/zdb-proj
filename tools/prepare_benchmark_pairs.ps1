# Eksport unikalnych par (student, grupa) które NIE są jeszcze w enrollments.
# Dzięki temu test mierzy czas zapisu, a nie szum 409 Conflict.
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

$containerPath = "/tmp/zdb_benchmark_pairs.csv"
$sql = @"
\copy (
  SELECT s.user_id::text AS studentId, picked.group_id::text AS groupId
  FROM students s
  CROSS JOIN generate_series(1, $SlotsPerStudent) AS slot(n)
  CROSS JOIN LATERAL (
    SELECT cg.id AS group_id
    FROM course_groups cg
    WHERE NOT EXISTS (
      SELECT 1 FROM enrollments e
      WHERE e.student_id = s.user_id AND e.course_group_id = cg.id
    )
    ORDER BY md5(s.user_id::text || slot.n::text)
    LIMIT 1
  ) picked
  WHERE picked.group_id IS NOT NULL
  LIMIT $MaxPairs
) TO '$containerPath' WITH (FORMAT CSV, HEADER true);
"@

$tempSql = Join-Path $env:TEMP "zdb_benchmark_pairs.sql"
$sql | Out-File -FilePath $tempSql -Encoding ASCII

try {
    Get-Content $tempSql -Raw | docker exec -i $ContainerName psql -U admin -d zdb -q
    docker cp "${ContainerName}:${containerPath}" $OutputFile | Out-Null
    docker exec $ContainerName rm -f $containerPath | Out-Null
} finally {
    Remove-Item $tempSql -ErrorAction SilentlyContinue
}

if (-not (Test-Path $OutputFile)) {
    throw "Nie utworzono pliku $OutputFile"
}

$lines = (Get-Content $OutputFile | Measure-Object -Line).Lines - 1
if ($lines -le 0) {
    throw "Brak par w $OutputFile. Sprawdz czy baza ma studentow i grupy."
}

Write-Host "Zapisano $lines par -> $OutputFile" -ForegroundColor Green
