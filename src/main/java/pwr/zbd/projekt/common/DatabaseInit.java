package pwr.zbd.projekt.common;

import com.github.javafaker.Faker;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;
import pwr.zbd.projekt.structure.domain.*;
import pwr.zbd.projekt.structure.repository.*;
import pwr.zbd.projekt.teaching.domain.*;
import pwr.zbd.projekt.teaching.repository.*;
import pwr.zbd.projekt.users.domain.*;
import pwr.zbd.projekt.users.repository.*;

import java.util.*;

/**
 * Start aplikacji (pusta baza): generuje spójny zestaw danych testowych — od uczelni po zapisy.
 * Implementuje {@link CommandLineRunner}, więc Spring wywołuje {@link #run(String...)} po starcie kontekstu.
 * <p>
 * Jeśli w tabeli {@code universities} są już rekordy, nic nie robi (żeby nie duplikować danych przy kolejnych uruchomieniach).
 */
@Component
@RequiredArgsConstructor
public class DatabaseInit implements CommandLineRunner {

    private final UniversityRepo universityRepo;
    private final FacultyRepo facultyRepo;
    private final DegreeProgramRepo degreeProgramRepo;
    private final CourseRepo courseRepo;
    private final BuildingRepo buildingRepo;
    private final RoomRepo roomRepo;
    private final StudyStageRepo studyStageRepo;
    private final UserRepo userRepo;
    private final CourseGroupRepo courseGroupRepo;
    private final EnrollmentRepo enrollmentRepo;
    private final StudentStageRepo studentStageRepo;
    private final InstructorRepo instructorRepo;
    private final StudentRepo studentRepo;

    private final Faker FAKER = new Faker();

    /**
     * Seed size configuration. Values can be overridden via Spring properties, e.g.
     *   -Dseed.universities=10 or in application.yaml under `seed.*`.
     * Defaults chosen conservatively to avoid overloading small developer machines.
     */
    @org.springframework.beans.factory.annotation.Value("${seed.universities:3}")
    private int UNIVERSITIES;

    @org.springframework.beans.factory.annotation.Value("${seed.batchMode:false}")
    private boolean BATCH_MODE;

    /** Start index when running in batch mode (0-based). Useful to create universities in chunks. */
    @org.springframework.beans.factory.annotation.Value("${seed.universityStart:0}")
    private int UNIVERSITY_START;

    @org.springframework.beans.factory.annotation.Value("${seed.exitAfterSeed:false}")
    private boolean EXIT_AFTER_SEED;

    @org.springframework.beans.factory.annotation.Value("${seed.facultiesPerUniversity:2}")
    private int FACULTIES_PER_UNIVERSITY;

    @org.springframework.beans.factory.annotation.Value("${seed.buildingsPerFaculty:2}")
    private int BUILDINGS_PER_FACULTY;

    @org.springframework.beans.factory.annotation.Value("${seed.roomsPerBuilding:10}")
    private int ROOMS_PER_BUILDING;

    @org.springframework.beans.factory.annotation.Value("${seed.degreeProgramsPerFaculty:1}")
    private int DEGREE_PROGRAMS_PER_FACULTY;

    @org.springframework.beans.factory.annotation.Value("${seed.coursesPerProgram:3}")
    private int COURSES_PER_PROGRAM;

    @org.springframework.beans.factory.annotation.Value("${seed.instructorsPerFaculty:2}")
    private int INSTRUCTORS_PER_FACULTY;

    @org.springframework.beans.factory.annotation.Value("${seed.studentsPerProgram:10}")
    private int STUDENTS_PER_PROGRAM;

    @org.springframework.beans.factory.annotation.Value("${seed.courseGroupsPerCourse:2}")
    private int COURSE_GROUPS_PER_COURSE;

    @org.springframework.beans.factory.annotation.Value("${seed.studentsPerGroup:5}")
    private int STUDENTS_PER_GROUP;

    @org.springframework.beans.factory.annotation.Value("${seed.studentYears:3}")
    private int STUDENT_YEARS;

    @org.springframework.beans.factory.annotation.Value("${seed.academicYear:2025/2026}")
    private String ACADEMIC_YEAR;

