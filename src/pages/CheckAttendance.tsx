import { useState, useEffect } from "react";
import Header from "@/components/Header";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { supabase } from "@/integrations/supabase/client";
import { useToast } from "@/hooks/use-toast";

interface AttendanceRecord {
  student_id: string;
  roll_number: string;
  full_name: string;
  status: string;
}

interface Class {
  id: string;
  class_name: string;
  class_code: string;
}

const CheckAttendance = () => {
  const [selectedDate, setSelectedDate] = useState<string>(
    new Date().toISOString().split('T')[0]
  );
  const [selectedClass, setSelectedClass] = useState<string>("");
  const [classes, setClasses] = useState<Class[]>([]);
  const [records, setRecords] = useState<AttendanceRecord[]>([]);
  const [hasSearched, setHasSearched] = useState(false);
  const [loading, setLoading] = useState(false);
  const { toast } = useToast();

  useEffect(() => {
    loadClasses();
  }, []);

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

  const fetchAttendance = async () => {
    if (!selectedClass) {
      toast({
        title: "Please select a class",
        variant: "destructive",
      });
      return;
    }

    setLoading(true);
    setHasSearched(true);

    const { data: session, error: sessionError } = await supabase
      .from("attendance_sessions")
      .select("id")
      .eq("class_id", selectedClass)
      .eq("session_date", selectedDate)
      .maybeSingle();

    if (sessionError) {
      toast({
        title: "Error fetching attendance",
        description: sessionError.message,
        variant: "destructive",
      });
      setLoading(false);
      return;
    }

    if (!session) {
      setRecords([]);
      setLoading(false);
      return;
    }

    const { data: attendanceData, error: recordsError } = await supabase
      .from("attendance_records")
      .select(`
        student_id,
        status,
        students (
          roll_number,
          full_name
        )
      `)
      .eq("session_id", session.id);

    if (recordsError) {
      toast({
        title: "Error fetching records",
        description: recordsError.message,
        variant: "destructive",
      });
    } else {
      const formattedRecords = attendanceData?.map((record: any) => ({
        student_id: record.student_id,
        roll_number: record.students.roll_number,
        full_name: record.students.full_name,
        status: record.status,
      })) || [];
      setRecords(formattedRecords);
    }

    setLoading(false);
  };

  return (
    <div className="min-h-screen bg-background">
      <Header />
      
      <main className="container mx-auto px-4 py-8">
        <div className="max-w-5xl mx-auto">
          <h1 className="text-3xl font-bold text-foreground mb-8 text-center">
            Check Attendance by Date
          </h1>
          
          <div className="bg-card rounded-lg shadow-md p-6 mb-8 space-y-4">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium mb-2">Select Class</label>
                <Select value={selectedClass} onValueChange={setSelectedClass}>
                  <SelectTrigger>
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
              
              <div>
                <label className="block text-sm font-medium mb-2">Select Date</label>
                <Input
                  type="date"
                  value={selectedDate}
                  onChange={(e) => setSelectedDate(e.target.value)}
                />
              </div>
            </div>
            
            <div className="text-center">
              <Button 
                onClick={fetchAttendance}
                size="lg"
                className="px-8"
                disabled={loading}
              >
                {loading ? "Loading..." : "Fetch Attendance"}
              </Button>
            </div>
          </div>
          
          {hasSearched && (
            <div className="bg-card rounded-lg shadow-md overflow-hidden">
              <h2 className="text-xl font-semibold text-foreground px-6 py-4 border-b border-border">
                Attendance Records
              </h2>
              
              {records.length === 0 ? (
                <div className="px-6 py-12 text-center text-muted-foreground">
                  No attendance records found for this date.
                </div>
              ) : (
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
                          Status
                        </th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-border">
                      {records.map((record) => (
                        <tr key={record.student_id} className="hover:bg-muted/50 transition-colors">
                          <td className="px-6 py-4 text-foreground">{record.roll_number}</td>
                          <td className="px-6 py-4 text-foreground">{record.full_name}</td>
                          <td className="px-6 py-4">
                            <span className={`font-medium ${
                              record.status === 'PRESENT' ? 'text-primary' : 'text-destructive'
                            }`}>
                              {record.status}
                            </span>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          )}
        </div>
      </main>
    </div>
  );
};

export default CheckAttendance;
