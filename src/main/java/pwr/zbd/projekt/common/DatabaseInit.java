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

    private final Faker FAKER = new Faker();
    
    // Configuration
    private static final int UNIVERSITIES = 10;
    private static final int FACULTIES_PER_UNIVERSITY = 10;
    private static final int BUILDINGS_PER_FACULTY = 10;
    private static final int ROOMS_PER_BUILDING = 50;
    private static final int DEGREE_PROGRAMS_PER_FACULTY = 3;
    private static final int COURSES_PER_PROGRAM = 8;
    private static final int INSTRUCTORS_PER_FACULTY = 8;
    private static final int STUDENTS_PER_PROGRAM = 30;
    private static final int COURSE_GROUPS_PER_COURSE = 10;
    private static final int STUDENTS_PER_GROUP = 10;
    private static final int STUDENT_YEARS = 3;
    private static final String ACADEMIC_YEAR = "2025/2026";

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
        if (!universityRepo.findAll().isEmpty()) {
            return; // Database already initialized
        }

        System.out.println("🚀 Initializing database with sample data...");
        
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
    }

    private void createUniversities() {
        System.out.println("Creating universities...");
        for (int i = 0; i < UNIVERSITIES; i++) {
            var university = new UniversityEntity();
            university.setName(universityNames[i]);
            universities.add(universityRepo.save(university));
        }
        System.out.println("  ✓ Created " + UNIVERSITIES + " universities");
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
                instructors.add(instructor);
            }
        }
        System.out.println("  ✓ Created " + instructors.size() + " instructors");
    }

    private void createCourses() {
        System.out.println("Creating courses...");
        for (DegreeProgramEntity program : degreePrograms) {
            for (int c = 0; c < COURSES_PER_PROGRAM; c++) {
                var course = new CourseEntity();
                course.setProgram(program);
                course.setName(FAKER.educator().course());
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

    private void createCourseGroups() {
        System.out.println("Creating course groups...");
        int groupCount = 0;
        Random random = new Random(42); // Fixed seed for reproducibility
        
        for (CourseEntity course : courses) {
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
                
                courseGroupRepo.save(group);
                groupCount++;
            }
        }
        System.out.println("  ✓ Created " + groupCount + " course groups");
    }

    private void createStudents() {
        System.out.println("Creating students...");
        int studentCount = 0;
        int index = 100000;
        
        // Map to store students for later use in enrollments
        Map<UUID, StudentEntity> studentMap = new HashMap<>();
        
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
                studentMap.put(user.getId(), student);
                
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

    private void createEnrollments() {
        System.out.println("Creating enrollments...");
        int enrollmentCount = 0;
        Random random = new Random(42); // Fixed seed for reproducibility
        
        List<CourseGroupEntity> allGroups = courseGroupRepo.findAll();
        
        for (CourseGroupEntity group : allGroups) {
            int enrolled = 0;
            for (UserEntity studentUser : studentUsers) {
                if (enrolled >= STUDENTS_PER_GROUP) break;
                
                // Randomly assign students to groups
                if (random.nextBoolean()) {
                    try {
                        var enrollmentId = new EnrollmentId(studentUser.getId(), group.getId());
                        var enrollment = new EnrollmentEntity();
                        enrollment.setEnrollmentId(enrollmentId);
                        enrollment.setStudent(new StudentEntity());
                        enrollment.getStudent().setUser(studentUser);
                        enrollment.setCourseGroup(group);
                        enrollment.setGrade(null); // Not graded yet
                        enrollmentRepo.save(enrollment);
                        enrollmentCount++;
                        enrolled++;
                    } catch (Exception e) {
                        // Handle constraint violations gracefully (duplicate enrollments)
                    }
                }
            }
        }
        System.out.println("  ✓ Created " + enrollmentCount + " enrollments");
    }
}
