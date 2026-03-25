package pwr.zbd.projekt.users.domain;

import jakarta.persistence.*;
import lombok.*;
import pwr.zbd.projekt.structure.domain.FacultyEntity;

import java.util.UUID;

@Entity
@Table(name = "instructors")
@NoArgsConstructor
@Getter
@Setter
@ToString
@EqualsAndHashCode
public class InstructorEntity {
    @Id
    private UUID userId;

    @MapsId
    @OneToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "user_id")
    private UserEntity user;

    private String title;

    @ManyToOne
    private FacultyEntity faculty;
}
