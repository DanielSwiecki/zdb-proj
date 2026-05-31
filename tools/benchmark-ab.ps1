# ============================================================================
# Benchmark with Apache Bench (ab)
# ============================================================================
# Requirements: Apache Bench (ab) - install separately or use WSL
# Alternative on Windows without ab: WSL -> apt install apache2-utils

$BaseUrl = "http://localhost:8081"
$Endpoint = "/api/course-groups"
$Requests = 1000
$Concurrency = 10

Write-Host "Benchmark API with Apache Bench (ab)"
Write-Host "========================================"
Write-Host "URL: $BaseUrl$Endpoint"
Write-Host "Requests: $Requests"
Write-Host "Concurrency: $Concurrency"
Write-Host "========================================`n"

# Check availability of ab
$ab = Get-Command ab -ErrorAction SilentlyContinue
if (-not $ab) {
    Write-Host "Apache Bench not found in PATH"
    Write-Host "Install using WSL:"
    Write-Host "  PS> wsl apt install apache2-utils"
    Write-Host "Or download ApacheBench from https://www.apachehaus.com/"
    Write-Host "Or use Docker: docker run --rm httpd ab ..."
    exit 1
}

# Check API availability
Write-Host "Checking API availability..."
try {
    $response = curl -s -o $null -w "%{http_code}" "$BaseUrl$Endpoint"
    if ($response -ne "200") {
        throw "HTTP $response"
    }
} catch {
    Write-Host "API unavailable at $BaseUrl"
    exit 1
}
Write-Host "API is available`n"

# 1. Benchmark GET all groups
Write-Host "Test 1: GET /api/course-groups"
Write-Host "----------------------------------------"
ab -n $Requests -c $Concurrency -q "$BaseUrl$Endpoint"
Write-Host ""

# 2. Benchmark GET by ID
Write-Host "Test 2: GET /api/course-groups/1"
Write-Host "----------------------------------------"
ab -n $Requests -c $Concurrency -q "$BaseUrl$Endpoint/1"
Write-Host ""

# 3. Benchmark POST (enroll) - manual test guidance
Write-Host "Test 3: POST /api/course-groups/1/enroll"
Write-Host "----------------------------------------"
Write-Host "Apache Bench does not support JSON POST bodies easily."
Write-Host "Use benchmark-curl.ps1 or JMeter for POST tests."

Write-Host "`nBenchmark completed!`n"
