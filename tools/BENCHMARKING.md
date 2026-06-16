# Benchmark obciazeniowy — instrukcja (finalna)

## Szybki start

**Terminal 1 — aplikacja:**
```powershell
docker compose up -d
.\mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=benchmark"
```

**Terminal 2 — test JMeter (wykres jak na wykladzie):**
```powershell
.\tools\run_jmeter_wyklad.ps1 -LikeColleague -HoldSec 90 -RampSec 15
```

Wariant rozszerzony (wiecej poziomow, wymaga par w CSV):
```powershell
.\tools\prepare_benchmark_pairs.ps1 -MaxPairs 500000 -SlotsPerStudent 50 -OutputFile .\tools\enrollments.csv
.\tools\run_jmeter_wyklad.ps1 -StartUsers 10 -StepUsers 100 -MaxUsers 610 -HoldSec 90 -RampSec 15
```

## Pliki wynikowe

| Plik | Opis |
|------|------|
| `wyniki_wyklad.jtl` | Surowe dane JMeter |
| `tools\benchmark_jmeter.csv` | Raport per poziom (pelny) |
| `tools\benchmark_jmeter_przed.csv` | Baseline przed optymalizacja |
| `tools\compare_optimization.ps1` | Porownanie przed/po |

## Porownanie optymalizacji (etap 2)

```powershell
Copy-Item tools\benchmark_jmeter.csv tools\benchmark_jmeter_przed.csv   # przed zmiana w kodzie
# ... restart aplikacji, test po optymalizacji ...
.\tools\compare_optimization.ps1
```

## pg_stat_statements po teście

```sql
SELECT left(query, 80), calls,
       round(mean_exec_time::numeric, 2) AS mean_ms
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
```

## Skrypty w tools/

| Skrypt | Rola |
|--------|------|
| `run_jmeter_wyklad.ps1` | Glowny runner testu |
| `run_wykres_wyklad.ps1` | Alias do run_jmeter_wyklad.ps1 |
| `Generate-BenchmarkWykladJmx.ps1` | Generuje plan JMeter |
| `jmeter-do-wykresu.ps1` | JTL → CSV pod wykres |
| `prepare_benchmark_pairs.ps1` | Eksport par student+grupa |
| `compare_optimization.ps1` | Tabela przed/po optymalizacji |
| `install-benchmarks.ps1` | Instalacja JMeter (Windows) |
| `run_seed_batch.ps1` | Seed bazy partiami |

JMeter: `benchmarks\apache-jmeter-5.6.3\bin\jmeter.bat`
