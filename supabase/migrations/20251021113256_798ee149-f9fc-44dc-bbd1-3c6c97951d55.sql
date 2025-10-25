-- ============================================
-- STUDENT ATTENDANCE MANAGEMENT SYSTEM
-- Database Schema Implementation
-- Normalized to BCNF with Advanced SQL Features
-- ============================================

-- Create app_role enum for user roles
CREATE TYPE app_role AS ENUM ('admin', 'teacher', 'student');

-- ============================================
-- PROFILES TABLE (User Information)
-- ============================================
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  role app_role NOT NULL DEFAULT 'teacher',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================
-- USER_ROLES TABLE (Separate role management)
-- ============================================
CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  role app_role NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, role)
);

-- ============================================
-- STUDENTS TABLE (Student Information)
-- ============================================
CREATE TABLE public.students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  roll_number TEXT NOT NULL UNIQUE,
  full_name TEXT NOT NULL,
  email TEXT UNIQUE,
  phone TEXT,
  enrollment_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================
-- CLASSES TABLE (Course/Class Information)
-- ============================================
CREATE TABLE public.classes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_code TEXT NOT NULL UNIQUE,
  class_name TEXT NOT NULL,
  description TEXT,
  teacher_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================
-- CLASS_ENROLLMENTS TABLE (Many-to-Many)
-- ============================================
CREATE TABLE public.class_enrollments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID REFERENCES public.students(id) ON DELETE CASCADE NOT NULL,
  class_id UUID REFERENCES public.classes(id) ON DELETE CASCADE NOT NULL,
  enrolled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(student_id, class_id)
);

-- ============================================
-- ATTENDANCE_SESSIONS TABLE (Session Metadata)
-- ============================================
CREATE TABLE public.attendance_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id UUID REFERENCES public.classes(id) ON DELETE CASCADE NOT NULL,
  session_date DATE NOT NULL,
  marked_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(class_id, session_date)
);

-- ============================================
-- ATTENDANCE_RECORDS TABLE (Individual Records)
-- ============================================
CREATE TABLE public.attendance_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES public.attendance_sessions(id) ON DELETE CASCADE NOT NULL,
  student_id UUID REFERENCES public.students(id) ON DELETE CASCADE NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('PRESENT', 'ABSENT', 'LATE', 'EXCUSED')),
  remarks TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(session_id, student_id)
);

-- ============================================
-- INDEXES FOR PERFORMANCE
-- ============================================
CREATE INDEX idx_students_roll_number ON public.students(roll_number);
CREATE INDEX idx_students_email ON public.students(email);
CREATE INDEX idx_classes_code ON public.classes(class_code);
CREATE INDEX idx_class_enrollments_student ON public.class_enrollments(student_id);
CREATE INDEX idx_class_enrollments_class ON public.class_enrollments(class_id);
CREATE INDEX idx_attendance_sessions_date ON public.attendance_sessions(session_date);
CREATE INDEX idx_attendance_sessions_class ON public.attendance_sessions(class_id);
CREATE INDEX idx_attendance_records_session ON public.attendance_records(session_id);
CREATE INDEX idx_attendance_records_student ON public.attendance_records(student_id);
CREATE INDEX idx_attendance_records_status ON public.attendance_records(status);

-- ============================================
-- TRIGGER FUNCTION: Update updated_at timestamp
-- ============================================
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- TRIGGERS: Automatic timestamp updates
-- ============================================
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_students_updated_at
  BEFORE UPDATE ON public.students
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_classes_updated_at
  BEFORE UPDATE ON public.classes
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_attendance_sessions_updated_at
  BEFORE UPDATE ON public.attendance_sessions
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_attendance_records_updated_at
  BEFORE UPDATE ON public.attendance_records
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================
-- TRIGGER: Auto-create profile on user signup
-- ============================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Teacher'),
    NEW.email,
    'teacher'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- FUNCTION: Calculate attendance percentage
-- ============================================
CREATE OR REPLACE FUNCTION public.calculate_attendance_percentage(
  p_student_id UUID,
  p_class_id UUID DEFAULT NULL,
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL
)
RETURNS NUMERIC AS $$
DECLARE
  total_sessions INTEGER;
  present_count INTEGER;
