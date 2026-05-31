package pwr.zbd.projekt.structure.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import pwr.zbd.projekt.structure.domain.DegreeProgramEntity;
import pwr.zbd.projekt.structure.domain.FacultyEntity;

import java.util.List;
import java.util.UUID;

@Repository
public interface DegreeProgramRepo  extends JpaRepository<DegreeProgramEntity, UUID> {
	List<DegreeProgramEntity> findByFacultyAndName(FacultyEntity faculty, String name);
}
