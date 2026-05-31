# 🚀 Benchmarkowanie API - Instrukcja

Projekt zawiera kompleksową konfigurację do benchmarkowania API za pomocą trzech narzędzi:
- **curl** — najprostsze, wbudowane w Windows
- **Apache Bench (ab)** — tradycyjne narzędzie Apache
- **JMeter** — profesjonalne, zaawansowane

## 📋 Wymagania

### 1. Aplikacja musi działać
```bash
cd zdb-proj
./mvnw spring-boot:run
```
API będzie dostępne na: `http://localhost:8081`

### 2. Baza danych musi działać
```bash
docker compose up -d
```

### 3. Zainstaluj narzędzia benchmarkowe
Uruchom skrypt (jako Administrator w PowerShell):
```powershell
# Przejdź do folderu tools
cd tools

# Uruchom instalator (pobierze JMeter)
PowerShell -ExecutionPolicy Bypass -File install-benchmarks.ps1
```

## 🔧 Opcje benchmarkowania

### Option 1: Benchmark za pomocą curl (najprostszy)
```powershell
cd tools
PowerShell -ExecutionPolicy Bypass -File benchmark-curl.ps1
```

**Zalety:**
- Żaden setup nie wymagany (curl jest wbudowany)
- Prosty skrypt PowerShell
- Idealne dla wstępnych testów

**Co testuje:**
- GET /api/course-groups (all groups)
- GET /api/course-groups/{id} (by ID)
- GET /api/course-groups/{id}/students (student count)

---

### Option 2: Apache Bench (ab)
```powershell
cd tools
PowerShell -ExecutionPolicy Bypass -File benchmark-ab.ps1
```

**Wymagania:**
- Najpierw: `PowerShell -ExecutionPolicy Bypass -File install-benchmarks.ps1`
- LUB: `wsl apt install apache2-utils` (jeśli masz WSL)

**Zalety:**
- Szybki, niskopoziomowy benchmark
- Detailowe statystyki (latency percentiles, etc.)
- Może testować dużo żądań jednocześnie

**Ograniczenia:**
- Trudne testowanie POST/DELETE z body
- Nie wspiera zmiennych w testach

---

### Option 3: JMeter (most powerful)
```powershell
cd tools
# Uruchom instalator
PowerShell -ExecutionPolicy Bypass -File install-benchmarks.ps1

# Potem: batch mode (bez GUI)
PowerShell -ExecutionPolicy Bypass -File benchmark-jmeter.ps1

# Lub: tryb GUI (interaktywny)
PowerShell -ExecutionPolicy Bypass -File benchmark-jmeter.ps1 gui
```

**Zalety:**
- Zapisywanie wyników (JTL format)
- Zmienne i dynamika w testach
- Wizualne raporty w GUI
- Możliwość testowania POST/DELETE z body
- Rozkład czasów odpowiedzi

**Plik testu:** `benchmark-api.jmx` (można edytować w GUI)

---

## 📊 Interpretacja wyników

### Metryki do obserwowania

| Metrika | Dobra | Średnia | Zła |
|---------|-------|---------|------|
| Avg Response | < 100ms | 100-500ms | > 1s |
| Max Response | < 1s | 1-5s | > 5s |
| Error Rate | 0% | < 1% | > 5% |
| RPS (Requests/sec) | > 100 | 10-100 | < 10 |

### Przykład wyników z curl
```
📊 Test 1: GET /api/course-groups
✓ Ukończono: 2.45s, RPS: 40.8
```
To oznacza: 100 żądań w 2.45 sekund = 40.8 żądań na sekundę.

### Przykład wyników z JMeter
```
Total requests: 1000
Successful: 999
Failed: 1
Avg Response: 45ms
Min Response: 12ms
Max Response: 285ms
```

---

## 🔍 Połączenie z PostgreSQL do analizy zapytań

Po benchmarku sprawdź, które zapytania SQL były najwolniejsze:

