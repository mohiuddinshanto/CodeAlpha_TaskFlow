# TaskFlow — Updated Master Prompt
## Full-Stack Audit, Bug Fixes, Project-Based Privacy & Member Invitation System

### Role

Act as a Senior Full-Stack Engineer, Software Architect, Security Engineer, QA Engineer, and UI/UX Engineer.

Your responsibility is to audit, improve, fix, and extend the existing TaskFlow application.

**IMPORTANT: Do not rebuild the application from scratch.** First understand the existing codebase, architecture, database, authentication, APIs, and UI. Preserve existing working features and coding conventions.

You must implement the requested changes in the existing project, not merely describe them.

---

# 1. Project Overview

TaskFlow is a private, team-based project management application.

Its purpose is to allow users to:
- Create and manage projects.
- Invite other registered users to projects.
- Assign tasks to project members.
- Manage tasks using Kanban boards.
- Communicate through task comments.
- Track project activities and notifications.
- Manage project members and their permissions.

### Core Privacy Principle

Every user can independently register and use TaskFlow.

However, users must NOT be able to browse or access every other user or project.

A user can only access:
1. Their own account and profile.
2. Projects they created.
3. Projects they have joined by accepting an invitation.
4. Members and resources belonging to those projects.

**Project membership is the foundation of authorization and data privacy.**

There is NO global user approval system and NO global Platform Admin role.

---

# 2. Existing Technology Stack

Preserve the existing stack:

### Frontend
- React 19
- TypeScript
- Tailwind CSS v4
- Zustand
- Lucide React
- React Hot Toast

### Backend
- Node.js
- Express.js
- TypeScript
- REST API

### Database
- JSON file database as the default development option.
- MongoDB Native Driver when MONGODB_URI is configured.
- Do not use Mongoose.

### Authentication
- Existing Better Auth integration.
- Verify the actual authentication implementation before making changes.
- Preserve secure cookie/session-based authentication.
- Remove conflicting or unused authentication implementations only after verifying they are genuinely unnecessary.

### Testing
- node:test
- tsx --test

Do not introduce unnecessary dependencies or migrate the stack.

---

# 3. Part A — Complete Existing Application Audit and Bug Fixes

Before implementing new features, inspect the entire project and audit existing functionality.

## A1. Startup, Build and Code Quality

Check:
- Application startup.
- Frontend and backend initialization.
- TypeScript compilation.
- Production build.
- ESLint.
- Existing automated tests.
- Missing imports and incorrect paths.
- Unused dependencies and imports.
- Duplicate React keys.
- Unhandled asynchronous errors.
- Incorrect useEffect cleanup.
- Inconsistent API response structures.

Run the available scripts and fix genuine issues.

Never report a test as PASS if it was not executed successfully.

## A2. Database Audit

Check:
- Database connection and initialization.
- JSON database read/write lifecycle.
- MongoDB Native Driver operations.
- Proper awaiting of database operations.
- Data consistency between JSON and MongoDB implementations.
- ObjectId validation when MongoDB is used.
- Required indexes.
- Duplicate record prevention.
- Database error handling.
- Data persistence after server restart.

Rules:
- Do not use Mongoose.
- Do not delete existing user data.
- Do not run destructive tests against real data.
- Use an isolated test database for audit operations.
- Preserve existing records during schema changes.

## A3. Authentication and Account Security

Verify:
- Registration.
- Login.
- Logout.
- User profile.
- Password security.
- Session persistence after refresh.
- Invalid and expired sessions.
- Protected frontend pages.
- Protected backend APIs.
- Unauthorized requests.
- Private user data exposure.

### Updated Registration Rule

Every successfully registered user becomes an active user immediately.

There is:
- No pending user status.
- No admin approval.
- No Platform Admin bootstrap.
- No ADMIN_EMAIL requirement.

Users can start creating their own projects immediately after registration.

## A4. Project Management

Verify:
- Create project.
- View project.
- Update project.
- Delete project.
- Project ownership.
- Project membership.
- Member invitation.
- Member removal.
- Ownership transfer.
- Project leave functionality.
- Project privacy.

Only project members can access project resources.

## A5. Task Management

