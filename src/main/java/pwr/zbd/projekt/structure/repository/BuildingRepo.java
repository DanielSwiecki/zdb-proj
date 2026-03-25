package pwr.zbd.projekt.structure.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import pwr.zbd.projekt.structure.domain.BuildingEntity;

import java.util.UUID;

@Repository
public interface BuildingRepo extends JpaRepository<BuildingEntity, UUID> {
}
