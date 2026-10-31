# LocalFix

**Local Problem Reporting & Civic Issue Management**

LocalFix is a Flutter-based civic issue reporting application that enables citizens to report local problems and helps authorities and workers manage, assign, and resolve reported issues efficiently.

## Features

- Report local problems with title, description, category, and severity
- Upload images of reported issues
- Capture problem location using GPS
- View and track submitted reports
- Authority dashboard for managing reports
- Assign reported problems to workers
- Worker dashboard for handling assigned issues
- Update and monitor problem status

## Tech Stack

| Technology | Usage |
|------------|-------|
| Flutter | Application development |
| Dart | Programming language |
| Supabase | Backend and database |
| Supabase Authentication | User authentication |
| Supabase Storage | Image storage |
| GPS / Location Services | Location capture |

## User Roles

**Citizen**  
Reports local problems and tracks their status.

**Authority**  
Reviews reports, assigns workers, and monitors progress.

**Worker**  
Views assigned problems and updates their resolution status.

## Workflow

```text
Citizen
   ↓
Report Problem
   ↓
Authority Review
   ↓
Worker Assignment
   ↓
Problem Resolution
   ↓
Status Update
   ↓
Citizen Tracking
```

## Getting Started

### Prerequisites

- Flutter SDK
- Dart SDK
- Android Studio or VS Code
- A Supabase project

### Installation

Clone the repository:

```bash
git clone https://github.com/your-username/localfix.git
cd localfix
```

Install dependencies:

```bash
flutter pub get
```

### Supabase Configuration

Create a Supabase project and obtain your project URL and publishable key.

Configure them in the application's Supabase configuration file:

```dart
class SupabaseConfig {
  static const String url = 'YOUR_SUPABASE_URL';
  static const String publishableKey = 'YOUR_SUPABASE_PUBLISHABLE_KEY';
}
```

Replace the placeholder values with your own Supabase credentials.

> **Security:** Do not upload private credentials, service-role keys, passwords, or other sensitive secrets to GitHub.

### Run the Application

```bash
flutter run
```

## Project Objective

To provide a simple and transparent platform for citizens, authorities, and workers to collaboratively report, manage, and resolve local civic problems.
