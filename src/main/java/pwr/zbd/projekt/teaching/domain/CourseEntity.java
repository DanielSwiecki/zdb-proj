package pwr.zbd.projekt.teaching.domain;

import jakarta.persistence.*;
import lombok.*;
import pwr.zbd.projekt.structure.domain.DegreeProgramEntity;

import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "courses",
uniqueConstraints = {
        @UniqueConstraint(columnNames = {"name", "degree_program_id"},
        name = "uq_course_name_program")
})
@NoArgsConstructor
@Getter
@Setter
@ToString
@EqualsAndHashCode
public class CourseEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    @Column(nullable = false)
    private String name;
    @ManyToOne
    @JoinColumn(name = "degree_program_id", nullable = false)
    private DegreeProgramEntity program;
}
