package pwr.zbd.projekt.teaching.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import pwr.zbd.projekt.teaching.domain.CourseGroupEntity;

import java.util.UUID;

@Repository
public interface CourseGroupRepo extends JpaRepository<CourseGroupEntity, UUID> {
}
