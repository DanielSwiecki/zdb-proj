# ZDB-PROJ - University Database Management System

## 📋 Przegląd

System zarządzania bazą danych dla uniwersytetu. Dane startowe generuje `DatabaseInit.java`. **Obecnie w kodzie są mniejsze stałe** (szybszy start, mniej RAM-u, krótka inicjalizacja). Wcześniejsza pełna skala potrafiła kończyć się problemami przy bardzo dużej liczbie rekordów (długi czas lub brak pamięci przy licznych `save()` i trzymanych kolekcjach).

### Aktualna skala (domyślna w kodzie, konfigurowalna przez properties)

- **3 uczelnie**
- **2 wydziały** na uczelnię → **6** wydziałów
- **2 budynki** na wydział → **12** budynków
- **10 sal** na budynek → **120** sal
- **1 kierunek** na wydział → **6** kierunków
- **3 przedmioty** na kierunek → **18** kursów
- **2 instruktorów** na wydział → **12** instruktorów
- **3 lata × 2 semestry** na kierunek → **36** etapów studiów
- **2 grupy** na przedmiot → **36** grup kursów
- **10 studentów** na kierunek → **60** studentów
- Zapisy (`createEnrollments`) — losowe, wg limitu `STUDENTS_PER_GROUP` (5 studentów na grupę)

### Skala referencyjna (gdy znów podkręcisz stałe jak wcześniej)

Przy klasycznym rozkładzie jak w starszym README (10 uczelni × 10 wydziałów × …) **rzędy wielkości** są m.in.: ok. **50 000** sal, **800** instruktorów, **2 400** kursów, **1 800** etapów studiów, **24 000** grup zajęciowych oraz **kilka–kilkadziesiąt tysięcy** studentów — dokładnie zależy od `STUDENTS_PER_PROGRAM` i pozostałych stałych w `DatabaseInit.java`. Lista z ok. **30 000** studentów mieści się w tej klasie problemu; przy takiej masie rekordów inicjalizacja bywa ciężka bez optymalizacji.

Sensowne kierunki przy dużej skali: batchowe zapisy (`saveAll`/partie), mniejsze trzymanie całego grafu w pamięci oraz ewentualnie większa sterta JVM.

---

## 🚀 Uruchomienie

### Wymagania wstępne

