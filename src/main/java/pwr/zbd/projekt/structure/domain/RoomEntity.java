package pwr.zbd.projekt.structure.domain;

import jakarta.persistence.*;
import lombok.*;

import java.util.UUID;

@Entity
@Table(name = "rooms",
    uniqueConstraints = {
        @UniqueConstraint(columnNames = {"building_id", "name"},
        name = "uq_building_name")
    })
@NoArgsConstructor
@Getter
@Setter
@ToString
@EqualsAndHashCode
public class RoomEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    @Column(nullable = false)
    private String name;
    @ManyToOne
    @JoinColumn(name = "building_id", nullable = false)
    private BuildingEntity building;
}
