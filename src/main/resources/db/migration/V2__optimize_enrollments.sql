-- Etap 2 optymalizacji: indeks pod COUNT zapisow per grupa (GET /students)
CREATE INDEX IF NOT EXISTS idx_enrollments_course_group_id ON enrollments (course_group_id);
