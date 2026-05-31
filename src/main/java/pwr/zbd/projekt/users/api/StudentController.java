package pwr.zbd.projekt.users.api;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pwr.zbd.projekt.users.domain.StudentEntity;
import pwr.zbd.projekt.users.repository.StudentRepo;

import java.util.List;

@RestController
@RequestMapping("/api/students")
@RequiredArgsConstructor
public class StudentController {

    private final StudentRepo studentRepo;

    @GetMapping
    public ResponseEntity<List<StudentEntity>> getAllStudents() {
        List<StudentEntity> students = studentRepo.findAll();
        return ResponseEntity.ok(students);
    }
}