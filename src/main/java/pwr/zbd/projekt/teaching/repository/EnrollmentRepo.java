package pwr.zbd.projekt.teaching.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import pwr.zbd.projekt.teaching.domain.EnrollmentEntity;
import pwr.zbd.projekt.teaching.domain.EnrollmentId;

@Repository
public interface EnrollmentRepo extends JpaRepository<EnrollmentEntity, EnrollmentId> {
}
