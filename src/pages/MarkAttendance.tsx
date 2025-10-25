import { useState, useEffect } from "react";
import Header from "@/components/Header";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { useToast } from "@/hooks/use-toast";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/contexts/AuthContext";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

interface Student {
  id: string;
  roll_number: string;
  full_name: string;
  present: boolean;
}

interface Class {
  id: string;
  class_name: string;
  class_code: string;
}

const MarkAttendance = () => {
  const [students, setStudents] = useState<Student[]>([]);
  const [classes, setClasses] = useState<Class[]>([]);
  const [selectedClass, setSelectedClass] = useState<string>("");
  const [loading, setLoading] = useState(false);
  const { toast } = useToast();
  const { user } = useAuth();

  useEffect(() => {
    loadClasses();
  }, []);

  useEffect(() => {
    if (selectedClass) {
      loadStudents();
    }
  }, [selectedClass]);

  const loadClasses = async () => {
    const { data, error } = await supabase
      .from("classes")
      .select("*")
      .order("class_name");

    if (error) {
      toast({
        title: "Error loading classes",
        description: error.message,
        variant: "destructive",
      });
    } else {
      setClasses(data || []);
      if (data && data.length > 0) {
        setSelectedClass(data[0].id);
      }
    }
  };

  const loadStudents = async () => {
    if (!selectedClass) return;

    setLoading(true);
    const { data: enrollments, error } = await supabase
      .from("class_enrollments")
      .select(`
        student_id,
        students (
          id,
          roll_number,
          full_name
        )
      `)
      .eq("class_id", selectedClass);

    if (error) {
      toast({
        title: "Error loading students",
        description: error.message,
        variant: "destructive",
      });
    } else {
      const studentData = enrollments?.map((e: any) => ({
        id: e.students.id,
        roll_number: e.students.roll_number,
        full_name: e.students.full_name,
        present: true,
      })) || [];
      setStudents(studentData);
    }
    setLoading(false);
  };

  const toggleAttendance = (id: string) => {
    setStudents((prev) =>
      prev.map((student) =>
        student.id === id ? { ...student, present: !student.present } : student
      )
    );
  };

  const handleSubmit = async () => {
    if (!selectedClass || !user) {
      toast({
        title: "Error",
        description: "Please select a class and ensure you're logged in",
        variant: "destructive",
      });
      return;
    }

    setLoading(true);
    const today = new Date().toISOString().split('T')[0];

    try {
      // Create or get session
      const { data: existingSession, error: sessionFetchError } = await supabase
        .from("attendance_sessions")
        .select("id")
        .eq("class_id", selectedClass)
        .eq("session_date", today)
        .maybeSingle();

      let sessionId: string;

      if (existingSession) {
        sessionId = existingSession.id;
        // Delete existing records for this session
        await supabase
          .from("attendance_records")
          .delete()
          .eq("session_id", sessionId);
      } else {
        // Create new session
        const { data: newSession, error: sessionError } = await supabase
          .from("attendance_sessions")
          .insert({
            class_id: selectedClass,
            session_date: today,
            marked_by: user.id,
          })
          .select()
          .single();

        if (sessionError) throw sessionError;
        sessionId = newSession.id;
      }

      // Insert attendance records
      const records = students.map((s) => ({
        session_id: sessionId,
        student_id: s.id,
        status: s.present ? "PRESENT" : "ABSENT",
      }));

      const { error: recordsError } = await supabase
        .from("attendance_records")
        .insert(records);

      if (recordsError) throw recordsError;

      toast({
        title: "Attendance submitted!",
        description: "Today's attendance has been recorded successfully.",
      });
    } catch (error: any) {
      toast({
        title: "Error submitting attendance",
        description: error.message,
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-background">
      <Header />
      
      <main className="container mx-auto px-4 py-8">
        <div className="max-w-5xl mx-auto">
          <h1 className="text-3xl font-bold text-foreground mb-8 text-center">
            Mark Today's Attendance
          </h1>
          
          <div className="mb-6">
            <label className="block text-sm font-medium mb-2">Select Class</label>
            <Select value={selectedClass} onValueChange={setSelectedClass}>
              <SelectTrigger className="w-full max-w-sm">
                <SelectValue placeholder="Choose a class" />
              </SelectTrigger>
              <SelectContent>
                {classes.map((cls) => (
                  <SelectItem key={cls.id} value={cls.id}>
                    {cls.class_code} - {cls.class_name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          
          {loading ? (
            <div className="text-center py-12">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto mb-4"></div>
              <p className="text-muted-foreground">Loading students...</p>
            </div>
          ) : students.length === 0 ? (
            <div className="text-center py-12 bg-card rounded-lg shadow-md">
              <p className="text-muted-foreground">No students enrolled in this class</p>
            </div>
          ) : (
            <div className="bg-card rounded-lg shadow-md overflow-hidden">
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="bg-primary text-primary-foreground">
                      <th className="px-6 py-4 text-left font-semibold text-sm uppercase tracking-wider">
                        Roll Number
                      </th>
                      <th className="px-6 py-4 text-left font-semibold text-sm uppercase tracking-wider">
                        Student Name
                      </th>
                      <th className="px-6 py-4 text-left font-semibold text-sm uppercase tracking-wider">
                        Toggle Status
                      </th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border">
                    {students.map((student) => (
                      <tr key={student.id} className="hover:bg-muted/50 transition-colors">
                        <td className="px-6 py-4 text-foreground">{student.roll_number}</td>
                        <td className="px-6 py-4 text-foreground">{student.full_name}</td>
                        <td className="px-6 py-4">
                          <div className="flex items-center gap-3">
                            <Switch
                              checked={student.present}
                              onCheckedChange={() => toggleAttendance(student.id)}
                              className="data-[state=checked]:bg-primary"
                            />
                            <span className={`font-medium ${student.present ? 'text-primary' : 'text-muted-foreground'}`}>
                              {student.present ? 'Present' : 'Absent'}
                            </span>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}
          
          {students.length > 0 && (
            <div className="mt-8 text-center">
              <Button 
                onClick={handleSubmit}
                size="lg"
                className="px-12 py-6 text-lg font-medium"
                disabled={loading}
              >
                {loading ? "Submitting..." : "Submit Attendance"}
              </Button>
            </div>
          )}
        </div>
      </main>
    </div>
  );
};

export default MarkAttendance;
