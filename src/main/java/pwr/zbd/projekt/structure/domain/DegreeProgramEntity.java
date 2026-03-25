package pwr.zbd.projekt.structure.domain;

import jakarta.persistence.*;
import lombok.*;

import java.util.UUID;

@Entity
@Table(name = "degree_programs",
        uniqueConstraints = {
                @UniqueConstraint(columnNames = {"name", "faculty_id"},
                        name = "uq_program_name_faculty")
        })
@NoArgsConstructor
@Getter
@Setter
@ToString
@EqualsAndHashCode
public class DegreeProgramEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    @ManyToOne
    @JoinColumn(name = "faculty_id", nullable = false)
    private FacultyEntity faculty;
    @Column(nullable = false)
    private String name;
}
