package pwr.zbd.projekt.structure.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import pwr.zbd.projekt.structure.domain.UniversityEntity;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface UniversityRepo extends JpaRepository<UniversityEntity, UUID> {
	Optional<UniversityEntity> findByName(String name);
}
