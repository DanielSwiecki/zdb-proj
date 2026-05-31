# LoadTest_fixed.ps1
# Poprawiona wersja testu obciążeniowego.
# Najważniejsza zmiana: usunięto Start-Job, który tworzył kruche sesje/procesy PowerShell
# i powodował błąd: "Opening the remote session failed ... State Broken".
# Zamiast tego używany jest RunspacePool, czyli lekkie wątki PowerShell w tym samym procesie.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ===== KONFIGURACJA TESTU =====
$baseUrl = "http://localhost:8081"

# Zakres testu. To daje poziomy: 10, 20, 30, ...
# Nie dawaj od razu 5000 na laptopie. Najpierw sprawdź 200-300, potem zwiększaj.
$startUsers = 850
$stepUsers  = 10
$maxConcurrentUsers = 1000

# Liczba żądań zapisu wykonywanych przez jednego wirtualnego użytkownika.
$requestsPerUser = 20

# Timeout pojedynczego żądania HTTP.
$requestTimeoutSec = 20

# 409 Conflict często oznacza: "student już zapisany do tej grupy".
# Przy teście powtarzanym na tej samej bazie 409 nie oznacza awarii bazy, tylko konflikt biznesowy.
# true  = 409 liczymy jako poprawną odpowiedź systemu.
# false = sukcesem są tylko odpowiedzi 2xx.
$count409AsSuccess = $true

# Maksymalna liczba prawdziwie równoległych runspace'ów.
# Dla testu lokalnego 150-300 jest zwykle znacznie stabilniejsze niż tysiące Start-Jobów.
$maxLocalParallelism = 1000

# Pliki wynikowe.
$outputFile = Join-Path $PSScriptRoot "load_test_results.csv"
$errorFile  = Join-Path $PSScriptRoot "load_test_errors.csv"

# Ustawienia dla większej liczby równoległych połączeń do localhost.
[System.Net.ServicePointManager]::DefaultConnectionLimit = 10000
[System.Net.ServicePointManager]::Expect100Continue = $false

# ===== FUNKCJE POMOCNICZE =====
function Get-ObjectId {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Item,
        [string[]]$PreferredProperties = @("id", "userId", "studentId", "uuid")
    )

    foreach ($name in $PreferredProperties) {
        if ($null -ne $Item.PSObject.Properties[$name] -and $null -ne $Item.$name -and "$($Item.$name)".Trim().Length -gt 0) {
            return "$($Item.$name)"
        }
    }

    return $null
}

function Get-Stats {
    param(
        [double[]]$Times,
        [int]$SuccessCount,
        [int]$TotalRequests
    )

    if ($Times.Count -gt 0) {
        $avg  = ($Times | Measure-Object -Average).Average
        $min  = ($Times | Measure-Object -Minimum).Minimum
        $max  = ($Times | Measure-Object -Maximum).Maximum
        $rate = [math]::Round(($SuccessCount / $TotalRequests) * 100, 2)
    } else {
        $avg = 0
        $min = 0
        $max = 0
        $rate = 0
    }

    [pscustomobject]@{
        Avg = [math]::Round($avg, 2)
        Min = [math]::Round($min, 2)
        Max = [math]::Round($max, 2)
        SuccessRate = $rate
    }
}

function New-ConcurrencyLevels {
    param(
        [int]$Start,
        [int]$Step,
        [int]$Max
    )

    $levels = New-Object System.Collections.Generic.List[int]
    if ($Max -le 0) { return @() }

    if ($Max -lt $Start) {
        [void]$levels.Add($Max)
    } else {
        for ($u = $Start; $u -le $Max; $u += $Step) {
            [void]$levels.Add($u)
        }
    }

    return [int[]]$levels.ToArray()
}

function Get-LevelStudents {
    param(
        [string[]]$AllStudentIds,
        [int]$Needed,
        [ref]$Cursor
    )

    # Staramy się nie używać ciągle tych samych studentów na kolejnych poziomach testu,
    # bo inaczej szybko powstają 409 Conflict: "student już zapisany".
    if ($AllStudentIds.Count -ge ($Cursor.Value + $Needed)) {
        $start = $Cursor.Value
        $end = $Cursor.Value + $Needed - 1
        $Cursor.Value += $Needed
        return [string[]]$AllStudentIds[$start..$end]
    }

    if ($AllStudentIds.Count -ge $Needed) {
        # Brakuje nowych studentów na dalsze poziomy, więc tasujemy całą pulę.
        # Test nadal działa, ale mogą pojawiać się 409, jeśli baza nie została wyczyszczona.
        return [string[]]($AllStudentIds | Get-Random -Count $Needed)
    }

    # Studentów jest mniej niż użytkowników równoczesnych, więc część będzie użyta ponownie.
    $result = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $Needed; $i++) {
        [void]$result.Add($AllStudentIds[$i % $AllStudentIds.Count])
    }
    return [string[]]$result.ToArray()
}

