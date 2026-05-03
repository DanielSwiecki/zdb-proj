# ZDB-PROJ - University Database Management System

## 📋 Przegląd

System zarządzania bazą danych dla uniwersytetu zawierający:
- **10 uczelni** z realistycznymi nazwami
- **10 wydziałów** na uczelni
- **10 budynków** na wydział
- **50 sal** na budynek
- **3 kierunki studiów** na wydział
- **8 przedmiotów** per kierunek
- **3 roczniki studentów** (1-3 rok)
- **10 grup zajęciowych** per przedmiot
- **10 studentów** per grupa
- **8 instruktorów** na wydział

**Razem:** ~50,000 sal, ~800 instruktorów, ~2,400 kursów, ~1,800 etapów studiów, ~30,000 studentów

---

## 🚀 Uruchomienie

### 1. Przygotowanie środowiska

```bash
# Ustaw JAVA_HOME na JDK 21
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
```

### 2. Uruchom PostgreSQL w Docker

```bash
docker-compose up -d
```

Sprawdź status:
```bash
docker ps | grep zbd_postgres
```

### 3. Uruchom aplikację Spring Boot

```bash
# Z terminala w folderze projektu
.\mvnw.cmd spring-boot:run
```

Lub z parametrem port:
```bash
.\mvnw.cmd spring-boot:run -Dspring-boot.run.arguments="--server.port=8081"
```

Aplikacja będzie dostępna na: **http://localhost:8081**

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
# Ustaw JAVA_HOME
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
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

## 📚 Dodatkowe informacje

- **Spring Boot:** 4.0.4
- **Spring Data JPA:** 4.0.4
- **Hibernate:** 7.2.7.Final
- **PostgreSQL:** 17
- **Java:** 21

---

**Ostatnia aktualizacja:** 2025-05-02
