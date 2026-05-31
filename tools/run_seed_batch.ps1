param(
    [int]$TotalUniversities = 10,
    [int]$UniversitiesPerBatch = 1,
    [int]$FacultiesPerUniversity = 10,
    [int]$BuildingsPerFaculty = 10,
    [int]$RoomsPerBuilding = 50,
    [int]$DegreeProgramsPerFaculty = 1,
    [int]$CoursesPerProgram = 10,
    [int]$CourseGroupsPerCourse = 10,
    [int]$StudentsPerProgram = 100, # total students per program (adjust to reach 10 groups x10 students)
    [int]$StudentsPerGroup = 10,
    [switch]$AutoContinue
)

# Ensure running from repo root
Set-Location -Path (Split-Path -Path $MyInvocation.MyCommand.Definition -Parent) -ErrorAction SilentlyContinue
Set-Location -Path ..

Write-Host "Starting batch seed: total=$TotalUniversities, per-batch=$UniversitiesPerBatch, autoContinue=$AutoContinue"

for ($start = 0; $start -lt $TotalUniversities; $start += $UniversitiesPerBatch) {
    $batchNum = [math]::Ceiling(($start + 1) / $UniversitiesPerBatch)
    Write-Host "`n=== Batch ${batchNum}: creating universities start=${start} (count=${UniversitiesPerBatch}) ==="

    $appArgs = @(
        '--seed.batchMode=true',
        '--seed.exitAfterSeed=true',
        '--server.port=0',
        "--seed.universityStart=$start",
        "--seed.universities=$UniversitiesPerBatch",
        "--seed.facultiesPerUniversity=$FacultiesPerUniversity",
        "--seed.buildingsPerFaculty=$BuildingsPerFaculty",
        "--seed.roomsPerBuilding=$RoomsPerBuilding",
        "--seed.degreeProgramsPerFaculty=$DegreeProgramsPerFaculty",
        "--seed.coursesPerProgram=$CoursesPerProgram",
        "--seed.courseGroupsPerCourse=$CourseGroupsPerCourse",
        "--seed.studentsPerProgram=$StudentsPerProgram",
        "--seed.studentsPerGroup=$StudentsPerGroup"
    )

    $args = @(
        'spring-boot:run',
        "-Dspring-boot.run.arguments=$($appArgs -join ' ')"
    )

    Write-Host "Running mvnw for this batch (this process will exit after seeding)..."
    Write-Host "Maven arguments: $($args -join ' ')"
    & .\mvnw.cmd $args
    $exitCode = $LASTEXITCODE
    Write-Host "mvnw exited with code $exitCode"

    if ($exitCode -ne 0) {
        Write-Host "Error: batch process failed. Stopping further batches." -ForegroundColor Red
        break
    }

    Write-Host "Batch $batchNum completed."
    if ($batchNum -lt [math]::Ceiling($TotalUniversities / $UniversitiesPerBatch)) {
        Write-Host "Starting next batch..."
    }
    Write-Host "Check resource usage before next batch: docker stats, Get-Process java, docker logs -f zbd_postgres"

    if (-not $AutoContinue) {
        Write-Host "Press Enter to continue to next batch or Ctrl+C to abort..."
        [void][System.Console]::ReadLine()
    }
}

Write-Host "All requested batches processed."