# ===== POBRANIE DANYCH Z API =====
Write-Host "Pobieranie listy grup zajęciowych z $baseUrl/api/course-groups..." -NoNewline
try {
    $groups = Invoke-RestMethod "$baseUrl/api/course-groups" -ErrorAction Stop
    $groupIds = @($groups | ForEach-Object { Get-ObjectId -Item $_ -PreferredProperties @("id", "groupId", "uuid") } | Where-Object { $_ })
    if ($groupIds.Count -eq 0) { throw "Endpoint /api/course-groups nie zwrócił żadnego prawidłowego id grupy." }
    Write-Host " OK ($($groupIds.Count) grup)" -ForegroundColor Green
} catch {
    Write-Host " BŁĄD" -ForegroundColor Red
    Write-Host "Nie udało się pobrać listy grup z $baseUrl/api/course-groups" -ForegroundColor Red
    Write-Host "Szczegóły: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "Pobieranie listy studentów z $baseUrl/api/students..." -NoNewline
try {
    $students = Invoke-RestMethod "$baseUrl/api/students" -ErrorAction Stop
    # W Twoim poprzednim skrypcie student był brany z userId, więc userId jest tutaj pierwszym wyborem.
    $studentIds = @($students | ForEach-Object { Get-ObjectId -Item $_ -PreferredProperties @("userId", "id", "studentId", "uuid") } | Where-Object { $_ })
    if ($studentIds.Count -eq 0) { throw "Endpoint /api/students nie zwrócił żadnego prawidłowego id/userId studenta." }
    Write-Host " OK ($($studentIds.Count) studentów)" -ForegroundColor Green
} catch {
    Write-Host " BŁĄD" -ForegroundColor Red
    Write-Host "Nie udało się pobrać listy studentów z $baseUrl/api/students" -ForegroundColor Red
    Write-Host "Szczegóły: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

if ($groupIds.Count -lt $requestsPerUser) {
    Write-Warning "Masz tylko $($groupIds.Count) grup, a jeden użytkownik wykonuje $requestsPerUser zapisów. Grupy będą używane ponownie, więc 409 Conflict są bardzo prawdopodobne."
}

$effectiveMaxUsers = [math]::Min($maxConcurrentUsers, [math]::Max(1, $studentIds.Count))
$concurrencyLevels = New-ConcurrencyLevels -Start $startUsers -Step $stepUsers -Max $effectiveMaxUsers

$totalRequestsInWholeTest = ($concurrencyLevels | ForEach-Object { $_ * $requestsPerUser } | Measure-Object -Sum).Sum
$totalPossiblePairs = $studentIds.Count * $groupIds.Count
if ($totalRequestsInWholeTest -gt $totalPossiblePairs) {
    Write-Warning "Cały test może wykonać $totalRequestsInWholeTest zapisów, a unikalnych par student-grupa jest tylko $totalPossiblePairs. Bez czyszczenia bazy pojawią się konflikty 409."
}

# ===== PRZYGOTOWANIE CSV =====
[pscustomobject]@{
    ConcurrentUsers = "ConcurrentUsers"
    RealParallelism = "RealParallelism"
    AvgResponseTimeMs = "AvgResponseTimeMs"
    MinResponseTimeMs = "MinResponseTimeMs"
    MaxResponseTimeMs = "MaxResponseTimeMs"
    SuccessRate = "SuccessRate"
    TotalRequests = "TotalRequests"
    FailedRequests = "FailedRequests"
    StatusCodes = "StatusCodes"
} | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1 | Out-File -FilePath $outputFile -Encoding UTF8

[pscustomobject]@{
    ConcurrentUsers = "ConcurrentUsers"
    UserIndex = "UserIndex"
    StatusCode = "StatusCode"
    Error = "Error"
} | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1 | Out-File -FilePath $errorFile -Encoding UTF8

# ===== KOD WYKONYWANY PRZEZ JEDNEGO WIRTUALNEGO UŻYTKOWNIKA =====
$workerScript = {
    param(
        [string]$BaseUrl,
        [string[]]$GroupIds,
        [string[]]$LevelStudentIds,
        [int]$RequestCount,
        [int]$UserIndex,
        [int]$TimeoutSec,
        [bool]$Count409AsSuccess
    )

    Add-Type -AssemblyName System.Net.Http

    $seed = [int](([DateTime]::UtcNow.Ticks + (7919 * ($UserIndex + 1))) % [int]::MaxValue)
    $random = [System.Random]::new($seed)

    $studentId = $LevelStudentIds[$UserIndex % $LevelStudentIds.Count]

    # Losujemy grupy dla użytkownika. Gdy grup jest wystarczająco dużo, nie powtarzamy ich w ramach jednego studenta.
    $myGroups = New-Object System.Collections.Generic.List[string]
    $available = New-Object System.Collections.Generic.List[string]
    foreach ($gid in $GroupIds) { [void]$available.Add($gid) }

    while ($myGroups.Count -lt $RequestCount) {
        if ($available.Count -eq 0) {
            foreach ($gid in $GroupIds) { [void]$available.Add($gid) }
        }

        $idx = $random.Next(0, $available.Count)
        [void]$myGroups.Add($available[$idx])
        $available.RemoveAt($idx)
    }

    $client = [System.Net.Http.HttpClient]::new()
    $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSec)

    $times = New-Object System.Collections.Generic.List[double]
    $successCount = 0
    $statusCodes = @{}
    $sampleErrors = New-Object System.Collections.Generic.List[object]

    foreach ($groupId in $myGroups) {
        $url = "$BaseUrl/api/course-groups/$groupId/enroll"
        $body = "{`"studentId`":`"$studentId`"}"
        $statusCode = 0
        $errorText = ""

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $content = [System.Net.Http.StringContent]::new($body, [System.Text.Encoding]::UTF8, "application/json")
            $response = $client.PostAsync($url, $content).GetAwaiter().GetResult()
            $sw.Stop()

            $statusCode = [int]$response.StatusCode
            $is2xx = ($statusCode -ge 200 -and $statusCode -lt 300)
            $isAcceptedConflict = ($Count409AsSuccess -and $statusCode -eq 409)

            if ($is2xx -or $isAcceptedConflict) {
                $successCount++
            } else {
                try {
                    $errorText = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                } catch {
                    $errorText = $_.Exception.Message
                }
            }

            $response.Dispose()
            $content.Dispose()
        } catch {
            if ($sw.IsRunning) { $sw.Stop() }
            $statusCode = 0
            $errorText = $_.Exception.Message
        }

        [void]$times.Add([double]$sw.ElapsedMilliseconds)

        $key = "$statusCode"
        if ($statusCodes.ContainsKey($key)) {
            $statusCodes[$key]++
        } else {
            $statusCodes[$key] = 1
        }

        if (($statusCode -eq 0 -or ($statusCode -lt 200 -or $statusCode -ge 300)) -and -not ($Count409AsSuccess -and $statusCode -eq 409)) {
            if ($sampleErrors.Count -lt 5) {
                [void]$sampleErrors.Add([pscustomobject]@{
                    UserIndex = $UserIndex
                    StatusCode = $statusCode
                    Error = $errorText
                })
            }
        }
    }

    $client.Dispose()

    [pscustomobject]@{
        Times = [double[]]$times.ToArray()
        SuccessCount = $successCount
        TotalReq = $RequestCount
        StatusCodes = $statusCodes
        SampleErrors = [object[]]$sampleErrors.ToArray()
    }
}