- [Java JDK 21](https://adoptium.net/) (lub nowsza LTS)
- [Docker](https://www.docker.com/get-started) i [Docker Compose]
- [Maven](https://maven.apache.org/install.html) (opcjonalnie, projekt zawiera wrapper mvnw)

### 1. Przygotowanie środowiska

Ustaw zmienne środowiskowe dla Java 21 (dostosuj ścieżkę do swojej instalacji):

**PowerShell:**
```powershell
$env:JAVA_HOME = "C:\Program Files\Java\jdk-21"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
```

**Command Prompt (cmd.exe):**
```cmd
set JAVA_HOME=C:\Program Files\Java\jdk-21
set PATH=%JAVA_HOME%\bin;%PATH%
```

### 2. Uruchom PostgreSQL w Docker

```bash
docker-compose up -d
```

Sprawdź czy kontener bazy danych działa:
```bash
docker ps | grep zbd_postgres
```

Powinieneś zobaczyć coś podobnego do:
```
CONTAINER ID   IMAGE                 COMMAND                  CREATED         STATUS         PORTS                    NAMES
a1b2c3d4e5f6   postgres:17           "docker-entrypoint.s…"   2 minutes ago   Up 2 minutes   0.0.0.0:12345->5432/tcp  zbd_postgres
```

### 3. Uruchom aplikację Spring Boot

```bash
# Z terminala w folderze projektu (używa Maven wrapper)
.\mvnw.cmd spring-boot:run
```

Lub określając własny port:
```bash
.\mvnw.cmd spring-boot:run -Dspring-boot.run.arguments="--server.port=8082"
```

Aplikacja będzie dostępna na: **http://localhost:8081** (lub port, który podałeś)

### 4. Sprawdź czy aplikacja działa

Po kilku sekundach powinieneś zobaczyć w logach coś podobnego do:
```
... Started ZbdbProjektApplication in 4.567 seconds (process running for 5.012)
```

A następnie możesz przetestować endpointy:
- http://localhost:8081/api/course-groups (lista grup)
- http://localhost:8081/api/students (lista studentów)

---

## 📡 REST API Endpoints

### GET - Pobierz wszystkie grupy zajęciowe

```bash
GET http://localhost:8081/api/course-groups
```

**Response:**
```json
[
  {
    "id": 1,
    "name": "Grupa A1",
    "course": {...}
  },
  ...
]
```

---

### GET - Pobierz grupę po ID

```bash
GET http://localhost:8081/api/course-groups/{groupId}
```

**Example:**
```bash
GET http://localhost:8081/api/course-groups/42
```

---

### GET - Liczba studentów w grupie

```bash
GET http://localhost:8081/api/course-groups/{groupId}/students
```

**Response:**
```
10
```

---

### POST - Zapisz studenta na zajęcia

```bash
POST http://localhost:8081/api/course-groups/{groupId}/enroll
Content-Type: application/json

{
  "studentId": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Student zapisany na zajęcia"
}
```

---

### DELETE - Usuń studenta z zajęć

```bash
DELETE http://localhost:8081/api/course-groups/{groupId}/unenroll/{studentId}
```

**Example:**
```bash
DELETE http://localhost:8081/api/course-groups/42/unenroll/550e8400-e29b-41d4-a716-446655440000
```

**Response:**
```json
{
  "success": true,
  "message": "Student usunięty z zajęć"
}
```

---

## 🔧 Benchmarking API

### Kompilacja narzędzia benchmarkingu

```bash
# Build całego projektu
.\mvnw.cmd clean package

# Lub przejdź do folderu i skompiluj benchmark
cd target/classes
javac -d . pwr\zbd\projekt\benchmark\ApiBenchmark.java
```

### Uruchomienie benchmarku

```bash
# Podstawowa składnia
java -cp target/classes pwr.zbd.projekt.benchmark.ApiBenchmark <baseUrl> <operation> <threads> <requests>
```

### Dostępne operacje

| Operacja | Opis |
|----------|------|
| `GET_ALL` | Pobierz wszystkie grupy |
| `GET_BY_ID` | Pobierz grupę po ID |
| `ENROLL` | Zapisz studenta |
| `UNENROLL` | Usuń studenta |
| `MIXED` | Losowa kombinacja wszystkich operacji |

### Przykłady

#### Test GET_ALL z 10 wątkami, 100 żądań na wątek

```bash
java -cp target/classes pwr.zbd.projekt.benchmark.ApiBenchmark http://localhost:8081 GET_ALL 10 100
```

**Output:**
```
🚀 Starting API Benchmark
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Base URL: http://localhost:8081
Operation: GET_ALL
Threads: 10
Requests per thread: 100
Total requests: 1000
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Benchmark Completed!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total Time: 4523 ms
Total Requests: 1000
Successful: 1000
Failed: 0
Success Rate: 100.00%
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 Response Time Statistics (ms):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Min:  12
Max:  456
Avg:  45
P50:  32
P95:  123
P99:  234
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚡ Throughput: 221.02 req/sec
```

#### Test ENROLL (zapisywanie) z 20 wątkami

```bash
java -cp target/classes pwr.zbd.projekt.benchmark.ApiBenchmark http://localhost:8081 ENROLL 20 500
```

#### Test MIXED operacji

```bash
java -cp target/classes pwr.zbd.projekt.benchmark.ApiBenchmark http://localhost:8081 MIXED 15 1000
```

---

## 🧭 Diagram bazy danych z kodu (JPA -> ERD)

Projekt zawiera skrypt generujący diagram ER na podstawie encji JPA (`*Entity.java`).

### 1. Wygeneruj diagram

```bash
python tools/generate_erd.py
```

Wynik zostanie zapisany do:
- `docs/db-diagram.mmd` (format Mermaid ER)

### 2. Jak pokazać diagram na zajęciach

- Otwórz `docs/db-diagram.mmd` w edytorze wspierającym Mermaid (np. plugin VS Code/Cursor lub [Mermaid Live Editor](https://mermaid.live/)).
- Diagram pokazuje tabele, klucze główne i relacje wykryte z adnotacji `@ManyToOne/@OneToMany/@OneToOne/@ManyToMany`.

---

## 📊 PostgreSQL pg_stat_statements

### Włączenie pg_stats

pg_stat_statements jest już skonfigurowany w `docker-compose.yml` i `init-db.sql`.

### Połącz się z bazą

```bash
# Z terminalem
docker exec -it zbd_postgres psql -U admin -d zdb
```

### Przydatne zapytania

#### Top 10 najwolniejszych zapytań

```sql
SELECT query, calls, mean_time, max_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;
```

#### Liczba wołań na zapytanie

```sql
SELECT query, calls
FROM pg_stat_statements
ORDER BY calls DESC
LIMIT 10;
```

#### Całkowity czas spędzony na zapytaniach

```sql
SELECT query, total_time
FROM pg_stat_statements
ORDER BY total_time DESC
LIMIT 10;
```

#### Resetuj statystyki

```sql
SELECT pg_stat_statements_reset();
```

---

## 🗄️ Weryfikacja bazy danych

### Połączenie z bazą

```bash
docker exec -it zbd_postgres psql -U admin -d zdb
```

### Liczba rekordów w tabelach

```sql
SELECT COUNT(*) as universities FROM universities;
SELECT COUNT(*) as faculties FROM faculties;
SELECT COUNT(*) as buildings FROM buildings;
SELECT COUNT(*) as rooms FROM rooms;
SELECT COUNT(*) as instructors FROM instructors;
SELECT COUNT(*) as students FROM students;
SELECT COUNT(*) as courses FROM courses;
SELECT COUNT(*) as course_groups FROM course_groups;
```

### Przykładowe dane

```sql
-- Uczelnie
SELECT name FROM universities LIMIT 3;

-- Wydziały
SELECT f.name, u.name FROM faculties f 
JOIN universities u ON f.university_id = u.id LIMIT 3;

-- Instruktorzy
SELECT i.first_name, i.last_name, f.name FROM instructors i
JOIN faculties f ON i.faculty_id = f.id LIMIT 3;

-- Studenci
SELECT s.index, u.email, dp.name FROM students s
JOIN users u ON s.user_id = u.id
JOIN degree_programs dp ON s.degree_program_id = dp.id LIMIT 3;
```

---

## 🐛 Troubleshooting

### Port 8081 już w użyciu

```bash
# Zmień port w application.yaml lub uruchom na innym porcie
.\mvnw.cmd spring-boot:run -Dspring-boot.run.arguments="--server.port=8082"
```

### PostgreSQL nie uruchamia się

```bash
# Sprawdź czy Docker Desktop jest uruchomiony
docker ps

# Restart kontenera
docker restart zbd_postgres

# Sprawdź logi
docker logs zbd_postgres
```

### Błąd "No compiler is provided"

```bash
# Ustaw JAVA_HOME na ścieżkę do JDK 21
$env:JAVA_HOME = "C:\Program Files\Java\jdk-21"
```

---

## 📝 Struktura projektu

```
zdb-proj/
├── docker-compose.yml          # Konfiguracja PostgreSQL
├── init-db.sql                 # Init skrypt z pg_stats
├── pom.xml                     # Maven dependencies
├── mvnw / mvnw.cmd            # Maven wrapper
└── src/main/java/
    └── pwr/zbd/projekt/
        ├── common/             # DatabaseInit.java
        ├── structure/          # Entities & Repos (University, Faculty, Building, Room)
        ├── teaching/           # Entities & Repos (Course, CourseGroup, Enrollment)
        │   └── api/            # CourseGroupController.java
        ├── users/              # Entities & Repos (User, Student, Instructor)
        │   └── repository/     # StudentRepo.java
        └── benchmark/          # ApiBenchmark.java
```

---

## 📊 Test wydajnościowy (Load Testing)

Projekt zawiera skrypt PowerShell do testowania obciążeniowego symulującego masowy zapis studentów na zajęcia.

### Narzędzie testujące: LoadTest.ps1

Skrypt znajduje się w folderze `tools/` i symuluje scenariusz "DZIEŃ ZAPISÓW":
- Uczelnia ma ~100 grup zajęciowych
- Każdy student zapisuje się na 20 z 30 wymaganych przedmiotów
- Test różne poziomy równoczesności (od 1 do 5000 użytkowników co 10)

#### Wymagania:
- Uruchomiona aplikacja Spring Boot na porcie 8081
- PowerShell 5.1+ (w standardzie w Windows)

#### Jak użyć:
1. Uruchom aplikację: `.\mvnw.cmd spring-boot:run`
2. Uruchom test: `.\tools\LoadTest.ps1`
3. Analizuj wyniki w pliku `load_test_results.csv`

#### Wyniki testu:
Plik CSV zawiera kolumny:
- ConcurrentUsers - liczba równoczesnych użytkowników
- AvgResponseTimeMs - średni czas odpowiedzi w ms
- MinResponseTimeMs - minimalny czas odpowiedzi
- MaxResponseTimeMs - maksymalny czas odpowiedzi
- SuccessRate - procent udanych requestów
- TotalRequests - łączna liczba requestów
- FailedRequests - liczba nieudanych requestów

#### Interpretacja wyników:
- **Czas rośnie liniowo** -> wystarczy skalowanie pionowe (więcej RAM/CPU)
- **Czas rośnie podliniowo** -> system dobrze buforuje, jest wydajny
- **Czas rośnie nadliniowo** -> wąskie gardło: blokady, pule połączeń, I/O
- **SuccessRate spada < 100%** -> baza przeciążona, timeouty lub deadlocki

## 🔧 Konfiguracja testu

W skrypcie `tools\LoadTest.ps1` można dostosować:
- `$baseUrl` - adres aplikacji (domyślnie http://localhost:8081)
- `$concurrencyLevels` - poziomy równoczesności testu
- `$maxParallelJobs` - maksymalna liczba równoległych jobów PowerShell
- `$requestsPerUser` - liczba żądań na użytkownika (domyślnie 20)

## 📚 Dodatkowe informacje

- **Spring Boot:** 4.0.4
- **Spring Data JPA:** 4.0.4
- **Hibernate:** 7.2.7.Final
- **PostgreSQL:** 17
- **Java:** 21

---

**Ostatnia aktualizacja:** 2026-06-02
