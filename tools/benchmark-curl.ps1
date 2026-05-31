# ============================================================================
# Benchmark za pomocą curl - najprostszy test obciążeniowy
# ============================================================================
# Parametry
$BaseUrl = "http://localhost:8081"
$Endpoint = "/api/course-groups"
$Requests = 100
$Concurrency = 5

Write-Host "🔥 Benchmark API za pomocą curl"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "URL: $BaseUrl$Endpoint"
Write-Host "Ilość żądań: $Requests"
Write-Host "Współbieżność: $Concurrency"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n"

# Test dostępności
Write-Host "✓ Testowanie dostępności API..."
$response = curl -s -o /dev/null -w "%{http_code}" "$BaseUrl$Endpoint"
if ($response -ne "200") {
    Write-Host "✗ Błąd: API zwróciło kod $response. Upewnij się, że aplikacja uruchomiona na $BaseUrl"
    exit 1
}
Write-Host "✓ API dostępne`n"

# 1. GET all groups
Write-Host "📊 Test 1: GET /api/course-groups (pobranie wszystkich grup)"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
$startTime = Get-Date
for ($i = 0; $i -lt $Requests; $i++) {
    curl -s -o /dev/null "$BaseUrl$Endpoint"
    if (($i + 1) % ($Requests / 5) -eq 0) {
        Write-Host "  Progress: $(($i + 1) / $Requests * 100)%"
    }
}
$duration = (Get-Date) - $startTime
$rps = $Requests / $duration.TotalSeconds
Write-Host "✓ Ukończono: $($duration.TotalSeconds.ToString('F2'))s, RPS: $($rps.ToString('F1'))`n"

# 2. GET by ID
Write-Host "📊 Test 2: GET /api/course-groups/{groupId} (pobranie grupy po ID)"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
$startTime = Get-Date
$groupIds = @()
# Najpierw pobierz grupę
$groups = curl -s "$BaseUrl$Endpoint" | ConvertFrom-Json
if ($groups.Count -gt 0) {
    for ($i = 0; $i -lt $Requests; $i++) {
        $groupId = $groups[$i % $groups.Count].id
        curl -s -o /dev/null "$BaseUrl$Endpoint/$groupId"
        if (($i + 1) % ($Requests / 5) -eq 0) {
            Write-Host "  Progress: $(($i + 1) / $Requests * 100)%"
        }
    }
    $duration = (Get-Date) - $startTime
    $rps = $Requests / $duration.TotalSeconds
    Write-Host "✓ Ukończono: $($duration.TotalSeconds.ToString('F2'))s, RPS: $($rps.ToString('F1'))`n"
} else {
    Write-Host "✗ Brak grup w bazie do testowania`n"
}

# 3. GET student count
Write-Host "📊 Test 3: GET /api/course-groups/{groupId}/students (liczba studentów)"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if ($groups.Count -gt 0) {
    $startTime = Get-Date
    for ($i = 0; $i -lt $Requests; $i++) {
        $groupId = $groups[$i % $groups.Count].id
        curl -s -o /dev/null "$BaseUrl$Endpoint/$groupId/students"
        if (($i + 1) % ($Requests / 5) -eq 0) {
            Write-Host "  Progress: $(($i + 1) / $Requests * 100)%"
        }
    }
    $duration = (Get-Date) - $startTime
    $rps = $Requests / $duration.TotalSeconds
    Write-Host "✓ Ukończono: $($duration.TotalSeconds.ToString('F2'))s, RPS: $($rps.ToString('F1'))`n"
}

Write-Host "✅ Benchmark zakończony!`n"
Write-Host "💡 Wskazówka: Włącz pg_stat_statements w PostgreSQL, aby zobaczyć wolne zapytania:"
Write-Host "   docker exec -it zbd_postgres psql -U admin -d zdb -c 'SELECT query, calls, mean_time FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;'"