# ===== MAIN =====
Write-Host "============================================================"
Write-Host "  TEST OBCIAZENIOWY: DZIEN ZAPISOW NA PRZEDMIOTY"
Write-Host "============================================================"
Write-Host "Endpoint:          POST $baseUrl/api/course-groups/{groupId}/enroll"
Write-Host "Zadania/uzyt.:     $requestsPerUser zapisow na uzytkownika"
Write-Host "Liczba grup:       $($groupIds.Count)"
Write-Host "Liczba studentow:  $($studentIds.Count)"
Write-Host "Poziomy:           $($concurrencyLevels -join ', ') uzytkownikow"
Write-Host "Max runspace'ow:   $maxLocalParallelism"
Write-Host "409 jako sukces:   $count409AsSuccess"
Write-Host "Wyniki:            $outputFile"
Write-Host "Bledy techniczne:  $errorFile"
Write-Host "============================================================"
Write-Host ""

$studentCursor = 0
$studentCursorRef = [ref]$studentCursor

foreach ($concurrentUsers in $concurrencyLevels) {
    $totalRequests = $concurrentUsers * $requestsPerUser
    $realParallelism = [math]::Min($concurrentUsers, $maxLocalParallelism)
    $levelStudentIds = Get-LevelStudents -AllStudentIds ([string[]]$studentIds) -Needed $concurrentUsers -Cursor $studentCursorRef

    Write-Host "-> $concurrentUsers uzytkownikow ($totalRequests lacznych zapisow)..." -NoNewline

    $pool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $realParallelism)
    $pool.ApartmentState = "MTA"
    $pool.Open()

    $tasks = New-Object System.Collections.Generic.List[object]

    try {
        for ($i = 0; $i -lt $concurrentUsers; $i++) {
            $ps = [System.Management.Automation.PowerShell]::Create()
            $ps.RunspacePool = $pool

            [void]$ps.AddScript($workerScript)
            [void]$ps.AddArgument($baseUrl)
            [void]$ps.AddArgument([string[]]$groupIds)
            [void]$ps.AddArgument([string[]]$levelStudentIds)
            [void]$ps.AddArgument($requestsPerUser)
            [void]$ps.AddArgument($i)
            [void]$ps.AddArgument($requestTimeoutSec)
            [void]$ps.AddArgument($count409AsSuccess)

            $handle = $ps.BeginInvoke()
            [void]$tasks.Add([pscustomobject]@{
                PowerShell = $ps
                Handle = $handle
                UserIndex = $i
            })
        }

        $allTimes = New-Object System.Collections.Generic.List[double]
        $totalSuccess = 0
        $statusCounts = @{}
        $technicalErrors = New-Object System.Collections.Generic.List[object]

        foreach ($task in $tasks) {
            try {
                $resultCollection = $task.PowerShell.EndInvoke($task.Handle)
                foreach ($result in $resultCollection) {
                    if ($null -eq $result) { continue }

                    foreach ($t in $result.Times) { [void]$allTimes.Add([double]$t) }
                    $totalSuccess += [int]$result.SuccessCount

                    foreach ($code in $result.StatusCodes.Keys) {
                        if ($statusCounts.ContainsKey($code)) {
                            $statusCounts[$code] += [int]$result.StatusCodes[$code]
                        } else {
                            $statusCounts[$code] = [int]$result.StatusCodes[$code]
                        }
                    }

                    foreach ($err in $result.SampleErrors) {
                        [void]$technicalErrors.Add($err)
                    }
                }
            } catch {
                # Gdyby któryś runspace sam się wywalił, nie rozbijamy całego testu.
                [void]$technicalErrors.Add([pscustomobject]@{
                    UserIndex = $task.UserIndex
                    StatusCode = 0
                    Error = $_.Exception.Message
                })
            } finally {
                $task.PowerShell.Dispose()
            }
        }
    } finally {
        $pool.Close()
        $pool.Dispose()
    }

    $stats = Get-Stats -Times ([double[]]$allTimes.ToArray()) -SuccessCount $totalSuccess -TotalRequests $totalRequests
    $failed = $totalRequests - $totalSuccess

    $statusText = ($statusCounts.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name):$($_.Value)" }) -join " "

    [pscustomobject]@{
        ConcurrentUsers = $concurrentUsers
        RealParallelism = $realParallelism
        AvgResponseTimeMs = $stats.Avg
        MinResponseTimeMs = $stats.Min
        MaxResponseTimeMs = $stats.Max
        SuccessRate = $stats.SuccessRate
        TotalRequests = $totalRequests
        FailedRequests = $failed
        StatusCodes = $statusText
    } | Export-Csv -Path $outputFile -NoTypeInformation -Append -Encoding UTF8

    foreach ($err in $technicalErrors) {
        [pscustomobject]@{
            ConcurrentUsers = $concurrentUsers
            UserIndex = $err.UserIndex
            StatusCode = $err.StatusCode
            Error = $err.Error
        } | Export-Csv -Path $errorFile -NoTypeInformation -Append -Encoding UTF8
    }

    Write-Host ("  Avg: {0:N1} ms  |  Min: {1:N0} ms  |  Max: {2:N0} ms  |  Sukces: {3}%  |  Bledy: {4}  |  HTTP: {5}" -f `
        $stats.Avg, $stats.Min, $stats.Max, $stats.SuccessRate, $failed, $statusText)
}

Write-Host ""
Write-Host "============================================================"
Write-Host "  TEST ZAKONCZONY"
Write-Host "  Wyniki: $outputFile"
Write-Host "  Bledy:  $errorFile"
Write-Host "============================================================"
Write-Host ""
Write-Host "Jak wykreslic:"
Write-Host "  Excel/LibreOffice: Wstaw > Wykres liniowy"
Write-Host "    - Os X: ConcurrentUsers"
Write-Host "    - Os Y: AvgResponseTimeMs"
Write-Host ""
Write-Host "Uwaga: jeśli chcesz liczyć jako sukces tylko HTTP 2xx, ustaw: `$count409AsSuccess = `$false"
