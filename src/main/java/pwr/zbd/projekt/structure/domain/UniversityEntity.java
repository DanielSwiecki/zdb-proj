package pwr.zbd.projekt.structure.domain;

import jakarta.persistence.*;
import lombok.*;

import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "universities")
@NoArgsConstructor
@Getter
@Setter
@ToString
@EqualsAndHashCode
public class UniversityEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    @Column(unique = true, nullable = false)
    private String name;
    @OneToMany(mappedBy = "university")
    private List<FacultyEntity> facultyList;
}
