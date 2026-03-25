CREATE TABLE buildings
(
    id            UUID         NOT NULL,
    name          VARCHAR(255) NOT NULL,
    university_id UUID         NOT NULL,
    CONSTRAINT pk_buildings PRIMARY KEY (id)
);

CREATE TABLE course_groups
(
    id             UUID    NOT NULL,
    course_id      UUID    NOT NULL,
    study_stage_id UUID    NOT NULL,
    instructor_id  UUID    NOT NULL,
    room_id        UUID    NOT NULL,
    group_num      INTEGER NOT NULL,
    capacity       INTEGER NOT NULL,
    CONSTRAINT pk_course_groups PRIMARY KEY (id)
);

CREATE TABLE courses
(
    id                UUID         NOT NULL,
    name              VARCHAR(255) NOT NULL,
    degree_program_id UUID         NOT NULL,
    CONSTRAINT pk_courses PRIMARY KEY (id)
);

CREATE TABLE degree_programs
(
    id         UUID         NOT NULL,
    faculty_id UUID         NOT NULL,
    name       VARCHAR(255) NOT NULL,
    CONSTRAINT pk_degree_programs PRIMARY KEY (id)
);

CREATE TABLE enrollments
(
    grade           INTEGER,
    student_id      UUID NOT NULL,
    course_group_id UUID NOT NULL,
    CONSTRAINT pk_enrollments PRIMARY KEY (student_id, course_group_id)
);

CREATE TABLE faculties
(
    id            UUID NOT NULL,
    university_id UUID NOT NULL,
    CONSTRAINT pk_faculties PRIMARY KEY (id)
);

CREATE TABLE instructors
(
    user_id    UUID NOT NULL,
    title      VARCHAR(255),
    faculty_id UUID,
    CONSTRAINT pk_instructors PRIMARY KEY (user_id)
);

CREATE TABLE rooms
(
    id          UUID         NOT NULL,
    name        VARCHAR(255) NOT NULL,
    building_id UUID         NOT NULL,
    CONSTRAINT pk_rooms PRIMARY KEY (id)
);

CREATE TABLE students
(
    user_id           UUID NOT NULL,
    index             INTEGER,
    degree_program_id UUID NOT NULL,
    CONSTRAINT pk_students PRIMARY KEY (user_id)
);

CREATE TABLE students_stages
(
    status         VARCHAR(255) NOT NULL,
    student_id     UUID         NOT NULL,
    study_stage_id UUID         NOT NULL,
    CONSTRAINT pk_students_stages PRIMARY KEY (student_id, study_stage_id)
);

CREATE TABLE study_stages
(
    id                UUID         NOT NULL,
    degree_program_id UUID         NOT NULL,
    semester_num      INTEGER      NOT NULL,
    academic_year     VARCHAR(255) NOT NULL,
    term_type         VARCHAR(255) NOT NULL,
    CONSTRAINT pk_study_stages PRIMARY KEY (id)
);

CREATE TABLE universities
(
    id   UUID         NOT NULL,
    name VARCHAR(255) NOT NULL,
    CONSTRAINT pk_universities PRIMARY KEY (id)
);

CREATE TABLE users
(
    id         UUID NOT NULL,
    email      VARCHAR(255),
    password   VARCHAR(255),
    first_name VARCHAR(255),
    last_name  VARCHAR(255),
    CONSTRAINT pk_users PRIMARY KEY (id)
);

ALTER TABLE universities
    ADD CONSTRAINT uc_universities_name UNIQUE (name);

ALTER TABLE rooms
    ADD CONSTRAINT uq_building_name UNIQUE (building_id, name);

ALTER TABLE courses
    ADD CONSTRAINT uq_course_name_program UNIQUE (name, degree_program_id);

ALTER TABLE buildings
    ADD CONSTRAINT uq_name_university UNIQUE (name, university_id);

ALTER TABLE degree_programs
    ADD CONSTRAINT uq_program_name_faculty UNIQUE (name, faculty_id);

ALTER TABLE buildings
    ADD CONSTRAINT FK_BUILDINGS_ON_UNIVERSITY FOREIGN KEY (university_id) REFERENCES universities (id);

ALTER TABLE courses
    ADD CONSTRAINT FK_COURSES_ON_DEGREE_PROGRAM FOREIGN KEY (degree_program_id) REFERENCES degree_programs (id);

ALTER TABLE course_groups
    ADD CONSTRAINT FK_COURSE_GROUPS_ON_COURSE FOREIGN KEY (course_id) REFERENCES courses (id);

ALTER TABLE course_groups
    ADD CONSTRAINT FK_COURSE_GROUPS_ON_INSTRUCTOR FOREIGN KEY (instructor_id) REFERENCES instructors (user_id);

ALTER TABLE course_groups
    ADD CONSTRAINT FK_COURSE_GROUPS_ON_ROOM FOREIGN KEY (room_id) REFERENCES rooms (id);

ALTER TABLE course_groups
    ADD CONSTRAINT FK_COURSE_GROUPS_ON_STUDY_STAGE FOREIGN KEY (study_stage_id) REFERENCES study_stages (id);

ALTER TABLE degree_programs
    ADD CONSTRAINT FK_DEGREE_PROGRAMS_ON_FACULTY FOREIGN KEY (faculty_id) REFERENCES faculties (id);

ALTER TABLE enrollments
    ADD CONSTRAINT FK_ENROLLMENTS_ON_COURSE_GROUP FOREIGN KEY (course_group_id) REFERENCES course_groups (id);

ALTER TABLE enrollments
    ADD CONSTRAINT FK_ENROLLMENTS_ON_STUDENT FOREIGN KEY (student_id) REFERENCES students (user_id);

ALTER TABLE faculties
    ADD CONSTRAINT FK_FACULTIES_ON_UNIVERSITY FOREIGN KEY (university_id) REFERENCES universities (id);

ALTER TABLE instructors
    ADD CONSTRAINT FK_INSTRUCTORS_ON_FACULTY FOREIGN KEY (faculty_id) REFERENCES faculties (id);

ALTER TABLE instructors
    ADD CONSTRAINT FK_INSTRUCTORS_ON_USER FOREIGN KEY (user_id) REFERENCES users (id);

ALTER TABLE rooms
    ADD CONSTRAINT FK_ROOMS_ON_BUILDING FOREIGN KEY (building_id) REFERENCES buildings (id);

ALTER TABLE students
    ADD CONSTRAINT FK_STUDENTS_ON_DEGREE_PROGRAM FOREIGN KEY (degree_program_id) REFERENCES degree_programs (id);

ALTER TABLE students
    ADD CONSTRAINT FK_STUDENTS_ON_USER FOREIGN KEY (user_id) REFERENCES users (id);

ALTER TABLE students_stages
    ADD CONSTRAINT FK_STUDENTS_STAGES_ON_STUDENT FOREIGN KEY (student_id) REFERENCES students (user_id);

ALTER TABLE students_stages
    ADD CONSTRAINT FK_STUDENTS_STAGES_ON_STUDY_STAGE FOREIGN KEY (study_stage_id) REFERENCES study_stages (id);

ALTER TABLE study_stages
    ADD CONSTRAINT FK_STUDY_STAGES_ON_DEGREE_PROGRAM FOREIGN KEY (degree_program_id) REFERENCES degree_programs (id);