package pwr.zbd.projekt.teaching.domain;

import jakarta.persistence.*;
import lombok.*;
import pwr.zbd.projekt.users.domain.StudentEntity;

/**
 * Zapis studenta na grupę zajęciową. Klucz główny: {@link EnrollmentId} (student + grupa).
 * {@code @MapsId} przepisuje UUID z powiązanych encji do pól embedowalnego klucza.
 */
@Entity
@Table(name = "enrollments")
@NoArgsConstructor
@Getter
@Setter
@ToString
@EqualsAndHashCode
public class EnrollmentEntity {
    @EmbeddedId
    private EnrollmentId enrollmentId;

    @ManyToOne
    @MapsId("studentId")
    @JoinColumn(name = "student_id")
    private StudentEntity student;

    @ManyToOne
    @MapsId("courseGroupId")
    @JoinColumn(name = "course_group_id")
    private CourseGroupEntity courseGroup;

    private Integer grade;
}
