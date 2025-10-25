import { Link } from "react-router-dom";
import Header from "@/components/Header";
import { Button } from "@/components/ui/button";

const Home = () => {
  return (
    <div className="min-h-screen bg-background">
      <Header />
      
      <main className="container mx-auto px-4 py-16">
        <div className="max-w-2xl mx-auto text-center space-y-8">
          <h1 className="text-4xl font-bold text-foreground mb-12">
            Welcome to the Attendance App
          </h1>
          
          <div className="flex flex-col items-center gap-4">
            <Link to="/check-attendance" className="w-full max-w-xs">
              <Button 
                className="w-full py-6 text-lg font-medium"
                size="lg"
              >
                Check Attendance
              </Button>
            </Link>
            
            <Link to="/mark-attendance" className="w-full max-w-xs">
              <Button 
                className="w-full py-6 text-lg font-medium"
                size="lg"
              >
                Today's Attendance
              </Button>
            </Link>
          </div>
        </div>
      </main>
    </div>
  );
};

export default Home;
