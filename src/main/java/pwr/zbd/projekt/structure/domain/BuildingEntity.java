package pwr.zbd.projekt.structure.domain;

import jakarta.persistence.*;
import lombok.*;

import java.util.UUID;

@Entity
@Table(name = "buildings",
    uniqueConstraints = {
        @UniqueConstraint(columnNames = {"name", "university_id"},
        name = "uq_name_university")
    })
@NoArgsConstructor
@Getter
@Setter
@ToString
@EqualsAndHashCode
public class BuildingEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    @Column(nullable = false)
    private String name;
    @ManyToOne
    @JoinColumn(name = "university_id", nullable = false)
    private UniversityEntity university;
}
