package pwr.zbd.projekt.structure.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import pwr.zbd.projekt.structure.domain.FacultyEntity;
import pwr.zbd.projekt.structure.domain.UniversityEntity;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface FacultyRepo extends JpaRepository<FacultyEntity, UUID> {
	java.util.List<FacultyEntity> findByUniversityAndName(UniversityEntity university, String name);
}
