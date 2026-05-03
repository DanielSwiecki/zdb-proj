package pwr.zbd.projekt.teaching.api;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pwr.zbd.projekt.teaching.domain.CourseGroupEntity;
import pwr.zbd.projekt.teaching.domain.EnrollmentEntity;
import pwr.zbd.projekt.teaching.domain.EnrollmentId;
import pwr.zbd.projekt.teaching.repository.CourseGroupRepo;
import pwr.zbd.projekt.teaching.repository.EnrollmentRepo;
import pwr.zbd.projekt.users.repository.StudentRepo;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/course-groups")
@RequiredArgsConstructor
public class CourseGroupController {

    private final CourseGroupRepo courseGroupRepo;
    private final EnrollmentRepo enrollmentRepo;
    private final StudentRepo studentRepo;

    /**
     * GET /api/course-groups - Pobierz wszystkie grupy zajęciowe
     */
    @GetMapping
    public ResponseEntity<List<CourseGroupEntity>> getAllCourseGroups() {
        List<CourseGroupEntity> groups = courseGroupRepo.findAll();
        return ResponseEntity.ok(groups);
    }

    /**
     * GET /api/course-groups/{groupId} - Pobierz grupę zajęciową po ID
     */
    @GetMapping("/{groupId}")
    public ResponseEntity<CourseGroupEntity> getCourseGroupById(@PathVariable UUID groupId) {
        return courseGroupRepo.findById(groupId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    /**
     * GET /api/course-groups/{groupId}/students - Pobierz liczbę studentów w grupie
     */
    @GetMapping("/{groupId}/students")
    public ResponseEntity<Long> getStudentCountInGroup(@PathVariable UUID groupId) {
        return courseGroupRepo.findById(groupId)
                .map(group -> {
                    long count = group.getEnrollments() != null ? group.getEnrollments().size() : 0;
                    return ResponseEntity.ok(count);
                })
                .orElse(ResponseEntity.notFound().build());
    }

    /**
     * POST /api/course-groups/{groupId}/enroll - Zapisz studenta na zajęcia
     * Request body: { "studentId": "550e8400-e29b-41d4-a716-446655440000" }
     */
    @PostMapping("/{groupId}/enroll")
    public ResponseEntity<EnrollmentResponse> enrollStudent(
            @PathVariable UUID groupId,
            @RequestBody EnrollmentRequest request) {
        try {
            // Sprawdzenie czy grupa istnieje
            CourseGroupEntity group = courseGroupRepo.findById(groupId)
                    .orElseThrow(() -> new RuntimeException("Grupa nie znaleziona"));

            // Sprawdzenie czy student istnieje
            if (!studentRepo.existsById(request.getStudentId())) {
                throw new RuntimeException("Student nie znaleziony");
            }

            // Sprawdzenie czy student już jest zapisany
            EnrollmentId enrollmentId = new EnrollmentId(request.getStudentId(), groupId);
            if (enrollmentRepo.existsById(enrollmentId)) {
                return ResponseEntity.status(HttpStatus.CONFLICT)
                        .body(new EnrollmentResponse(false, "Student już jest zapisany na tę grupę"));
            }

            // Zapis na zajęcia
            EnrollmentEntity enrollment = new EnrollmentEntity();
            enrollment.setEnrollmentId(enrollmentId);
            enrollment.setCourseGroup(group);
            enrollment.setStudent(studentRepo.findById(request.getStudentId()).get());
            enrollmentRepo.save(enrollment);

            return ResponseEntity.status(HttpStatus.CREATED)
                    .body(new EnrollmentResponse(true, "Student zapisany na zajęcia"));

        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new EnrollmentResponse(false, "Błąd: " + e.getMessage()));
        }
    }

    /**
     * DELETE /api/course-groups/{groupId}/unenroll/{studentId} - Usuń studenta z zajęć
     */
    @DeleteMapping("/{groupId}/unenroll/{studentId}")
    public ResponseEntity<EnrollmentResponse> unenrollStudent(
            @PathVariable UUID groupId,
            @PathVariable UUID studentId) {
        try {
            EnrollmentId enrollmentId = new EnrollmentId(studentId, groupId);
            if (!enrollmentRepo.existsById(enrollmentId)) {
                return ResponseEntity.notFound().build();
            }
            enrollmentRepo.deleteById(enrollmentId);
            return ResponseEntity.ok(new EnrollmentResponse(true, "Student usunięty z zajęć"));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new EnrollmentResponse(false, "Błąd: " + e.getMessage()));
        }
    }

    // DTO Classes
    public static class EnrollmentRequest {
        public UUID studentId;

        public UUID getStudentId() {
            return studentId;
        }

        public void setStudentId(UUID studentId) {
            this.studentId = studentId;
        }
    }

    public static class EnrollmentResponse {
        public boolean success;
        public String message;

        public EnrollmentResponse(boolean success, String message) {
            this.success = success;
            this.message = message;
        }

        public boolean isSuccess() {
            return success;
        }

        public String getMessage() {
            return message;
        }
    }
}
