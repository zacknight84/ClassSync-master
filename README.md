# 📅 ClassSync — Class Schedule Management System

A full-stack school timetable management application built with **Next.js 14**, **Prisma ORM**, **PostgreSQL** (Supabase), and a custom glassy design system.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/template)

---

## 📖 Project Overview

ClassSync lets school administrators:

- **Manage teachers** with subjects assigned per teacher
- **Mark daily attendance** — `Present`, `Absent`, or `Leave`
- **Auto-assign substitutes** — when a teacher is absent, the system instantly finds a qualified, conflict-free replacement teacher
- **View class schedules** by Day, Week, or Month with live status badges
- **Manage substitutions** — manual override for cases where no substitute is found automatically
- **Track subjects** — create subjects and link them to teachers

---

## 🛠 Tech Stack

| Layer | Technology |
|---|---|
| Framework | Next.js 14 App Router |
| Language | TypeScript |
| ORM | Prisma 5 |
| Database | PostgreSQL (Supabase) |
| Styling | Tailwind CSS + Custom CSS Design System |
| Calendar | react-day-picker |
| Date utils | date-fns |
| Icons | lucide-react |
| Deployment | Railway / Fly.io / Vercel |

---

## 🧠 Architecture Decisions

### Auto-Substitution System

When a teacher is marked **Absent** or **Leave**, the system automatically:

1. Finds all classes scheduled for that teacher on that day of week
2. For each affected class, searches for a substitute teacher who:
   - Teaches the **same subject** (via `Subject` relation)
   - Is **not absent/leave** on that date
   - Has **no schedule conflict** (no existing class at the same time slot)
   - Has **no existing substitute assignment** at that time
3. Creates a `SubstituteAssignment` record:
   - `status: "Assigned"` — substitute found, schedule shows teal "Substituted" badge
   - `status: "NeedsManual"` — no qualified substitute available, shows amber "⚠ Assign" badge
4. Returns results inline in the API response for immediate UI feedback

When the teacher is changed back to **Present**, all substitute assignments for that date are cleared.

### Dynamic Status (no DB mutation)

`ClassSchedule` records in the database are **never mutated** when classes are cancelled or substituted. Instead, `dynamicStatus` is computed at query time in `lib/scheduleLogic.ts` using two bulk queries:
- One for attendance records on the date
- One for substitute assignments for the schedule IDs

This preserves the permanent timetable while surfacing daily operational reality through the API.

---

## 🗃 ER Diagram

```mermaid
erDiagram
    Teacher {
        String id PK
        String name
        String email UK
        Json availability
        DateTime createdAt
    }
    Subject {
        String id PK
        String name
        String teacherId FK
    }
    ClassSection {
        String id PK
        String name
    }
    TeacherAttendance {
        String id PK
        String teacherId FK
        Date date
        String status
    }
    ClassSchedule {
        String id PK
        String dayOfWeek
        String startTime
        String endTime
        String classId FK
        String subjectId FK
        String teacherId FK
    }
    SubstituteAssignment {
        String id PK
        Date date
        String scheduleId FK
        String originalTeacherId FK
        String substituteTeacherId FK
        String status
        String note
    }

    Teacher ||--o{ Subject : "teaches"
    Teacher ||--o{ TeacherAttendance : "has"
    Teacher ||--o{ ClassSchedule : "assigned to"
    Teacher ||--o{ SubstituteAssignment : "original"
    Teacher ||--o{ SubstituteAssignment : "substitute"
    Subject ||--o{ ClassSchedule : "scheduled in"
    ClassSection ||--o{ ClassSchedule : "holds"
    ClassSchedule ||--o{ SubstituteAssignment : "has"
```

---

## 🚀 Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/dev-Lavi/ClassSync.git
cd ClassSync
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Set Up Supabase (PostgreSQL)

