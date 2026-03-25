package pwr.zbd.projekt.teaching.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import pwr.zbd.projekt.teaching.domain.StudyStageEntity;

import java.util.UUID;

@Repository
public interface StudyStageRepo extends JpaRepository<StudyStageEntity, UUID> {
}