Verify:
- Create task.
- Update task.
- Delete task.
- Task assignment.
- Task reassignment.
- Task descriptions.
- Task due dates.
- Task priorities.
- Task status.
- Task labels.
- Task validation.
- Invalid IDs.
- Project membership enforcement.

Supported statuses:
- Todo
- In Progress
- Review
- Completed

Supported priorities:
- Low
- Medium
- High
- Urgent

A task must belong to a valid project.

A task can only be assigned to a member of that project.

## A6. Kanban Board

Verify:
- Correct status columns.
- Drag and drop.
- Status persistence.
- API failure rollback.
- Loading states.
- Empty states.
- Responsive behavior.
- Mobile-friendly task status changes.

## A7. Comments and Notifications

Verify:
- Add comments.
- Edit own comments.
- Delete own comments.
- Admin/Owner moderation according to the permission rules.
- Comment validation.
- Correct project/task association.
- Notification creation.
- Read/unread status.
- Mark all as read.
- Duplicate notification prevention.
- Notification navigation.

## A8. Search, Filter and Sorting

Verify:
- Project search.
- Task search.
- Status filter.
- Priority filter.
- Assignee filter.
- Date filters.
- Combined filters.
- Sorting.
- Reset filters.
- No-result state.

All queries must respect project membership.

## A9. Dashboard

Dashboard statistics must come from actual database records.

Verify:
- Total projects.
- Total tasks.
- Completed tasks.
- Pending tasks.
- Overdue tasks.
- Recent activity.
- Project-specific statistics.

Never use hardcoded statistics.

Users must only see statistics for projects they belong to.

## A10. API and Error Handling

Verify appropriate HTTP status codes:

- 200 — OK
- 201 — Created
- 400 — Bad Request
- 401 — Unauthorized
- 403 — Forbidden
- 404 — Not Found
- 409 — Conflict
- 500 — Internal Server Error

Use consistent response structures.

Never expose:
- Password hashes.
- Session secrets.
- Database credentials.
- Stack traces.
- Internal sensitive information.

## A11. Security Audit

Check:
- Authentication.
- Backend authorization.
- Project-level access control.
- IDOR vulnerabilities.
- NoSQL injection.
- XSS.
- CORS.
- Payload size limits.
- Login/register rate limiting.
- Password security.
- Cookie security.
- Environment variable protection.
- Sensitive data exposure.
- Unauthorized project access.
- Unauthorized task access.
- Unauthorized member access.

**Frontend-only permission checks are not sufficient. All permissions must be enforced by the backend.**

## A12. Responsive UI/UX

Test at:
- 375px
- 425px
- 768px
- 1024px
- 1440px

Check:
- Sidebar.
- Navigation.
- Dashboard.
- Project cards.
- Task cards.
- Kanban columns.
- Modals.
- Forms.
- Member management.
- Notifications.
- Horizontal overflow.
- Mobile interactions.

Preserve the existing design unless a genuine usability issue requires a change.

---

# 4. Part B — Project-Based Privacy and Permission System

This is one of the most important requirements.

## B1. Remove Global User Approval and Global Admin

Completely remove the previously proposed global approval system.

Do not implement:
- Pending user registration.
- User approval dashboard.
- Global admin approval endpoints.
- Platform Admin role.
- ADMIN_EMAIL bootstrap.
- Global user directory accessible to all users.

Every registered user can use TaskFlow independently.

Each project has its own Owner and project-level roles.

## B2. Project-Based Privacy

A user must only see projects they own or have joined.

Example:

Shanto creates:
- Website Redesign
- Mobile App Launch

He invites Rahim and Karim to Website Redesign.

He invites Hasan and Rahim to Mobile App Launch.

Expected access:

| User | Website Redesign | Mobile App Launch |
|---|---|---|
| Shanto | Access | Access |
| Rahim | Access | Access |
| Karim | Access | No Access |
| Hasan | No Access | Access |
| Other User | No Access | No Access |

Important:
- A user cannot see projects they are not a member of.
- A user cannot browse all registered users.
- A user cannot browse another project's members.
- A user cannot access another project's tasks or comments.
- A user cannot access another project's notifications or activity.
- API authorization must enforce all these restrictions.

## B3. User Directory

