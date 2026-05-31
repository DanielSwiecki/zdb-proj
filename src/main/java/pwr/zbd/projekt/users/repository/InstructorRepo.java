package pwr.zbd.projekt.users.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import pwr.zbd.projekt.users.domain.InstructorEntity;

import java.util.UUID;

@Repository
public interface InstructorRepo extends JpaRepository<InstructorEntity, UUID> {
}
