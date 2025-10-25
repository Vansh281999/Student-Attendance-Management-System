# Student Attendance Management System

A modern web application for managing student attendance built with React, TypeScript, and Supabase. The system provides an intuitive interface for marking and tracking student attendance with real-time updates.

## Features

- 🔐 Secure Authentication
- 📝 Mark Attendance
- 📊 Check Attendance Records
- 📱 Responsive Design
- 🎨 Modern UI with Shadcn/ui
- 🔄 Real-time Updates with Supabase

## Tech Stack

- **Frontend Framework**: React 18 with TypeScript
- **Build Tool**: Vite
- **UI Components**: Shadcn/ui
- **Styling**: TailwindCSS
- **Backend/Database**: Supabase
- **Form Handling**: React Hook Form with Zod validation
- **Data Visualization**: Recharts
- **Routing**: React Router DOM
- **State Management**: React Query

## Prerequisites

Before running this project, make sure you have:

- Node.js (v16 or higher)
- npm or yarn or pnpm
- A Supabase account and project

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Vansh281999/Student-Attendance-Management-System.git
   cd Student-Attendance-Management-System
   ```

2. Install dependencies:
   ```bash
   npm install
   # or
   yarn install
   # or
   pnpm install
   ```

3. Create a `.env` file in the root directory with your Supabase credentials:
   ```env
   VITE_SUPABASE_URL=your_supabase_project_url
   VITE_SUPABASE_ANON_KEY=your_supabase_anon_key
   ```

## Development

To start the development server:

```bash
npm run dev
# or
yarn dev
# or
pnpm dev
```

The application will be available at `http://localhost:5173`

## Building for Production

To create a production build:

```bash
npm run build
# or
yarn build
# or
pnpm build
```

To preview the production build:

```bash
npm run preview
# or
yarn preview
# or
pnpm preview
```

## Project Structure

```
src/
  ├── components/      # Reusable UI components
  ├── contexts/       # React context providers
  ├── hooks/          # Custom React hooks
  ├── integrations/   # External service integrations
  ├── lib/           # Utility functions
  ├── pages/         # Application pages/routes
  └── App.tsx        # Root component
```

## Features in Detail

### Authentication
- Secure user authentication using Supabase Auth
- Protected routes for authenticated users
- User role management

### Attendance Management
- Mark attendance for individual students
- Bulk attendance marking
- View attendance history
- Generate attendance reports

### User Interface
- Responsive design for all screen sizes
- Dark/Light theme support
- Modern and clean UI components
- Interactive data visualizations

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.