Do not provide a public/global user directory.

When inviting a user, the Owner/Admin may search for a specific registered user using their exact email address.

The search response must only expose the minimum information necessary for the invitation process.

Do not expose:
- Full user lists.
- Private profile information.
- Password or authentication data.
- Membership information from unrelated projects.

Only registered users can receive invitations.

If an email is not registered, show a clear message that the user must create an account first.

---

# 5. Project Roles and Permissions

Each project has three roles:

1. Owner
2. Admin
3. Member

## Owner

The user who creates a project automatically becomes its Owner.

Owner permissions:
- View project.
- Update project.
- Delete project.
- Create tasks.
- Update tasks.
- Delete tasks.
- Assign tasks.
- Invite members.
- Remove members.
- Promote a member to Admin.
- Demote an Admin to Member.
- Transfer project ownership.
- Manage project settings.
- Moderate comments.
- View project activity and notifications.

The Owner has the highest authority within their project.

## Admin

Admin permissions:
- View project.
- Create and manage tasks.
- Assign tasks.
- Invite members.
- Remove regular Members.
- Manage regular Members.
- Moderate comments.
- View project activity.
- Manage permitted project settings.

Admin restrictions:
- Cannot delete the project.
- Cannot transfer ownership.
- Cannot promote another user to Admin.
- Cannot remove or demote the Owner.
- Cannot override Owner permissions.

## Member

Member permissions:
- View project.
- View project members.
- Create tasks.
- Update permitted task information.
- Update task status.
- Assign tasks where allowed by the project's permission rules.
- Add comments.
- Edit their own comments.
- Delete their own comments.
- View project activity.
- Receive project notifications.
- Leave the project.

Members cannot:
- Invite other members.
- Remove other members.
- Change project roles.
- Delete the project.
- Change ownership.

Use the same permission rules consistently in the backend, frontend, API, and README.

## Ownership Rules

- The Owner cannot leave a project without transferring ownership.
- The Owner can transfer ownership to an existing project member.
- After transfer, the previous Owner becomes a Member unless explicitly assigned another role by the new Owner.
- Non-owner members can leave freely.
- When a member leaves or is removed, their assigned tasks must become unassigned.
- Never delete tasks or comments merely because a member leaves.

---

# 6. Part C — Member Invitation System

Implement an invitation-based membership system.

### Core Rule

A user must explicitly accept an invitation before becoming a member of a project.

Sending an invitation does NOT grant project access.

## C1. Invitation Creation

Owner and Admin can invite an existing registered user using their exact email address.

The invitation should contain:

- Invitation ID.
- Project ID.
- Inviter User ID.
- Invited User ID.
- Invited email.
- Assigned role.
- Invitation status.
- Created timestamp.
- Optional expiration timestamp.

Suggested TypeScript structure:

```ts
interface ProjectInvitation {
  _id: string;
  projectId: string;
  invitedBy: string;
  invitedUserId: string;
  invitedEmail: string;
  role: "admin" | "member";
  status: "pending" | "accepted" | "rejected" | "revoked" | "expired";
  createdAt: Date;
  expiresAt?: Date;
  respondedAt?: Date;
}
```

The invitation system must prevent:
- Inviting the same user multiple times while a pending invitation exists.
- Inviting someone who is already a project member.
- Unauthorized invitation creation.
- Assigning the Owner role through an invitation.
- Unauthorized Admin promotion.

Only the Owner can invite someone directly as Admin.

An Admin can invite users as Member only.

## C2. Invitation Status

Supported statuses:

- pending
- accepted
- rejected
- revoked
- expired

Only pending invitations can be accepted or rejected.

The inviter may revoke a pending invitation.

If expiration is implemented, expired invitations must not be accepted.

## C3. Invitation Notification

When an invitation is created, the invited user receives a notification.

The notification should include:
- Project name.
- Inviter name.
- Invitation role.
- Invitation date.
- Accept action.
- Reject action.

The invited user can view invitations in a dedicated Invitations section or notification area.

## C4. Accept Invitation

When the invited user accepts:

