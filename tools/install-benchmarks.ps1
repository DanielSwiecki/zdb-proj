# ============================================================================
# Script do instalacji narzedzi benchmarkowych na Windows
# ============================================================================
# Tego skryptu uruchamiaj jako Administrator

$BenchmarkDir = "$PSScriptRoot\..\benchmarks"
$JMeterVersion = "5.6.3"
$JMeterUrl = "https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-$JMeterVersion.zip"

# Tworzenie katalogu dla benchmarkow
if (-not (Test-Path $BenchmarkDir)) {
    New-Item -ItemType Directory -Path $BenchmarkDir | Out-Null
    Write-Host "Utworzono katalog: $BenchmarkDir"
}

# ============================================================================
# 1. Instalacja JMeter
# ============================================================================
Write-Host "`nInstalacja JMeter..."
$JMeterDir = Join-Path $BenchmarkDir "apache-jmeter-$JMeterVersion"
$JMeterZip = Join-Path $BenchmarkDir "jmeter.zip"

if (Test-Path $JMeterDir) {
    Write-Host "JMeter juz zainstalowany w: $JMeterDir"
} else {
    try {
        Write-Host "  Pobieranie JMeter ($JMeterVersion)..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $JMeterUrl -OutFile $JMeterZip -Verbose -ErrorAction Stop

        Write-Host "  Rozpakowywanie..."
        Expand-Archive -Path $JMeterZip -DestinationPath $BenchmarkDir -Force
        Remove-Item $JMeterZip

        Write-Host "JMeter zainstalowany: $JMeterDir"
        Write-Host "Uruchom: $JMeterDir\bin\jmeter.bat (GUI) lub jmeter.sh -n (CLI)"
    } catch {
        Write-Host "Blad przy pobieraniu JMeter: $_"
    }
}

# ============================================================================
# 2. Apache Bench (ab)
# ============================================================================
Write-Host "`nInstalacja Apache Bench (ab)..."
$AbPath = Join-Path $BenchmarkDir "ab.exe"

if (Test-Path $AbPath) {
    Write-Host "Apache Bench juz zainstalowany: $AbPath"
} else {
    Write-Host "Pobranie Apache Bench wymaga recznej instalacji."
    Write-Host "Alternatywy:"
    Write-Host "  1. Pobierz z: https://www.apachehaus.com/"
    Write-Host "  2. Lub uzyj WSL: wsl apt install apache2-utils"
    Write-Host "  3. Lub uzyj Docker: docker run --rm httpd ab ..."
}

# ============================================================================
# 3. Siege - zalecenia
# ============================================================================
Write-Host "`nSiege - opcje instalacji:"
$SiegePath = "C:\siege\siege.exe"
if (Test-Path $SiegePath) {
    Write-Host "Siege znaleziony: $SiegePath"
} else {
    Write-Host "Alternatywy:"
    Write-Host "  1. Pobierz ze strony: https://www.joedog.org/siege-home/"
    Write-Host "  2. Lub uzyj WSL: wsl apt install siege"
    Write-Host "  3. Lub uzyj Docker (patrz docker-compose.yml)"
}

# ============================================================================
# Dodaj do PATH
# ============================================================================
Write-Host "`nAktualizacja zmiennej PATH..."
$CurrentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
$JMeterBin = Join-Path $JMeterDir "bin"

if ($CurrentPath -notlike "*$JMeterBin*") {
    Write-Host "  Dodawanie JMeter do PATH: $JMeterBin"
    [Environment]::SetEnvironmentVariable(
        "PATH",
        "$CurrentPath;$JMeterBin",
        "User"
    )
    Write-Host "PATH zaktualizowany. Otworz nowy terminal, aby zmiana weszla w zycie."
} else {
    Write-Host "JMeter juz w PATH"
}

Write-Host "`nInstalacja zakonczona!`n"
Write-Host "Nastepny krok: uruchom test JMeter:"
Write-Host "  .\tools\run_jmeter_wyklad.ps1 -LikeColleague"
