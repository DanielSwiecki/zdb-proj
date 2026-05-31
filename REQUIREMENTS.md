# 💻 Wymagania do uruchomienia projektu na nowym laptopie

## Spis treści
1. [System operacyjny](#system-operacyjny)
2. [Wymagania obowiązkowe](#wymagania-obowiązkowe)
3. [Wymagania opcjonalne](#wymagania-opcjonalne)
4. [Instalacja krok po kroku](#instalacja-krok-po-kroku)
5. [Weryfikacja instalacji](#weryfikacja-instalacji)

---

## System operacyjny
- **Windows 10/11** (rekomendowany)
- Alternatywnie: **Linux** (Ubuntu 20.04+) lub **macOS**
- **Minimalnie 8 GB RAM**, rekomendowane **16 GB** (dla PostgreSQL + Spring Boot + Docker)

---

## ✅ Wymagania obowiązkowe

### 1. **Java Development Kit (JDK) 21**
   - **Pobierz:** https://www.oracle.com/java/technologies/downloads/#java21
   - Lub: https://adoptium.net/temurin/ (OpenJDK)
   - **Instalacja:** Standardowy installer, dodaj do PATH
   - **Weryfikacja:**
     ```powershell
     java -version
     # powinno wyświetlić: openjdk version "21" lub Oracle JDK 21
     ```

### 2. **Docker Desktop** (dla PostgreSQL)
   - **Pobierz:** https://www.docker.com/products/docker-desktop
   - **Instalacja:** Standardowy installer
   - Włącz hyper-V na Windows (może wymagać restartu)
   - **Weryfikacja:**
     ```powershell
     docker --version
     docker compose --version
     ```

### 3. **Git** (dla klonowania i kontroli wersji)
   - **Pobierz:** https://git-scm.com/download/win
   - **Instalacja:** Standardowy installer
   - **Weryfikacja:**
     ```powershell
     git --version
     ```

### 4. **Maven** (zarządzanie zależnościami) - OPCJONALNIE
   - **Alternatywa:** Projekt ma `./mvnw` i `mvnw.cmd` (wrapper, nie wymaga instalacji)
   - **Jeśli chcesz zainstalować:**
     - Pobierz: https://maven.apache.org/download.cgi
     - Rozpakuj do: `C:\tools\apache-maven`
     - Dodaj do PATH: `C:\tools\apache-maven\bin`
     - **Weryfikacja:** `mvn --version`

---

## 🎯 Wymagania opcjonalne

### Dla benchmarkowania API:

#### **Apache Bench (ab)**
- Instalacja: `PowerShell -ExecutionPolicy Bypass -File tools/install-benchmarks.ps1`
- Alternatywa na WSL: `wsl apt install apache2-utils`

#### **JMeter** (rekomendowane)
- Instalacja: Ten sam skrypt `install-benchmarks.ps1` pobierze JMeter 5.6.3
- Requires: Java (już zainstalowany)
- Pobierz ręcznie: https://jmeter.apache.org/download_jmeter.cgi

#### **Siege**
- Alternatywa 1: WSL → `wsl apt install siege`
- Alternatywa 2: https://www.joedog.org/siege-home/ (binarki)
- Alternatywa 3: Docker (patrz BENCHMARKING.md)

### Dla wygody:

#### **Visual Studio Code + Extensions**
   - Pobierz: https://code.microsoft.com/
   - Extensions:
     - **Extension Pack for Java** (Microsoft)
     - **Spring Boot Extension Pack** (Vmware)
     - **REST Client** - do testowania API wewnątrz VS Code
     - **SQL Server (mssql)** lub **PostgreSQL** - dla SQL

#### **PostgreSQL Client Tools** (opcjonalnie, Docker ma już psql)
   - Pobierz: https://www.postgresql.org/download/windows/
   - Wystarczy zainstalować tylko CLI tools
   - Pozwala na: `psql -h localhost -U admin -d zdb`

#### **Postman** (do testowania API, zamiast curl)
   - Pobierz: https://www.postman.com/downloads/
   - Alternatywa: HTTP REST Client w VS Code

#### **DBeaver** (GUI dla PostgreSQL)
   - Pobierz: https://dbeaver.io/download/
   - Umożliwia wizualne przeglądanie bazy

---

## 🚀 Instalacja krok po kroku

### Krok 1: Instalacja JDK 21
```powershell
# Pobierz installer z https://www.oracle.com/java/technologies/downloads/#java21
# Uruchom installer
# Sprawdź PATH

java -version
```

### Krok 2: Instalacja Docker Desktop
```powershell
# Pobierz z https://www.docker.com/products/docker-desktop
# Uruchom installer
# Zrestartuj komputer
# Uruchom Docker Desktop

docker --version
docker compose --version
```

### Krok 3: Instalacja Git
```powershell
# Pobierz z https://git-scm.com/download/win
# Uruchom installer
# Sprawdź PATH

git --version
```

### Krok 4: Sklonuj projekt
```powershell
cd C:\projects  # Lub dowolny katalog
git clone <URL-projektu>
cd zdb-proj
```

### Krok 5: Uruchom bazę danych
```powershell
docker compose up -d
# PostgreSQL powinien się uruchomić na localhost:5432
```

### Krok 6: Uruchom aplikację Spring Boot
```powershell
# Opcja 1: Maven Wrapper (nie wymaga instalacji Maven)
./mvnw spring-boot:run

# Opcja 2: Bezpośredni run (jeśli masz Maven zainstalowany)
mvn spring-boot:run
```

API powinno być dostępne na: `http://localhost:8081`

### Krok 7: Test dostępności
```powershell
# Powinien zwrócić JSON z listą grup
curl http://localhost:8081/api/course-groups
```

### Krok 8: Zainstaluj benchmarki (opcjonalnie)
```powershell
cd tools
PowerShell -ExecutionPolicy Bypass -File install-benchmarks.ps1
# Pobierze i rozpakuje JMeter
```

---

## ✔️ Weryfikacja instalacji

### Checklist

```powershell
# 1. Java
java -version

# 2. Docker
docker --version
docker compose --version

# 3. Git
git --version

# 4. Dostęp do bazy
docker exec -it zbd_postgres psql -U admin -d zdb -c "SELECT version();"

# 5. Dostęp do API (musi działać ./mvnw spring-boot:run)
curl http://localhost:8081/api/course-groups | jq .

# 6. JMeter (jeśli zainstalowany)
jmeter --version
```

Wszystkie powyższe komendy powinny zwrócić wersje bez błędów.

---

## 📋 Konfiguracja zmiennych środowiska

### Na Windows 10/11:

1. Otwórz **Settings** → **System** → **About** → **Advanced system settings**
2. Kliknij **Environment Variables**
3. Dodaj nowe zmienne:

| Zmienna | Wartość | Opis |
|---------|---------|------|
| `JAVA_HOME` | `C:\Program Files\Java\jdk-21` | (lub gdziekolwiek jest JDK) |
| `MAVEN_HOME` | `C:\tools\apache-maven-3.9.x` | (tylko jeśli instalujesz Maven) |
| `PATH` | Dodaj `%JAVA_HOME%\bin` | (Maven jest już w PATH jeśli jest zainstalowany) |

**Reload PATH:**
```powershell
# Zamknij i otwórz nowy terminal PowerShell
```

---

## 🆘 Troubleshooting

| Problem | Rozwiązanie |
|---------|------------|
| `'java' is not recognized` | Dodaj `C:\Program Files\Java\jdk-21\bin` do PATH |
| `Docker daemon not running` | Uruchom Docker Desktop |
| `Cannot connect to database` | Sprawdź `docker compose ps` - baza musi być UP |
| `Port 8081 already in use` | Zmień port w `application.yaml` lub zabij proces na 8081 |
| `mvnw command not found` | Sprawdź czy jesteś w głównym katalogu projektu |
| Out of memory | Zwiększ RAM w Docker Desktop: Settings → Resources → Memory |

---

## 📊 Rozmiar pobierań

| Komponent | Rozmiar |
|-----------|---------|
| JDK 21 | ~200 MB |
| Docker Desktop | ~1.5 GB |
| Git | ~200 MB |
| JMeter | ~280 MB |
| Maven (opcjonalnie) | ~300 MB |
| PostgreSQL (Docker image) | ~400 MB |
| **Razem** | **~3.3 GB** |

---

## ⏱️ Szacunkowy czas instalacji

- Pobieranie: **20-30 minut** (zależy od internetu)
- Instalacja: **10-15 minut**
- Pierwszy startup bazy: **2-3 minuty**
- Pierwszy build projektu: **3-5 minut** (Maven pobierze zależności)
- **Razem: ~45 minut**

---

## 🎓 Rekomendacje dla lepszej wydajności

1. **Zwiększ RAM dla Docker:**
   - Docker Desktop → Settings → Resources → Memory: minimum **8 GB**
   - CPU: minimum **4 cores**

2. **Włącz WSL 2 backend** (zalecany dla Docker na Windows):
   - Docker Desktop → Settings → General → Use WSL 2 based engine

3. **Wylącz wiele aplikacji podczas testów:**
   - Przeglądarki, IDE itp. mogą spowalniać testy

4. **SSD jest wymagany** dla lepszej wydajności PostgreSQL

---

## 📚 Przydatne komendy

```powershell
# Uruchamianie bazy
docker compose up -d

# Zatrzymanie bazy
docker compose down

# Łoha do bazy z terminala
docker exec -it zbd_postgres psql -U admin -d zdb

# Uruchamianie aplikacji
./mvnw spring-boot:run

# Czyszczenie Maven cache
./mvnw clean

# Build projektu (bez uruchamiania)
./mvnw package

# Obejrzenie logów Docker
docker logs -f zbd_postgres

# Status kontenerów
docker compose ps
```

---

## 📞 Wsparcie

Jeśli masz problemy z instalacją:
1. Sprawdź sekcję **Troubleshooting**
2. Czytaj logi: `./mvnw spring-boot:run` → terminal
3. Docker logs: `docker logs -f zbd_postgres`
4. PostgreSQL logs: `docker exec -it zbd_postgres tail -f /var/log/postgresql/postgresql.log`

---

**Autor:** Database Project
**Data:** 2026-05-30