1. Authenticate the user.
2. Verify that the invitation belongs to the authenticated user.
3. Verify that the invitation is still pending.
4. Verify that the invitation has not expired or been revoked.
5. Add the user to the project's members.
6. Apply the invited role.
7. Change invitation status to accepted.
8. Record the response timestamp.
9. Notify the project Owner/Admin.
10. Make the project available in the user's dashboard.

Membership creation and invitation status update must be atomic where the database supports transactions.

For JSON storage, implement safe consistency handling to prevent duplicate membership.

**Only after acceptance can the user access the project.**

## C5. Reject Invitation

When the invited user rejects:

1. Verify invitation ownership.
2. Verify invitation status.
3. Update status to rejected.
4. Record response timestamp.
5. Notify the inviter where appropriate.
6. Do not add the user to project members.
7. Do not expose project resources.

## C6. Invitation Revocation

Owner/Admin can revoke a pending invitation according to their role permissions.

After revocation:
- The invited user cannot accept it.
- The invitation status becomes revoked.
- The project remains inaccessible to that user unless another invitation is accepted.

## C7. Suggested API Endpoints

Follow existing API conventions and avoid duplicate endpoints.

Suggested endpoints:

```http
POST   /api/projects/:projectId/invitations
GET    /api/invitations
GET    /api/projects/:projectId/invitations
PATCH  /api/invitations/:invitationId/accept
PATCH  /api/invitations/:invitationId/reject
PATCH  /api/invitations/:invitationId/revoke
```

Add exact-email user lookup only as a protected invitation-related endpoint.

Every endpoint must enforce authentication and authorization.

## C8. Invitation UI

Implement:
- Invite Members modal.
- Exact email search.
- Role selection.
- Send Invitation action.
- Pending invitation list.
- Received invitations list.
- Accept button.
- Reject button.
- Revoke invitation action.
- Invitation status badges.
- Loading states.
- Error states.
- Empty states.

Use React Hot Toast for feedback.

Do not give invited users access before acceptance.

---

# 7. Part D — Project Membership Management

Inside each project, provide a Members section.

Display only the members of the current project.

Each member card/row should show:
- Name.
- Email where appropriate.
- Avatar or initials.
- Role.
- Join date where available.
- Available actions according to permissions.

Owner can:
- Promote Member to Admin.
- Demote Admin to Member.
- Remove Admin or Member.
- Transfer ownership.

Admin can:
- Manage regular Members according to the permission matrix.
- Remove regular Members.
- Invite regular Members.

Member can:
- View the member list.
- Leave the project.

When a user is removed:
- Revoke their access immediately.
- Unassign their assigned tasks.
- Preserve task history.
- Preserve comments according to the existing data-retention rules.
- Preserve activity records.

Do not leak membership data to non-members.

---

# 8. Part E — Custom Categories and Labels

Allow users to create custom project categories.

Requirements:
- Categories must accept user-entered text.
- Existing categories can be suggestions.
- Use HTML input + datalist where appropriate.
- Do not enforce a hardcoded enum in the backend.
- Trim whitespace.
- Validate length between 1 and 40 characters.
- Sanitize user input.
- Update TypeScript types from restrictive unions to string where appropriate.
- Unknown categories must have a safe default color/icon.

Apply similar flexibility to task labels where appropriate.

Support both create and edit forms.

---

# 9. Part F — Landing Page and Demo Mode

Create a professional logged-out landing page.

Include:
- TaskFlow name.
- Short description.
- Key features.
- Kanban preview or illustration.
- Sign In button.
- Register button.
- Try Demo button.

### Try Demo

A reviewer should be able to enter the demo environment with one click.

The demo experience must not require registration.

Important:
- Demo users must not receive any special global administrator privilege.
- Demo accounts are ordinary users with normal project-level roles.
- All demo accounts must be pre-created and usable.
- Demo users must only see projects where they are members.

### Authentication UI

- Do not flash private project data before authentication completes.
- Expired sessions should redirect cleanly.
- Logged-out users must see the landing/login experience.
- All protected APIs must return 401 without a valid session.

