package pwr.zbd.projekt.teaching.domain;

import jakarta.persistence.*;
import lombok.*;
import pwr.zbd.projekt.structure.domain.RoomEntity;
import pwr.zbd.projekt.users.domain.InstructorEntity;

import java.util.UUID;

@Entity
@Table(name = "course_groups")
@NoArgsConstructor
@Getter
@Setter
@ToString
@EqualsAndHashCode
public class CourseGroupEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    @ManyToOne
    @JoinColumn(name = "course_id", nullable = false)
    private CourseEntity course;
    @ManyToOne
    @JoinColumn(name = "study_stage_id", nullable = false)
    private StudyStageEntity studyStage;
    @ManyToOne
    @JoinColumn(name = "instructor_id", nullable = false)
    private InstructorEntity instructor;
    @ManyToOne
    @JoinColumn(name = "room_id", nullable = false)
    private RoomEntity room;
    @Column(name = "group_num", nullable = false)
    private Integer groupNum;
    @Column(nullable = false)
    private Integer capacity;
}