    /** Bufory między krokami seeda — kolejne metody dokładają encje i używają już zapisanych obiektów (FK). */
    private final List<UniversityEntity> universities = new ArrayList<>();
    private final List<FacultyEntity> faculties = new ArrayList<>();
    private final List<DegreeProgramEntity> degreePrograms = new ArrayList<>();
    private final List<BuildingEntity> buildings = new ArrayList<>();
    private final List<RoomEntity> rooms = new ArrayList<>();
    private final List<CourseEntity> courses = new ArrayList<>();
    private final List<UserEntity> instructorUsers = new ArrayList<>();
    private final List<InstructorEntity> instructors = new ArrayList<>();
    private final List<UserEntity> studentUsers = new ArrayList<>();
    private final List<StudyStageEntity> studyStages = new ArrayList<>();
    private final List<CourseGroupEntity> createdCourseGroups = new ArrayList<>();

    private String[] universityNames = {
            "Politechnika Warszawska", "Uniwersytet Jagielloński", "Politechnika Wrocławska",
            "Uniwersytet Warszawski", "Politechnika Gdańska", "Politechnika Krakowska",
            "Uniwersytet Poznański", "Politechnika Łódzka", "Uniwersytet Wrocławski", "AGH"
    };

    private String[] facultyNames = {
            "Wydział Informatyki", "Wydział Elektrotechniki", "Wydział Mechaniczny",
            "Wydział Automatyki", "Wydział Budowy Maszyn", "Wydział Inżynierii Transportu",
            "Wydział Technologii Materiałów", "Wydział Chemiczny", "Wydział Zarządzania", "Wydział Energetyki"
    };

    private String[] programNames = {
            "Informatyka", "Automatyka i Robotyka", "Inżynieria Oprogramowania"
    };

    private String[] buildingNames = {
            "Budynek A", "Budynek B", "Budynek C", "Budynek D", "Budynek E",
            "Budynek F", "Budynek G", "Budynek H", "Budynek I", "Budynek J"
    };

    @Override
    public void run(String... args) throws Exception {
        // If not running in batch mode, skip seeding when DB already contains universities.
        if (!BATCH_MODE && !universityRepo.findAll().isEmpty()) {
            return;
        }

        System.out.println("🚀 Initializing database with sample data...");
        System.out.println("Seed config: batchMode=" + BATCH_MODE + ", universityStart=" + UNIVERSITY_START + ", universities=" + UNIVERSITIES + ", facultiesPerUniversity=" + FACULTIES_PER_UNIVERSITY + ", buildingsPerFaculty=" + BUILDINGS_PER_FACULTY + ", roomsPerBuilding=" + ROOMS_PER_BUILDING + ", coursesPerProgram=" + COURSES_PER_PROGRAM + ", courseGroupsPerCourse=" + COURSE_GROUPS_PER_COURSE + ", studentsPerProgram=" + STUDENTS_PER_PROGRAM + ", studentsPerGroup=" + STUDENTS_PER_GROUP);
        // Kolejność ma znaczenie: najpierw struktura (uczelnie → sale), potem ludzie i przedmioty, na końcu zapisy.
        createUniversities();
        createFacultiesAndBuildings();
        createDegreePrograms();
        createInstructors();
        createCourses();
        createStudyStages();
        createCourseGroups();
        createStudents();
        createEnrollments();
        
        System.out.println("✅ Database initialization completed!");

        if (BATCH_MODE && EXIT_AFTER_SEED) {
            System.out.println("Batch mode + exitAfterSeed=true -> exiting JVM to allow scripted batches.");
            System.exit(0);
        }
    }

    private void createUniversities() {
        System.out.println("Creating universities...");
        for (int i = 0; i < UNIVERSITIES; i++) {
            int nameIndex = i + UNIVERSITY_START;
            String name = nameIndex < universityNames.length ? universityNames[nameIndex] : "Uczelnia "+(nameIndex+1);
            UniversityEntity university = universityRepo.findByName(name)
                    .orElseGet(() -> {
                        var entity = new UniversityEntity();
                        entity.setName(name);
                        return universityRepo.save(entity);
                    });
            universities.add(university);
        }
        System.out.println("  ✓ Ensured " + UNIVERSITIES + " universities (created or existing)");
    }