Test at least:
- /api/projects
- /api/tasks
- /api/comments/*
- /api/notifications
- /api/dashboard/stats
- /api/auth/users or its replacement

Do not expose private data through unauthenticated API calls.

---

# 10. Part G — Demo Seed Data

Create realistic demo data.

### Demo Accounts

Use these accounts:

| Email | Role |
|---|---|
| demo.owner@taskflow.test | Project Owner |
| demo.admin@taskflow.test | Project Admin |
| demo.member1@taskflow.test | Member |
| demo.member2@taskflow.test | Member |
| demo.member3@taskflow.test | Member |

Shared demo password:

```text
Demo@12345
```

These are ordinary demo users, not global administrators.

### Demo Projects

Under demo.owner@taskflow.test create:

1. Website Redesign
2. Mobile App Launch

Add the demo users to appropriate projects with realistic project-level roles.

Include:
- All task statuses.
- Mixed priorities.
- Overdue tasks.
- Tasks due this week.
- Custom labels.
- Comments.
- Notifications.
- Activity history.
- Pending invitations for demonstrating the invitation workflow where appropriate.

Ensure the demo Admin and Members have the correct permissions.

### Seed Safety

- Seed must be idempotent.
- Never overwrite real user data.
- Never delete real user data.
- Demo reset must affect demo data only.
- Restore Seed must not destroy real projects.
- Do not create duplicate demo users or projects.

For JSON database deployments, demo changes must persist between sessions and server restarts.

Provide a safe demo reset mechanism.

---

# 11. Part H — Optional Invite Code

Email-based invitations with Accept/Reject are the required implementation.

Invite codes are optional and should only be implemented if they do not delay or compromise the main invitation workflow.

If implemented:
- Owner/Admin can generate codes.
- Codes can be revoked.
- Optional expiration can be supported.
- Only registered users can redeem codes.
- Redeeming a code must still respect project permissions.
- Prevent duplicate membership.

Do not replace the required invitation acceptance flow with automatic code-based membership.

---

# 12. Part I — README Rewrite

Update the README to accurately describe the actual application.

Include:

1. Project overview.
2. Features.
3. Tech stack.
4. Folder structure.
5. Installation.
6. Development commands.
7. Environment variables.
8. Authentication implementation.
9. JSON and MongoDB configuration.
10. Project privacy model.
11. Owner/Admin/Member permissions.
12. Member invitation workflow.
13. Accept/Reject behavior.
14. Demo account credentials.
15. API overview.
16. Testing instructions.
17. Deployment instructions.
18. Known limitations.

Do not document features that are not implemented.

Do not claim real-time functionality unless actual WebSocket or equivalent functionality exists.

Use .env.example and never expose real secrets.

---

# 13. Required Security and Authorization Rules

These rules are mandatory.

1. Every protected endpoint must authenticate the user.
2. Every project endpoint must verify project membership.
3. Every task endpoint must verify membership in the task's project.
4. Every comment endpoint must verify access to the associated project.
5. Every notification endpoint must return only the authenticated user's notifications.
6. Every invitation endpoint must verify the invited user or authorized inviter.
7. Only accepted invitations grant project membership.
8. Only project Owner/Admin can invite users.
9. Only Owner can grant Admin role.
10. A user cannot modify another project's resources.
11. A user cannot access projects by guessing project IDs.
12. Removing a member must revoke access immediately.
13. Frontend hiding is not authorization.
14. No sensitive information may be exposed through user lookup.

Test these cases explicitly.

---

# 14. Implementation Order

Follow this order. Do not jump randomly between features.

### Phase 1 — Understand and Audit
- Inspect the complete codebase.
- Read existing documentation.
- Understand authentication.
- Understand database architecture.
- Run build, tests, lint and TypeScript checks.
- Identify existing issues.

### Phase 2 — Fix Core Architecture
- Fix startup/build errors.
- Fix database lifecycle.
- Fix authentication issues.
- Fix project and task API issues.
- Fix security vulnerabilities.

### Phase 3 — Project-Based Privacy
- Remove Global User Approval.
- Remove Platform Admin.
- Implement project-scoped authorization.
- Implement Owner/Admin/Member permissions.
- Secure user lookup.
- Restrict project and member visibility.

### Phase 4 — Invitation System
- Create invitation data model.
- Implement invitation APIs.
- Implement invitation notifications.
- Implement Accept/Reject.
- Implement Revoke.
- Implement duplicate prevention.
- Implement Members UI.
- Test all permission scenarios.

### Phase 5 — Existing Feature Improvements
- Improve task management.
- Improve Kanban.
- Improve comments.
- Improve notifications.
- Improve dashboard.
- Improve search and filters.
- Add custom categories and labels.

### Phase 6 — Landing and Demo
- Implement landing page.
- Implement Try Demo.
- Prepare demo accounts.
- Seed demo projects and tasks.
- Implement safe demo reset.

### Phase 7 — Responsive UI and Final QA
- Test desktop and mobile.
- Test every role.
- Test invitation workflow.
- Test unauthorized access.
- Test database persistence.
- Test production build.
- Update README.

---

# 15. Testing Requirements

Do not mark a feature as PASS unless it has actually been verified.

At minimum, test the following scenarios.

### Authentication
- New user registration.
- Login.
- Logout.
- Session persistence.
- Invalid session.
- Unauthenticated API access returns 401.

### Project Privacy
- User A creates a project.
- User B cannot access it.
- User B cannot discover its members.
- User B cannot access its tasks.
- User B cannot access its comments.
- User B cannot access its activity.

### Invitation Workflow
- Owner invites a registered user.
- Invited user receives notification.
- Invitation appears in received invitations.
- Invited user can accept.
- Invited user can reject.
- Rejected user remains outside the project.
- Pending invitation does not grant access.
- Revoked invitation cannot be accepted.
- Expired invitation cannot be accepted, if expiration is implemented.
- Duplicate invitations are prevented.
- Already-member users cannot be invited again.
- An unrelated user cannot accept another user's invitation.

### Role Permissions
- Owner can promote Member to Admin.
- Admin cannot promote another Member to Admin.
- Admin cannot remove Owner.
- Member cannot invite users.
- Member cannot change roles.
- Owner can transfer ownership.
- Owner cannot leave without transfer.
- Member can leave.
- Removed member loses access immediately.

### Task Permissions
- Only project members can view tasks.
- Tasks cannot be assigned to non-members.
- Leaving/removing a member unassigns their tasks.
- Task history is preserved.

### Demo
- Try Demo works.
- Demo accounts can log in.
- Demo users see only their projects.
- Demo reset preserves real user data.

### Database
- Data persists after server restart.
- Invitation status persists.
- Membership changes persist.
- No duplicate records.
- Existing real data remains intact.

---

# 16. Development Rules

- Do not rebuild from scratch.
- Do not remove existing working features.
- Do not create mock APIs to simulate completed functionality.
- Do not hardcode dashboard statistics.
- Do not use Mongoose.
- Do not unnecessarily change the technology stack.
- Do not introduce unnecessary dependencies.
- Preserve existing code organization.
- Reuse existing components and utilities where appropriate.
- Keep code readable and maintainable.
- Use proper TypeScript types.
- Validate inputs on the backend.
- Handle loading, success, empty, and error states.
- Do not expose private information.
- Never delete existing user records.
- Use isolated test databases.
- Do not claim unverified work as completed.

If network access is unavailable:
- Do not pretend npm installation succeeded.
- Do not pretend MongoDB was tested.
- Mark unavailable checks as NOT TESTED.
- Continue with the checks that can actually be performed.

If you discover a major architectural problem, explain it before making risky changes.

---

# 17. Final Report Requirements

After completing the work, provide a structured report.

### A. Overall Status
- READY
- PARTIALLY READY
- NOT READY

Explain the reason.

### B. Feature Checklist

For each feature use:

- PASS
- FIXED
- FAIL
- MISSING
- NOT TESTED
- NOT APPLICABLE

### C. Bugs Fixed

For every important bug, mention:
- File path.
- Problem.
- Root cause.
- Fix.
- Verification.

### D. Invitation System Report
- Invitation creation.
- Notification.
- Accept.
- Reject.
- Revoke.
- Expiration, if implemented.
- Duplicate prevention.
- Access control.

### E. Permission and Privacy Report
- Owner permissions.
- Admin permissions.
- Member permissions.
- Project isolation.
- Unauthorized access tests.
- Member removal and task reassignment.

### F. Database Report
- JSON database.
- MongoDB Native Driver.
- Data persistence.
- Migration/schema compatibility.
- Seed safety.

### G. Security Report
- Authentication.
- Authorization.
- IDOR.
- Input validation.
- Session protection.
- Sensitive data exposure.

### H. Final Verification
- Build result.
- TypeScript result.
- Lint result.
- Test result.
- Browser testing.
- Responsive testing.
- Remaining issues.
- Exact totals for PASS, FIXED, FAIL, MISSING and NOT TESTED.

---

# Final Goal

Transform the existing TaskFlow application into a secure, responsive, private, team-based Project Management Platform.

The core user experience must follow this model:

1. Anyone can register and start using TaskFlow.
2. Every user can create their own projects.
3. Every project has one Owner.
4. The Owner can promote other project members to Admin.
5. Owner/Admin can invite registered users.
6. Invited users must explicitly Accept or Reject.
7. Only users who accept invitations become project members.
8. Only project members can see project resources.
9. Users cannot browse unrelated users or projects.
10. Backend authorization must enforce all permissions.

**The most important architectural principle is: TaskFlow is not a globally shared workspace. It is a collection of private projects, each controlled by its own Owner and authorized members.**




# Part F — Public Landing Page, Authentication and Demo Mode

## F1. Public Landing Page

When an unauthenticated visitor opens the TaskFlow website, display a professional public landing page instead of immediately showing the login form.

The landing page must introduce TaskFlow and explain its main features.

### Navbar
Include:
- TaskFlow Logo
- Home
- Features
- About
- Sign In
- Get Started

### Hero Section

Heading:

"Manage Your Projects. Empower Your Team."

Description:

"Organize tasks, collaborate with your team, and track every project from one simple workspace."

Buttons:
- Get Started → Registration page.
- Sign In → Login page.
- Try Demo → Demo environment.

### Dashboard Preview

Show a visually appealing preview or illustration of:
- Project dashboard.
- Kanban board.
- Task cards.
- Team collaboration.

Use static demo visuals only. Never expose real user project data.

### Features Section

Show:
- Project Management.
- Task Management.
- Team Collaboration.
- Kanban Board.
- Member Invitations.
- Notifications.
- Progress Tracking.

### How It Works

Explain:
1. Create an account.
2. Create a project.
3. Invite team members.
4. Accept invitations.
5. Collaborate and manage tasks.

### Footer

Include:
- About.
- Features.
- Contact.
- GitHub.
- Copyright.

## F2. Public Routes

The following pages must be accessible without authentication:

- /
- /features (if implemented)
- /about (if implemented)
- /login
- /register

Do not force unauthenticated visitors directly to the login page when they open the homepage.

## F3. Protected Routes

The following pages require authentication:

- /dashboard
- /projects
- /projects/:projectId
- /tasks
- /notifications
- /invitations
- /settings
- Other private application routes.

If an unauthenticated visitor tries to access a protected route:
- Do not render private page content.
- Redirect to the public landing page or login page.
- Preserve the intended destination if appropriate.
- After successful login, optionally redirect to the original requested page.

## F4. Authenticated Navigation

When a logged-in user opens the homepage:
- Redirect them to /dashboard, or show a clearly authenticated application entry point.
- Do not show unnecessary Sign In/Register buttons.
- Provide access to their private workspace.

When an authenticated user opens /login or /register:
- Redirect them to /dashboard.

## F5. Authentication Loading State

- Do not flash private dashboard content before authentication is verified.
- Show a loading screen or skeleton while checking the session.
- Handle expired sessions cleanly.
- Clear invalid session state.
- Avoid redirect loops.

## F6. Public API vs Protected API

Public:
- Public landing page content.
- Static feature information.
- Authentication registration/login endpoints.

Protected:
- Projects.
- Tasks.
- Comments.
- Notifications.
- Invitations.
- Dashboard statistics.
- Private user profile.
- Project member lookup.

Every protected API must return 401 without a valid session.

Never expose private project or user data through public APIs.

## F7. Try Demo

Provide a Try Demo button on the landing page.

It should allow reviewers to enter a preconfigured demo account with one click.

Demo users must be ordinary users with normal project-level roles.

Do not give demo users global administrator privileges.

Ensure demo users can only access projects where they are actual members.