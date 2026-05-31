package pwr.zbd.projekt.teaching.domain;

import jakarta.persistence.Embeddable;
import lombok.AllArgsConstructor;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.util.UUID;

/** Złożony klucz tabeli enrollments — ten sam student może być na wielu grupach, ale nie dwa razy na tej samej. */
@Embeddable
@NoArgsConstructor
@AllArgsConstructor
@EqualsAndHashCode
public class EnrollmentId implements Serializable {
    private UUID studentId;
    private UUID courseGroupId;
}