    private void createFacultiesAndBuildings() {
        System.out.println("Creating faculties and buildings...");
        for (UniversityEntity university : universities) {
            for (int f = 0; f < FACULTIES_PER_UNIVERSITY; f++) {
                var faculty = new FacultyEntity();
                faculty.setUniversity(university);
                faculty.setName(facultyNames[f % facultyNames.length]);
                faculty = facultyRepo.save(faculty);
                faculties.add(faculty);

                // Create buildings for this faculty
                for (int b = 0; b < BUILDINGS_PER_FACULTY; b++) {
                    var building = new BuildingEntity();
                    building.setUniversity(university);
                    building.setName(buildingNames[b % buildingNames.length] + " (" + faculty.getName() + ")");
                    building = buildingRepo.save(building);
                    buildings.add(building);

                    // Create rooms for this building
                    for (int r = 0; r < ROOMS_PER_BUILDING; r++) {
                        var room = new RoomEntity();
                        room.setBuilding(building);
                        room.setName(String.valueOf(r + 1)); // Room numbers like: 1, 2, 3, ...
                        rooms.add(roomRepo.save(room));
                    }
                }
            }
        }
        System.out.println("  ✓ Created " + faculties.size() + " faculties");
        System.out.println("  ✓ Created " + buildings.size() + " buildings");
        System.out.println("  ✓ Created " + rooms.size() + " rooms");
    }

    private void createDegreePrograms() {
        System.out.println("Creating degree programs...");
        for (FacultyEntity faculty : faculties) {
            for (int p = 0; p < DEGREE_PROGRAMS_PER_FACULTY; p++) {
                var program = new DegreeProgramEntity();
                program.setFaculty(faculty);
                program.setName(programNames[p % programNames.length]);
                degreePrograms.add(degreeProgramRepo.save(program));
            }
        }
        System.out.println("  ✓ Created " + degreePrograms.size() + " degree programs");
    }

    private void createInstructors() {
        System.out.println("Creating instructors...");
        for (FacultyEntity faculty : faculties) {
            for (int i = 0; i < INSTRUCTORS_PER_FACULTY; i++) {
                var user = new UserEntity();
                user.setFirstName(FAKER.name().firstName());
                user.setLastName(FAKER.name().lastName());
                user.setEmail(FAKER.internet().emailAddress());
                user.setPassword("password123"); // In real app, this should be hashed
                user = userRepo.save(user);
                instructorUsers.add(user);

                var instructor = new InstructorEntity();
                instructor.setUser(user);
                instructor.setFaculty(faculty);
                instructor.setTitle(new String[]{"Dr.", "Prof.", "Mgr.", "Inż."}[FAKER.random().nextInt(4)]);
                instructors.add(instructorRepo.save(instructor));
            }
        }
        System.out.println("  ✓ Created " + instructors.size() + " instructors");
    }

    private void createCourses() {
        System.out.println("Creating courses...");
        String[] courseNames = {
            "Programowanie obiektowe", "Bazy danych", "Sieci komputerowe", 
            "Algorytmy i struktury danych", "Systemy operacyjne", "Grafika komputerowa",
            "Sztuczna inteligencja", "Bezpieczeństwo informacji"
        };
        
        for (DegreeProgramEntity program : degreePrograms) {
            for (int c = 0; c < COURSES_PER_PROGRAM; c++) {
                var course = new CourseEntity();
                course.setProgram(program);
                // Use Polish course names with counter for uniqueness
                String courseName = courseNames[c % courseNames.length] + " (" + (c + 1) + ")";
                course.setName(courseName);
                courses.add(courseRepo.save(course));
            }
        }
        System.out.println("  ✓ Created " + courses.size() + " courses");
    }

    private void createStudyStages() {
        System.out.println("Creating study stages...");
        for (DegreeProgramEntity program : degreePrograms) {
            for (int year = 1; year <= STUDENT_YEARS; year++) {
                for (int semester = 1; semester <= 2; semester++) {
                    var stage = new StudyStageEntity();
                    stage.setDegreeProgram(program);
                    stage.setAcademicYear(ACADEMIC_YEAR);
                    stage.setSemesterNum((year - 1) * 2 + semester);
                    stage.setTermType(semester == 1 ? TermType.WINTER : TermType.SUMMER);
                    studyStages.add(studyStageRepo.save(stage));
                }
            }
        }
        System.out.println("  ✓ Created " + studyStages.size() + " study stages");
    }