BEGIN
  -- Count total sessions
  SELECT COUNT(DISTINCT ar.session_id)
  INTO total_sessions
  FROM public.attendance_records ar
  JOIN public.attendance_sessions asess ON ar.session_id = asess.id
  WHERE ar.student_id = p_student_id
    AND (p_class_id IS NULL OR asess.class_id = p_class_id)
    AND (p_start_date IS NULL OR asess.session_date >= p_start_date)
    AND (p_end_date IS NULL OR asess.session_date <= p_end_date);

  -- Count present sessions
  SELECT COUNT(*)
  INTO present_count
  FROM public.attendance_records ar
  JOIN public.attendance_sessions asess ON ar.session_id = asess.id
  WHERE ar.student_id = p_student_id
    AND ar.status = 'PRESENT'
    AND (p_class_id IS NULL OR asess.class_id = p_class_id)
    AND (p_start_date IS NULL OR asess.session_date >= p_start_date)
    AND (p_end_date IS NULL OR asess.session_date <= p_end_date);

  -- Calculate percentage
  IF total_sessions = 0 THEN
    RETURN 0;
  END IF;

  RETURN ROUND((present_count::NUMERIC / total_sessions::NUMERIC) * 100, 2);
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================
-- FUNCTION: Get student attendance summary
-- ============================================
CREATE OR REPLACE FUNCTION public.get_student_attendance_summary(p_student_id UUID)
RETURNS TABLE (
  total_sessions BIGINT,
  present_count BIGINT,
  absent_count BIGINT,
  late_count BIGINT,
  attendance_percentage NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*)::BIGINT as total_sessions,
    COUNT(*) FILTER (WHERE status = 'PRESENT')::BIGINT as present_count,
    COUNT(*) FILTER (WHERE status = 'ABSENT')::BIGINT as absent_count,
    COUNT(*) FILTER (WHERE status = 'LATE')::BIGINT as late_count,
    CASE
      WHEN COUNT(*) = 0 THEN 0
      ELSE ROUND((COUNT(*) FILTER (WHERE status = 'PRESENT')::NUMERIC / COUNT(*)::NUMERIC) * 100, 2)
    END as attendance_percentage
  FROM public.attendance_records
  WHERE student_id = p_student_id;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================
-- SECURITY DEFINER FUNCTION: Check user role
-- ============================================
CREATE OR REPLACE FUNCTION public.has_role(p_user_id UUID, p_role app_role)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = p_user_id AND role = p_role
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

-- ============================================
-- VIEW: Student Attendance Statistics
-- ============================================
CREATE OR REPLACE VIEW public.student_attendance_stats AS
SELECT
  s.id as student_id,
  s.roll_number,
  s.full_name,
  COUNT(DISTINCT ar.session_id) as total_sessions,
  COUNT(*) FILTER (WHERE ar.status = 'PRESENT') as present_count,
  COUNT(*) FILTER (WHERE ar.status = 'ABSENT') as absent_count,
  COUNT(*) FILTER (WHERE ar.status = 'LATE') as late_count,
  CASE
    WHEN COUNT(DISTINCT ar.session_id) = 0 THEN 0
    ELSE ROUND((COUNT(*) FILTER (WHERE ar.status = 'PRESENT')::NUMERIC / COUNT(DISTINCT ar.session_id)::NUMERIC) * 100, 2)
  END as attendance_percentage
FROM public.students s
LEFT JOIN public.attendance_records ar ON s.id = ar.student_id
GROUP BY s.id, s.roll_number, s.full_name;

-- ============================================
-- VIEW: Class Attendance Report
-- ============================================
CREATE OR REPLACE VIEW public.class_attendance_report AS
SELECT
  c.id as class_id,
  c.class_code,
  c.class_name,
  COUNT(DISTINCT asess.id) as total_sessions,
  COUNT(DISTINCT ce.student_id) as enrolled_students,
  COUNT(ar.id) as total_records,
  COUNT(*) FILTER (WHERE ar.status = 'PRESENT') as total_present,
  COUNT(*) FILTER (WHERE ar.status = 'ABSENT') as total_absent,
  CASE
    WHEN COUNT(ar.id) = 0 THEN 0
    ELSE ROUND((COUNT(*) FILTER (WHERE ar.status = 'PRESENT')::NUMERIC / COUNT(ar.id)::NUMERIC) * 100, 2)
  END as overall_attendance_percentage
FROM public.classes c
LEFT JOIN public.attendance_sessions asess ON c.id = asess.class_id
LEFT JOIN public.class_enrollments ce ON c.id = ce.class_id
LEFT JOIN public.attendance_records ar ON asess.id = ar.session_id
GROUP BY c.id, c.class_code, c.class_name;

