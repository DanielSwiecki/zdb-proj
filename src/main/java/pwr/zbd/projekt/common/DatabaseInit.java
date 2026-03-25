package pwr.zbd.projekt.common;

import com.github.javafaker.Faker;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;
import pwr.zbd.projekt.structure.domain.*;
import pwr.zbd.projekt.structure.repository.*;
import pwr.zbd.projekt.teaching.domain.CourseEntity;
import pwr.zbd.projekt.teaching.domain.StudyStageEntity;
import pwr.zbd.projekt.teaching.domain.TermType;
import pwr.zbd.projekt.teaching.repository.CourseRepo;
import pwr.zbd.projekt.teaching.repository.StudyStageRepo;

import java.util.ArrayList;
import java.util.List;

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

    private final Faker FAKER = new Faker();
    private static final int FACULTY_NUM = 5;
    private static final int PROGRAM_NUM = 5;
    private static final int COURSE_NUM = 5;
    private static final int BUILDING_NUM = 1;
    private static final int ROOM_NUM = 50;

    private final List<UniversityEntity> universityEntities = new ArrayList<>();
    private final List<FacultyEntity> facultyEntities = new ArrayList<>();
    private final List<DegreeProgramEntity> degreeProgramEntities = new ArrayList<>();
    private final List<CourseEntity> courseEntities = new ArrayList<>();
    private final List<BuildingEntity> buildingEntities = new ArrayList<>();
    private final List<RoomEntity> roomEntities = new ArrayList<>();
    private final List<StudyStageEntity> studyStageEntities = new ArrayList<>();

    @Override
    public void run(String... args) throws Exception {
        createUniversity();
        createFaculties();
        createPrograms();
        createStudyStages();
        createCourses();
        createRooms();
    }

    private void createUniversity() {
        if (universityRepo.findAll().isEmpty()) {
            UniversityEntity university = new UniversityEntity();
            university.setName("University");
            university = universityRepo.save(university);
            universityEntities.add(university);
        }
    }

    private void createFaculties() {
        if (facultyRepo.findAll().isEmpty()) {
            for (int i = 0; i < FACULTY_NUM; i++) {
                FacultyEntity faculty = new FacultyEntity();

                faculty.setUniversity(universityEntities.getFirst());
                String facultyName = "faculty:" + i;
                faculty.setName(facultyName);

                faculty = facultyRepo.save(faculty);
                facultyEntities.add(faculty);
            }
        }
    }

    private void createPrograms() {
        if (!degreeProgramRepo.findAll().isEmpty()) return;
        for (FacultyEntity faculty : facultyEntities) {
            for (int i = 0; i < PROGRAM_NUM; i++) {
                var degreeProgram = new DegreeProgramEntity();

                degreeProgram.setName(faculty.getName() + "_" + "program:" + i);
                degreeProgram.setFaculty(faculty);

                degreeProgram = degreeProgramRepo.save(degreeProgram);
                degreeProgramEntities.add(degreeProgram);
            }
        }
    }

    private void createCourses() {
        if(!courseRepo.findAll().isEmpty()) return;
        for (DegreeProgramEntity degreeProgram : degreeProgramEntities) {
            for (int i = 0; i < COURSE_NUM; i++) {
                var course = new CourseEntity();

                course.setName(degreeProgram.getName() + "_" + "course:" + i);
                course.setProgram(degreeProgram);

                course = courseRepo.save(course);
                courseEntities.add(course);
            }
        }
    }

    private void createStudyStages() {
        if (!studyStageRepo.findAll().isEmpty()) return;
        for (var degreeProgram : degreeProgramEntities) {
            for (int i = 1; i <= 6; i++) {
                var studyStage = new StudyStageEntity();

                studyStage.setAcademicYear("2025/2026");
                studyStage.setDegreeProgram(degreeProgram);
                studyStage.setSemesterNum(i);
                TermType term = (i % 2 == 1) ? TermType.WINTER : TermType.SUMMER;
                studyStage.setTermType(term);

                studyStage = studyStageRepo.save(studyStage);
                studyStageEntities.add(studyStage);
            }
        }
    }

    private void createRooms() {
        if (!buildingRepo.findAll().isEmpty()) return;
        for (int i = 0; i < BUILDING_NUM; i++) {
            var building = new BuildingEntity();

            building.setUniversity(universityEntities.getFirst());
            building.setName("building:" + i);

            building = buildingRepo.save(building);
            buildingEntities.add(building);
        }

        if (!roomRepo.findAll().isEmpty()) return;
        for (var building : buildingEntities) {
            for (int i = 0; i < ROOM_NUM; i++) {
                var room = new RoomEntity();
                room.setBuilding(buildingEntities.getFirst());
                room.setName(building.getName() + "room:" + i);

                room = roomRepo.save(room);
                roomEntities.add(room);
            }
        }
    }
}