    /** Grupa zajęciowa = przedmiot + etap studiów + numer grupy + prowadzący + sala + limit miejsc. */
    private void createCourseGroups() {
        System.out.println("Creating course groups...");
        int groupCount = 0;
        Random random = new Random(42); // stały seed — przy tych samych stałych seed zawsze ten sam rozkład sal/prowadzących

        for (CourseEntity course : courses) {
            // Uproszczenie: wszystkie grupy przypięte do pierwszego semestru programu (semesterNum == 1)
            StudyStageEntity stage = studyStages.stream()
                    .filter(s -> s.getDegreeProgram().equals(course.getProgram()) && s.getSemesterNum() == 1)
                    .findFirst()
                    .orElse(null);
            
            if (stage == null) continue;

            for (int g = 0; g < COURSE_GROUPS_PER_COURSE; g++) {
                var group = new CourseGroupEntity();
                group.setCourse(course);
                group.setStudyStage(stage);
                group.setGroupNum(g + 1);
                group.setCapacity(STUDENTS_PER_GROUP);
                
                // Assign instructor
                InstructorEntity instructor = instructors.get(random.nextInt(instructors.size()));
                group.setInstructor(instructor);
                
                // Assign room
                RoomEntity room = rooms.get(random.nextInt(rooms.size()));
                group.setRoom(room);
                
                var saved = courseGroupRepo.save(group);
                createdCourseGroups.add(saved);
                groupCount++;
            }
        }
        System.out.println("  ✓ Created " + groupCount + " course groups");
    }

    private void createStudents() {
        System.out.println("Creating students...");
        int studentCount = 0;
        int index = 100000;
        
        for (DegreeProgramEntity program : degreePrograms) {
            for (int s = 0; s < STUDENTS_PER_PROGRAM; s++) {
                var user = new UserEntity();
                user.setFirstName(FAKER.name().firstName());
                user.setLastName(FAKER.name().lastName());
                user.setEmail(FAKER.internet().emailAddress());
                user.setPassword("student123");
                user = userRepo.save(user);
                studentUsers.add(user);

                var student = new StudentEntity();
                student.setUser(user);
                student.setDegreeProgram(program);
                student.setIndex(index++);
                student = studentRepo.save(student);
                
                // Create student stage records for all study stages in their program
                for (StudyStageEntity stage : studyStages) {
                    if (stage.getDegreeProgram().equals(program)) {
                        var studentStage = new StudentStageEntity();
                        var stageId = new StudentStageId(user.getId(), stage.getId());
                        studentStage.setStudentStageId(stageId);
                        studentStage.setStudent(student);
                        studentStage.setStudyStage(stage);
                        studentStage.setStatus(StudentStageEntity.Status.ACTIVE);
                        studentStageRepo.save(studentStage);
                    }
                }
                
                studentCount++;
            }
        }
        System.out.println("  ✓ Created " + studentCount + " students");
    }

    /**
     * Zapisy: losowy podzbiór studentów na grupę (max {@link #STUDENTS_PER_GROUP}).
     * Student w encji ma PK = {@code user_id} — do zapisu używamy {@link StudentRepo#getReferenceById}, nie „gołego” User.
     */
    private void createEnrollments() {
        System.out.println("Creating enrollments...");
        int enrollmentCount = 0;
        Random random = new Random(42);

        List<UserEntity> order = new ArrayList<>(studentUsers);
        Collections.shuffle(order, random);

        for (CourseGroupEntity group : createdCourseGroups) {
            int enrolled = 0;
            for (UserEntity studentUser : order) {
                if (enrolled >= STUDENTS_PER_GROUP) break;
                if (!random.nextBoolean()) continue;

                var enrollmentId = new EnrollmentId(studentUser.getId(), group.getId());
                var enrollment = new EnrollmentEntity();
                enrollment.setEnrollmentId(enrollmentId);
                enrollment.setStudent(studentRepo.getReferenceById(studentUser.getId()));
                enrollment.setCourseGroup(group);
                enrollment.setGrade(null);
                enrollmentRepo.save(enrollment);
                enrollmentCount++;
                enrolled++;
            }
        }
        System.out.println("  ✓ Created " + enrollmentCount + " enrollments");
    }
}
