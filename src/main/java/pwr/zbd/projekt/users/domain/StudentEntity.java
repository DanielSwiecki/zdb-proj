package pwr.zbd.projekt.users.domain;

import jakarta.persistence.*;
import lombok.*;
import pwr.zbd.projekt.structure.domain.DegreeProgramEntity;

import java.util.UUID;

@Entity
@Table(name = "students")
@NoArgsConstructor
@Getter
@Setter
@ToString
@EqualsAndHashCode
public class StudentEntity {
    @Id
    private UUID userId;

    @MapsId
    @OneToOne
    @JoinColumn(name = "user_id")
    private UserEntity user;

    private Integer index;

    @ManyToOne
    @JoinColumn(name = "degree_program_id", nullable = false)
    private DegreeProgramEntity degreeProgram;
}
