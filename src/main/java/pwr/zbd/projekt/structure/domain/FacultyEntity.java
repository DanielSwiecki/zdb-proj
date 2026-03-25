package pwr.zbd.projekt.structure.domain;

import jakarta.persistence.*;
import lombok.*;

import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "faculties")
@NoArgsConstructor
@Getter
@Setter
@ToString
@EqualsAndHashCode
public class FacultyEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    @ManyToOne
    @JoinColumn(name = "university_id", nullable = false)
    private UniversityEntity university;
    private String name;
}
