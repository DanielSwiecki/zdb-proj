Instrukcja: bezpieczne, etapowe seedowanie pełnej bazy danych

Cel:
- Utworzyć pełny zestaw danych (10 uczelni × 10 wydziałów × 10 budynków × 50 sal, 2 semestry × 3 roczniki, 10 przedmiotów × 10 grup × 10 studentów) bez jednoczesnego przeciążenia laptopa.

Strategia:
- Seed uruchamiany jest partiami (domyślnie po 1 uczelni na partię). Każda partia uruchamia aplikację, seed dodaje encje tylko dla tej partii i kończy JVM (w trybie batch).
- Po każdej partii sprawdź użycie zasobów (`docker stats`, `Get-Process java`) i dopiero wtedy uruchom kolejną partię.

Kroki (szybkie):
1. Otwórz PowerShell w katalogu repozytorium (root projektu).
2. Uruchom PostgreSQL i aplikację pomocniczo jeśli jeszcze nie (docker compose up -d).

3. Domyślne uruchomienie seeda partiami (po 1 uczelni):
```powershell
cd "D:\studia\Mag-II-stoień\Semestr 1\Zaawansowane bazy danych Projekt\zdb-proj"
.\tools\run_seed_batch.ps1 -TotalUniversities 10 -UniversitiesPerBatch 1 -StudentsPerProgram 10
```
Skrypt uruchomi kolejne partie; po każdej partii proces `mvnw` zakończy się (dzięki `seed.exitAfterSeed=true`).

4. Monitoruj zasoby podczas procesu w osobnym terminalu:
```powershell
docker stats
Get-Process java | Sort-Object WorkingSet -Descending | Select-Object Id,ProcessName,@{Name='RAM_MB';Expression={[math]::Round($_.WorkingSet/1MB,1)}}
docker logs -f zbd_postgres
```

5. Jeśli laptop zaczyna swapować lub system staje się niereaktywny — przerwij kolejne partie.

Uwagi:
- Skrypt wywołuje `mvnw` i wymaga zainstalowanego JDK oraz działającego Dockera.
- Jeśli chcesz przyspieszyć import, możesz zwiększyć `UniversitiesPerBatch` (np. 2 lub 3), ale rób to tylko gdy masz wystarczające zasoby.
- W razie problemów, przyślij logi z konsoli (wycinek z `mvnw` i `docker logs -f zbd_postgres`).
