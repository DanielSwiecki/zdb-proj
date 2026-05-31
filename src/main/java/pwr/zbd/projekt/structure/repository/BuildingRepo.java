package pwr.zbd.projekt.structure.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import pwr.zbd.projekt.structure.domain.BuildingEntity;
import pwr.zbd.projekt.structure.domain.UniversityEntity;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface BuildingRepo extends JpaRepository<BuildingEntity, UUID> {
	Optional<BuildingEntity> findByUniversityAndName(UniversityEntity university, String name);
}