1. Go to [supabase.com](https://supabase.com) → **New project**
2. In **Settings → Database → Connection string**:
   - Copy **Pooling** connection (port `6543`) → `DATABASE_URL`
   - Copy **Direct** connection (port `5432`) → `DIRECT_URL`

### 4. Configure Environment Variables

Create `.env.local`:

```env
DATABASE_URL="postgresql://postgres.YOURREF:PASSWORD@aws-1-ap-south-1.pooler.supabase.com:6543/postgres?pgbouncer=true"
DIRECT_URL="postgresql://postgres.YOURREF:PASSWORD@aws-1-ap-south-1.pooler.supabase.com:5432/postgres"
```

### 5. Push Schema and Seed

```bash
npx prisma generate
npx prisma db push
npx tsx prisma/seed.ts
```

### 6. Run Dev Server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

---

## ☁️ Deployment

### Railway (Recommended)

1. Push to GitHub
2. Go to [railway.app](https://railway.app) → **New Project → Deploy from GitHub repo**
3. Add environment variables: `DATABASE_URL`, `DIRECT_URL`
4. Railway auto-detects Next.js and deploys

The `railway.toml` is pre-configured. The `docker-entrypoint.sh` runs `prisma migrate deploy` before starting the server.

### Fly.io

```bash
fly launch
fly secrets set DATABASE_URL="..." DIRECT_URL="..."
fly deploy
```

The `fly.toml` is pre-configured for the Singapore (`sin`) region.

---

## 📡 API Reference

### Teachers
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/teachers` | List all teachers |
| `POST` | `/api/teachers` | Create teacher `{name, email}` |
| `PUT` | `/api/teachers/:id` | Update teacher |
| `DELETE` | `/api/teachers/:id` | Delete teacher |

### Attendance
| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/attendance` | Mark attendance `{teacherId, date, status}` — triggers auto-substitution |
| `GET` | `/api/attendance?date=YYYY-MM-DD` | Get all teacher statuses for a date |

### Substitutions
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/substitutions` | List all substitution records |
| `GET` | `/api/substitutions?date=YYYY-MM-DD` | Filter by date |
| `PATCH` | `/api/substitutions/:id` | Manually assign substitute `{substituteTeacherId}` |

### Subjects
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/subjects` | List all subjects with teacher info |
| `POST` | `/api/subjects` | Create subject `{name, teacherId}` |
| `DELETE` | `/api/subjects/:id` | Delete subject |

### Schedules
| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/schedules` | All schedule entries (static) |
| `POST` | `/api/schedules` | Create entry `{dayOfWeek, startTime, endTime, classId, subjectId, teacherId}` |
| `GET` | `/api/schedules/day?view=day&date=YYYY-MM-DD` | Day view with `dynamicStatus` |
| `GET` | `/api/schedules/week?view=week&start=YYYY-MM-DD` | Week view grouped by day |
| `GET` | `/api/schedules/month?view=month&month=YYYY-MM` | Month view |

#### `dynamicStatus` values
| Value | Meaning |
|---|---|
| `Scheduled` | Teacher present, class runs normally |
| `Substituted` | Teacher absent, substitute auto-assigned |
| `NeedsManual` | Teacher absent, no qualified substitute found |
| `Cancelled` | Teacher absent, no substitute assignment exists |

---

## 🌱 Seed Data

Running `npx tsx prisma/seed.ts` creates:
- **5 teachers**: Dr. Amelia Chen, Mr. James Hartwell, Ms. Priya Nair, Prof. Samuel Owusu, Ms. Elena Vasquez
- **3 class sections**: Class 9A, Class 10B, Class 11C
- **6 subjects**: Mathematics, Physics, English Literature, History, Chemistry, Computer Science
- **16 schedule entries** across Monday–Friday
- **25 attendance records** for week of March 2–6, 2026

---

## 📁 Project Structure

```
class-schedule-system/
├── app/
│   ├── layout.tsx              # Root layout with nav
│   ├── page.tsx                # Dashboard
│   ├── globals.css             # Design system tokens + CSS
│   ├── attendance/             # Daily attendance page
│   ├── teachers/               # Teacher list + add form
│   ├── subjects/               # Subject management
│   ├── schedules/              # Day/Week/Month views + Add Schedule
│   ├── substitutions/          # Substitution history + manual assign
│   └── api/                    # All REST API routes
│       ├── attendance/
│       ├── teachers/
│       ├── subjects/
│       ├── schedules/
│       ├── substitutions/
│       └── class-sections/
├── components/
│   ├── AttendanceTable.tsx     # Teacher rows + inline sub banners
│   ├── TeacherForm.tsx         # Add teacher form
│   └── ScheduleCalendar.tsx    # Day picker calendar
├── lib/
│   ├── prisma.ts               # Singleton Prisma client
│   ├── utils.ts                # Helpers + colour utils
│   ├── scheduleLogic.ts        # Bulk status annotator
│   └── substitutionLogic.ts   # Auto-substitution engine
├── prisma/
│   ├── schema.prisma
│   ├── seed.ts
│   └── migrations/
├── Dockerfile                  # Multi-stage production image
├── docker-compose.yml
├── docker-entrypoint.sh        # Runs migrate deploy then starts server
├── railway.toml
└── fly.toml
```

---

## 🧪 Development Commands

```bash
npm run dev              # Start dev server (localhost:3000)
npm run build            # Production build
npx prisma studio        # GUI database browser
npx prisma db push       # Sync schema (dev)
npx prisma migrate deploy # Apply migrations (production)
npx tsx prisma/seed.ts   # Re-seed database
```
