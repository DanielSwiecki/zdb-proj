package pwr.zbd.projekt.teaching.domain;

import jakarta.persistence.*;
import lombok.*;
import pwr.zbd.projekt.structure.domain.DegreeProgramEntity;

import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "study_stages")
@NoArgsConstructor
@Getter
@Setter
@ToString
@EqualsAndHashCode
public class StudyStageEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    @ManyToOne
    @JoinColumn(name = "degree_program_id", nullable = false)
    private DegreeProgramEntity degreeProgram;
    @Column(name = "semester_num", nullable = false)
    private Integer semesterNum;
    @Column(name = "academic_year", nullable = false)
    private String academicYear;
    @Enumerated(EnumType.STRING)
    @Column(name = "term_type", nullable = false)
    private TermType termType;

    @ManyToMany
    @JoinTable(
            name = "stage_course",
            joinColumns = @JoinColumn(name = "study_stage_id"),
            inverseJoinColumns = @JoinColumn(name = "course_id")
    )
    private List<CourseEntity> courses;
}
