package pwr.zbd.projekt.users.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import pwr.zbd.projekt.users.domain.UserEntity;

import java.util.UUID;

@Repository
public interface UserRepo extends JpaRepository<UserEntity, UUID> {
}
