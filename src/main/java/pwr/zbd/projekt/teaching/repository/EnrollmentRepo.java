package pwr.zbd.projekt.teaching.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import pwr.zbd.projekt.teaching.domain.EnrollmentEntity;
import pwr.zbd.projekt.teaching.domain.EnrollmentId;

import java.util.UUID;

@Repository
public interface EnrollmentRepo extends JpaRepository<EnrollmentEntity, EnrollmentId> {

    /** Liczba zapisow na grupe — uzywa idx_enrollments_course_group_id. */
    long countByCourseGroup_Id(UUID courseGroupId);

    /**
     * Jeden round-trip do bazy zamiast 3x SELECT + INSERT.
     * Zwraca 1 gdy wstawiono, 0 gdy duplikat (PK).
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query(value = """
            INSERT INTO enrollments (student_id, course_group_id, grade)
            VALUES (:studentId, :courseGroupId, NULL)
            ON CONFLICT (student_id, course_group_id) DO NOTHING
            """, nativeQuery = true)
    int insertIfAbsent(@Param("studentId") UUID studentId, @Param("courseGroupId") UUID courseGroupId);
}
