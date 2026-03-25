package pwr.zbd.projekt.teaching.domain;

import jakarta.persistence.*;
import lombok.*;
import pwr.zbd.projekt.users.domain.StudentEntity;

@Entity
@Table(name = "students_stages")
@NoArgsConstructor
@Getter
@Setter
@ToString
@EqualsAndHashCode
public class StudentStageEntity {
    @EmbeddedId
    private StudentStageId studentStageId;

    @ManyToOne
    @MapsId("studentId")
    @JoinColumn(name = "student_id")
    private StudentEntity student;

    @ManyToOne
    @MapsId("stageId")
    @JoinColumn(name = "study_stage_id")
    private StudyStageEntity studyStage;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private Status status;

    public enum Status {
        ACTIVE,
        PASSED,
        FAILED
    }
}
