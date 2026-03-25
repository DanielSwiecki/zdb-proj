package pwr.zbd.projekt.teaching.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import pwr.zbd.projekt.teaching.domain.StudentStageEntity;

import java.util.UUID;

@Repository
public interface StudentStageRepo extends JpaRepository<StudentStageEntity, UUID> {
}