```bash
# Podłącz się do bazy
docker exec -it zbd_postgres psql -U admin -d zdb

# Top 10 najwolniejszych zapytań
SELECT query, calls, mean_time, max_time, total_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;

# Zapytania z największą liczbą wywołań
SELECT query, calls, mean_time
FROM pg_stat_statements
ORDER BY calls DESC
LIMIT 10;

# Resetuj statystyki
SELECT pg_stat_statements_reset();
```

---

## 📝 Scenariusze testów

### Scenariusz 1: Test obciążeniowy - GET
```powershell
# Uruchom benchmark-curl.ps1
# To wysyła 100 żądań GET z 5 wątkami
```

### Scenariusz 2: Test wydajności - JMeter
```powershell
# Uruchom benchmark-jmeter.ps1
# To wysyła 1000 żądań z 10 wątkami w ciągu 30 sekund (ramp-up)
```

### Scenariusz 3: Własny test
Edytuj parametry w skryptach:
```powershell
# W benchmark-curl.ps1
$Requests = 1000  # liczba żądań
$Concurrency = 20 # wątki

# W benchmark-jmeter.ps1 lub benchmark-api.jmx
$Threads = 20
$RampUp = 60
$Iterations = 200
```

---

## ⚙️ Konfiguracja JMeter

Plik testu: `benchmark-api.jmx`

Aby edytować w GUI:
```powershell
jmeter -t benchmark-api.jmx
```

Zmienne w teście (można zmienić via CLI):
- `BASE_URL` — URL API (default: http://localhost:8081)
- `THREADS` — liczba wątków (default: 10)
- `RAMP_UP` — czas ramp-up w sekundach (default: 30)
- `ITERATIONS` — iteracje per wątek (default: 100)

Override z wiersza poleceń:
```powershell
jmeter -n -t benchmark-api.jmx `
       -Jthreads=50 `
       -Jiterations=500 `
       -l results/output.jtl
```

---

## 🐳 Alternatywa: Docker dla benchmarków

Jeśli chcesz uruchamiać benchmarki w kontenerach:

```bash
# Apache Bench w Docker
docker run --rm httpd ab -n 1000 -c 10 http://localhost:8081/api/course-groups

# JMeter w Docker
docker run --rm -v $(pwd)/tools:/tests \
  justb4/jmeter -n -t /tests/benchmark-api.jmx -l /tests/results/output.jtl

# Siege w Docker
docker run --rm siege -b -c 10 -r 100 http://localhost:8081/api/course-groups
```

---

## 📈 Continuous monitoring

Aby monitorować API w real-time podczas benchmarku:

```bash
# Terminal 1: Uruchom benchmark
PowerShell -ExecutionPolicy Bypass -File tools/benchmark-jmeter.ps1

# Terminal 2: Monitoruj bazę
watch -n 1 'docker exec -it zbd_postgres psql -U admin -d zdb -c "SELECT count(*) FROM enrollments;"'

# Terminal 3: Monitoruj aplikację
curl http://localhost:8081/actuator/metrics
```

---

## 🆘 Troubleshooting

| Problem | Rozwiązanie |
|---------|------------|
| `jmeter command not found` | Uruchom `install-benchmarks.ps1` lub dodaj JMeter do PATH |
| `API not responding` | Sprawdź `./mvnw spring-boot:run` i `docker compose up` |
| `Too many connections` | Zwiększ `max_connections` w PostgreSQL |
| `Out of memory` | Zmniejsz liczbę wątków lub iteracji |
| `Timeout errors` | Zwiększ timeout w testach lub dodaj `-Jconnect_timeout=10000` |

---

## 📚 Dodatkowe zasoby

- [Apache Bench docs](https://httpd.apache.org/docs/2.4/programs/ab.html)
- [JMeter User Manual](https://jmeter.apache.org/usermanual/index.html)
- [PostgreSQL pg_stat_statements](https://www.postgresql.org/docs/current/pgstatstatements.html)

---

**Autor:** Database Project
**Data:** 2026-05-30
