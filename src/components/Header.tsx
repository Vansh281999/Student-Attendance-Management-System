import { Link, useLocation, useNavigate } from "react-router-dom";
import { useAuth } from "@/contexts/AuthContext";
import { Button } from "@/components/ui/button";

const Header = () => {
  const location = useLocation();
  const { signOut, user } = useAuth();
  const navigate = useNavigate();
  
  const isActive = (path: string) => location.pathname === path;
  
  return (
    <header className="bg-primary text-primary-foreground shadow-md">
      <div className="container mx-auto px-4">
        <div className="flex items-center justify-between py-4">
          <Link to="/" className="text-2xl font-bold">
            Attendance App
          </Link>
          
          <nav className="flex items-center gap-6">
            <Link
              to="/"
              className={`text-lg font-medium transition-opacity hover:opacity-80 ${
                isActive("/") ? "underline underline-offset-4" : ""
              }`}
            >
              Home
            </Link>
            <Link
              to="/check-attendance"
              className={`text-lg font-medium transition-opacity hover:opacity-80 ${
                isActive("/check-attendance") ? "underline underline-offset-4" : ""
              }`}
            >
              Check Attendance
            </Link>
            <Link
              to="/mark-attendance"
              className={`text-lg font-medium transition-opacity hover:opacity-80 ${
                isActive("/mark-attendance") ? "underline underline-offset-4" : ""
              }`}
            >
              Mark Attendance
            </Link>
            <Button
              variant="secondary"
              size="sm"
              onClick={async () => {
                await signOut();
                navigate("/auth");
              }}
              className="ml-4"
            >
              Logout
            </Button>
          </nav>
        </div>
      </div>
    </header>
  );
};

export default Header;
