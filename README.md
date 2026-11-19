# TaskFlow

**Plan work. Bring your team together. Track every task.**

TaskFlow is a full-stack project management app for organizing projects, assigning tasks, and following work from a shared Kanban board. It was built as the CodeAlpha Full Stack Development Internship Task 3 project.

## What you can do

- View project and task progress, deadlines, and workload from a dashboard.
- Create projects and tasks, assign teammates, set priorities and due dates, and organize work by labels.
- Move tasks across **To Do**, **In Progress**, **In Review**, and **Completed** on a Kanban board, or use the searchable task list.
- Collaborate with project members through task comments and in-app notifications.
- Manage profiles and project access, with role-based permissions.
- Switch between light and dark themes and use the responsive interface on smaller screens.

## Tech stack

| Area | Tools |
| --- | --- |
| UI | React 19, TypeScript, Vite, Tailwind CSS 4 |
| State and UI | Zustand, Motion, Lucide React, React Hot Toast |
| API | Node.js, Express, TypeScript |
| Authentication | Better Auth, MongoDB adapter |
| Database | MongoDB Native Driver |

## Get started

### Requirements

- Node.js 20.19+ or 22.12+
- npm
- A reachable MongoDB database (local MongoDB or MongoDB Atlas)

### Install and configure

The application and its scripts live in `Frontend/`.

```bash
cd Frontend
npm install
```

Copy the example environment file and set the values for your environment:

```powershell
Copy-Item .env.example .env
```

On macOS or Linux, use `cp .env.example .env` instead. Configure at least:

```dotenv
PORT=3000
NODE_ENV=development
BETTER_AUTH_URL=http://localhost:3000
BETTER_AUTH_SECRET=replace-with-a-long-random-secret
MONGODB_URI=mongodb://127.0.0.1:27017
MONGODB_DB_NAME=taskflow_db
MONGODB_REPLICA_SET=false
```

Use a unique, strong `BETTER_AUTH_SECRET` and keep `.env` private. For MongoDB Atlas, set `MONGODB_URI` to your Atlas connection string and `MONGODB_REPLICA_SET=true`. MongoDB is required; the server will not fall back to local file storage.

### Run locally

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000). The development server runs the React app and Express API together on the same origin.

## Available commands

Run these from `Frontend/`:

| Command | Description |
| --- | --- |
| `npm run dev` | Start the full-stack development server with rebuild-on-change |
| `npm run build` | Build the frontend and bundle the production server |
| `npm start` | Start the production server after building |
| `npm run lint` | Check TypeScript types |
| `npm test` | Run the project test suite |
| `npm run clean` | Remove generated build output |

## Project layout

```text
.
├── README.md
└── Frontend/
    ├── server.ts             # Express entry point and API setup
    ├── server/               # Database, auth, permissions, and API routes
    ├── src/
    │   ├── components/       # React views and reusable UI
    │   ├── lib/              # API client and auth helpers
    │   ├── store/            # Zustand application state
    │   └── types/            # Shared TypeScript types
    ├── scripts/              # Development server and test runner
    ├── .env.example          # Environment variable template
    └── package.json
```

## API overview

The Express API is served from the same origin under `/api`.

| Route | Purpose |
| --- | --- |
| `/api/auth` | Authentication, account, and profile operations |
| `/api/projects` | Projects, members, and project permissions |
| `/api/tasks` | Task creation, filtering, updates, and deletion |
| `/api/comments` | Task discussion threads |
| `/api/notifications` | Notification list and read status |
| `/api/dashboard/stats` | Dashboard metrics |
| `/api/health` | Service health check |

## Deployment

Build and run the app as a Node.js service:

```bash
cd Frontend
npm ci
npm run build
npm start
```

Set `NODE_ENV=production`, `PORT`, `BETTER_AUTH_URL`, `BETTER_AUTH_SECRET`, `MONGODB_URI`, `MONGODB_DB_NAME`, and `MONGODB_REPLICA_SET` in the hosting environment. The host must be able to reach MongoDB. The frontend and API are served by the same Node.js service.

## Project status

TaskFlow is an internship project. Its current access model includes a legacy global admin role in addition to project-level roles, and project membership is added directly rather than through an invitation acceptance flow. Review and adapt authorization and deployment settings before using it for a production team.

## License

No license file is currently included. Contact the project owner before redistributing this repository.