-- ============================================
-- VIEW: Daily Attendance Summary
-- ============================================
CREATE OR REPLACE VIEW public.daily_attendance_summary AS
SELECT
  asess.session_date,
  c.class_name,
  c.class_code,
  COUNT(ar.id) as total_marked,
  COUNT(*) FILTER (WHERE ar.status = 'PRESENT') as present,
  COUNT(*) FILTER (WHERE ar.status = 'ABSENT') as absent,
  COUNT(*) FILTER (WHERE ar.status = 'LATE') as late,
  p.full_name as marked_by
FROM public.attendance_sessions asess
JOIN public.classes c ON asess.class_id = c.id
LEFT JOIN public.attendance_records ar ON asess.id = ar.session_id
LEFT JOIN public.profiles p ON asess.marked_by = p.id
GROUP BY asess.session_date, c.class_name, c.class_code, p.full_name
ORDER BY asess.session_date DESC;

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.class_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_records ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view all profiles"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

-- User roles policies
CREATE POLICY "Users can view all roles"
  ON public.user_roles FOR SELECT
  TO authenticated
  USING (true);

-- Students policies
CREATE POLICY "Teachers can view all students"
  ON public.students FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Teachers can insert students"
  ON public.students FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Teachers can update students"
  ON public.students FOR UPDATE
  TO authenticated
  USING (true);

CREATE POLICY "Teachers can delete students"
  ON public.students FOR DELETE
  TO authenticated
  USING (true);

-- Classes policies
CREATE POLICY "Users can view all classes"
  ON public.classes FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Teachers can insert classes"
  ON public.classes FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Teachers can update classes"
  ON public.classes FOR UPDATE
  TO authenticated
  USING (true);

CREATE POLICY "Teachers can delete classes"
  ON public.classes FOR DELETE
  TO authenticated
  USING (true);

-- Class enrollments policies
CREATE POLICY "Users can view all enrollments"
  ON public.class_enrollments FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Teachers can manage enrollments"
  ON public.class_enrollments FOR ALL
  TO authenticated
  USING (true);

-- Attendance sessions policies
CREATE POLICY "Users can view all sessions"
  ON public.attendance_sessions FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Teachers can create sessions"
  ON public.attendance_sessions FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = marked_by);

CREATE POLICY "Teachers can update own sessions"
  ON public.attendance_sessions FOR UPDATE
  TO authenticated
  USING (auth.uid() = marked_by);

CREATE POLICY "Teachers can delete own sessions"
  ON public.attendance_sessions FOR DELETE
  TO authenticated
  USING (auth.uid() = marked_by);

-- Attendance records policies
CREATE POLICY "Users can view all attendance records"
  ON public.attendance_records FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Teachers can insert attendance records"
  ON public.attendance_records FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.attendance_sessions
      WHERE id = session_id AND marked_by = auth.uid()
    )
  );

CREATE POLICY "Teachers can update attendance records"
  ON public.attendance_records FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.attendance_sessions
      WHERE id = session_id AND marked_by = auth.uid()
    )
  );

CREATE POLICY "Teachers can delete attendance records"
  ON public.attendance_records FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.attendance_sessions
      WHERE id = session_id AND marked_by = auth.uid()
    )
  );

-- ============================================
-- INSERT SAMPLE DATA FOR TESTING
-- ============================================

-- Insert sample students
INSERT INTO public.students (roll_number, full_name, email, phone) VALUES
('STU001', 'John Doe', 'john.doe@example.com', '555-0001'),
('STU002', 'Mary Smith', 'mary.smith@example.com', '555-0002'),
('STU003', 'Christian Brown', 'christian.brown@example.com', '555-0003'),
('STU004', 'Ron Wilson', 'ron.wilson@example.com', '555-0004'),
('STU005', 'Angelina Davis', 'angelina.davis@example.com', '555-0005'),
('STU006', 'Sophie Miller', 'sophie.miller@example.com', '555-0006'),
('STU007', 'Anne Taylor', 'anne.taylor@example.com', '555-0007'),
('STU008', 'May Anderson', 'may.anderson@example.com', '555-0008'),
('STU009', 'Henry Thomas', 'henry.thomas@example.com', '555-0009'),
('STU010', 'Paul Jackson', 'paul.jackson@example.com', '555-0010');

-- Insert sample class
INSERT INTO public.classes (class_code, class_name, description) VALUES
('CS101', 'Introduction to Computer Science', 'Basic programming and computer science concepts');

-- Insert class enrollments (all students enrolled in CS101)
INSERT INTO public.class_enrollments (student_id, class_id)
SELECT s.id, c.id
FROM public.students s
CROSS JOIN public.classes c
WHERE c.class_code = 'CS101';