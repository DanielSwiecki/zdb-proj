package pwr.zbd.projekt.teaching.api;

import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import pwr.zbd.projekt.teaching.domain.CourseGroupEntity;
import pwr.zbd.projekt.teaching.domain.EnrollmentId;
import pwr.zbd.projekt.teaching.repository.CourseGroupRepo;
import pwr.zbd.projekt.teaching.repository.EnrollmentRepo;

import java.util.List;
import java.util.UUID;

/**
 * Warstwa REST — jedyny kontroler HTTP w projekcie (grupy zajęciowe + zapisy).
 * <p>
 * Mapowanie URL: {@code /api/course-groups}. Spring deserializuje JSON (POST) do {@link EnrollmentRequest},
 * encje JPA zwracane w GET są serializowane do JSON (Jackson); cykle w grafie obiektów są ucinane
 * adnotacjami {@code @JsonIgnore} na wybranych polach encji.
 */
@RestController
@RequestMapping("/api/course-groups")
@RequiredArgsConstructor
public class CourseGroupController {

    private final CourseGroupRepo courseGroupRepo;
    private final EnrollmentRepo enrollmentRepo;

    /**
     * GET /api/course-groups/count — lekki COUNT w bazie (bez ladowania 10k grup do JSON).
     */
    @GetMapping("/count")
    public ResponseEntity<Long> countCourseGroups() {
        return ResponseEntity.ok(courseGroupRepo.count());
    }

    /**
     * GET /api/course-groups — lista wszystkich grup (JOIN-y wg potrzeb Hibernate; odpowiedź może być duża).
     * Przy dużej skali używaj {@link #countCourseGroups()} zamiast tego endpointu.
     */
    @GetMapping
    public ResponseEntity<List<CourseGroupEntity>> getAllCourseGroups() {
        List<CourseGroupEntity> groups = courseGroupRepo.findAll();
        return ResponseEntity.ok(groups);
    }

    /**
     * GET /api/course-groups/{groupId} — jedna grupa po UUID; 404 gdy brak rekordu.
     */
    @GetMapping("/{groupId}")
    public ResponseEntity<CourseGroupEntity> getCourseGroupById(@PathVariable UUID groupId) {
        return courseGroupRepo.findById(groupId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    /**
     * GET /api/course-groups/{groupId}/students — liczba zapisów w tabeli {@code enrollments}
     * dla danej grupy (zapytanie COUNT po stronie bazy, bez ładowania lazy kolekcji).
     */
    @GetMapping("/{groupId}/students")
    public ResponseEntity<Long> getStudentCountInGroup(@PathVariable UUID groupId) {
        if (!courseGroupRepo.existsById(groupId)) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(enrollmentRepo.countByCourseGroup_Id(groupId));
    }

    /**
     * POST /api/course-groups/{groupId}/enroll — tworzy wiersz w {@code enrollments}.
     * Klucz główny zapisu to para (studentId, courseGroupId) — {@link EnrollmentId}.
     * Body JSON: {@code {"studentId":"<UUID>"}} — ten sam UUID co {@code students.user_id}.
     * Kody: 201 sukces, 409 duplikat zapisu, 400 błąd walidacji / brak grupy lub studenta.
     */
    @PostMapping("/{groupId}/enroll")
    @Transactional
    public ResponseEntity<EnrollmentResponse> enrollStudent(
            @PathVariable UUID groupId,
            @RequestBody EnrollmentRequest request) {
        if (request.getStudentId() == null) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new EnrollmentResponse(false, "Brak studentId"));
        }

        try {
            int inserted = enrollmentRepo.insertIfAbsent(request.getStudentId(), groupId);
            if (inserted == 0) {
                return ResponseEntity.status(HttpStatus.CONFLICT)
                        .body(new EnrollmentResponse(false, "Student już jest zapisany na tę grupę"));
            }
            return ResponseEntity.status(HttpStatus.CREATED)
                    .body(new EnrollmentResponse(true, "Student zapisany na zajęcia"));
        } catch (DataIntegrityViolationException e) {
            String msg = e.getMostSpecificCause() != null ? e.getMostSpecificCause().getMessage() : e.getMessage();
            if (msg != null && msg.contains("course_group_id")) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                        .body(new EnrollmentResponse(false, "Grupa nie znaleziona"));
            }
            if (msg != null && msg.contains("student_id")) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                        .body(new EnrollmentResponse(false, "Student nie znaleziony"));
            }
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(new EnrollmentResponse(false, "Błąd integralności danych"));
        }
    }

    /**
     * DELETE /api/course-groups/{groupId}/unenroll/{studentId} — usuwa rekord zapisu po złożonym kluczu.
     */
    @DeleteMapping("/{groupId}/unenroll/{studentId}")
    @Transactional
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

    /** Ciało żądania POST /enroll — pole musi nazywać się {@code studentId} (Jackson). */
    public static class EnrollmentRequest {
        public UUID studentId;

        public UUID getStudentId() {
            return studentId;
        }

        public void setStudentId(UUID studentId) {
            this.studentId = studentId;
        }
    }

    /** Odpowiedź JSON dla enroll/unenroll — {@code success} + komunikat dla frontu / curl. */
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
