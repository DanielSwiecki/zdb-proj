# Prezentacja: jak działa API i gdzie co leży w projekcie

Dokument pod obronę / pokaz prowadzącemu: **architektura**, **najważniejsze pliki**, **gotowe komendy** (copy-paste).

---

## 1. Krótki przepływ (co powiedzieć na głos)

1. Uruchamiasz **PostgreSQL** (Docker) — baza `zdb`, użytkownik jak w `application.yaml`.
2. Uruchamiasz **Spring Boot** (`ProjektApplication`) — na starcie ładuje kontekst: repozytoria JPA, kontroler REST, `DatabaseInit`.
3. Jeśli baza jest **pusta** (brak uczelni), **`DatabaseInit`** wypełnia ją danymi testowymi w logicznej kolejności (struktura → ludzie → grupy → zapisy).
4. Klient (np. **curl**) woła **`CourseGroupController`** pod `/api/course-groups`. Kontroler używa **repozytoriów** Spring Data — to one generują SQL (INSERT/SELECT/COUNT/DELETE).
5. Odpowiedzi GET zwracają **encje JPA**; Jackson zamienia je na JSON. Pola z **`@JsonIgnore`** odcinają cykle w grafie (np. uczelnia ↔ lista wydziałów).

---

## 2. Mapa katalogów (najważniejsze miejsca)

| Ścieżka | Rola |
|---------|------|
| `src/main/java/pwr/zbd/projekt/ProjektApplication.java` | Start aplikacji Spring Boot. |
| `src/main/java/pwr/zbd/projekt/common/DatabaseInit.java` | Seed bazy przy pierwszym uruchomieniu (`CommandLineRunner`). |
| `src/main/java/pwr/zbd/projekt/teaching/api/CourseGroupController.java` | **Jedyń REST API** w projekcie — wszystkie endpointy grup / zapisów. |
| `src/main/java/pwr/zbd/projekt/teaching/repository/*.java` | Repozytoria Spring Data (m.in. `CourseGroupRepo`, `EnrollmentRepo`). |
| `src/main/java/pwr/zbd/projekt/teaching/domain/*.java` | Encje JPA domeny „nauczanie” (grupa, zapis, klucz złożony). |
| `src/main/java/pwr/zbd/projekt/structure/domain/*.java` | Encje struktury (uczelnia, wydział, budynek, sala, kierunek). |
| `src/main/java/pwr/zbd/projekt/users/domain/*.java` | Użytkownik, student, prowadzący. |
| `src/main/resources/application.yaml` | URL bazy, login, port **8081**, `ddl-auto`. |
| `docker-compose.yml` | Postgres + mapowanie portów (sprawdź zgodność z `12345` w YAML). |
| `src/main/java/pwr/zbd/projekt/benchmark/ApiBenchmark.java` | Opcjonalne obciążeniowe testy HTTP (osobno od curl). |

---

## 3. Endpointy (dowód w kodzie)

Plik: `CourseGroupController.java`, prefiks: **`/api/course-groups`**.

| Metoda | URL | Co robi |
|--------|-----|---------|
| GET | `/api/course-groups` | Lista grup. |
| GET | `/api/course-groups/{groupId}` | Jedna grupa po UUID. |
| GET | `/api/course-groups/{groupId}/students` | Liczba wierszy w `enrollments` dla grupy (COUNT w bazie). |
| POST | `/api/course-groups/{groupId}/enroll` | Body JSON: `{"studentId":"<UUID>"}` — PK studenta = `students.user_id`. |
| DELETE | `/api/course-groups/{groupId}/unenroll/{studentId}` | Usunięcie zapisu. |

**Zapis w bazie:** tabela `enrollments`, klucz złożony `(student_id, course_group_id)` — klasy `EnrollmentId` + `EnrollmentEntity`.

---

## 4. Komendy — jeden blok do wklejenia (PowerShell)

Wklej **całość** do PowerShella (jedna sesja). Zakłada: aplikacja na **8081**, kontener Postgres **`zbd_postgres`**.

```powershell
# --- konfiguracja ---
$base = "http://localhost:8081/api/course-groups"

# 1) lista grup
curl.exe -s $base

# 2) pierwsza grupa + pierwszy student (automatycznie)
$gid = (Invoke-RestMethod $base)[0].id
$sid = (docker exec zbd_postgres psql -U admin -d zdb -t -A -c "SELECT user_id FROM students LIMIT 1;").Trim()
"GROUP_ID=$gid"
"STUDENT_ID=$sid"

# 3) jedna grupa
curl.exe -s "$base/$gid"

# 4) liczba zapisów w grupie
curl.exe -s "$base/$gid/students"

# 5) zapis studenta (POST)
$body = @{ studentId = $sid } | ConvertTo-Json
Invoke-RestMethod -Method POST -Uri "$base/$gid/enroll" -Body $body -ContentType "application/json; charset=utf-8"

# 6) drugi POST — konflikt (już zapisany)
try { Invoke-RestMethod -Method POST -Uri "$base/$gid/enroll" -Body $body -ContentType "application/json; charset=utf-8" } catch { $_.Exception.Response.StatusCode.value__ }

# 7) wypis (DELETE)
curl.exe -s -w "`nHTTP:%{http_code}`n" -X DELETE "$base/$gid/unenroll/$sid"

# 8) ponowny DELETE — brak rekordu (404)
curl.exe -s -w "`nHTTP:%{http_code}`n" -X DELETE "$base/$gid/unenroll/$sid"
```

Jeśli `docker exec` zwróci błąd — sprawdź nazwę kontenera: `docker ps` i podmień `zbd_postgres`.

---

## 5. Co pokazać w IDE prowadzącemu (30 sekund)

1. `CourseGroupController` — metody z adnotacjami `@GetMapping`, `@PostMapping`, `@DeleteMapping`.
2. `EnrollmentEntity` / `EnrollmentId` — **złożony klucz** i `@MapsId`.
3. `DatabaseInit.run` — kolejność `create…` i warunek „jeśli baza niepusta, wyjdź”.
4. `application.yaml` — **port 8081** i JDBC do Postgresa.

To wystarczy, żeby uzasadnić: *„API to warstwa kontrolera, persystencja to JPA + repozytoria, dane startowe to CommandLineRunner”*.
