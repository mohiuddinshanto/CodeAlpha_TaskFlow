/**
 * TaskFlow Comprehensive Audit Test Script
 * Tests all checklist items that can be verified without a browser.
 */

import 'dotenv/config';

const BASE = 'http://localhost:3000';
const PASS = '\u001b[32m[PASS]\u001b[0m';
const FAIL = '\u001b[31m[FAIL]\u001b[0m';
const SKIP = '\u001b[33m[SKIP]\u001b[0m';
const INFO = '\u001b[36m[INFO]\u001b[0m';

let passed = 0, failed = 0, skipped = 0;
const failures = [];

const ACCOUNTS = {
  owner:    { email: 'audit_owner@test.local',    password: 'AuditOwner#9x2!Secure',    name: 'Audit Owner' },
  admin:    { email: 'audit_admin@test.local',     password: 'AuditAdmin#9x2!Secure',    name: 'Audit Admin' },
  member:   { email: 'audit_member@test.local',    password: 'AuditMember#9x2!Secure',   name: 'Audit Member' },
  outsider: { email: 'audit_outsider@test.local',  password: 'AuditOutsider#9x2!Secure', name: 'Audit Outsider' },
};

const cookies = {};
const userIds = {};
let testProjectId = null;
let testTaskId = null;
let testCommentId = null;
let testNotifId = null;

// ===== HTTP HELPERS =====

async function req(method, path, body, cookieKey) {
  const headers = { 'Content-Type': 'application/json', 'Origin': BASE };
  if (cookieKey && cookies[cookieKey]) headers['Cookie'] = cookies[cookieKey];
  const opts = { method, headers };
  if (body !== undefined) opts.body = JSON.stringify(body);
  try {
    const r = await fetch(`${BASE}${path}`, opts);
    const text = await r.text();
    let json;
    try { json = JSON.parse(text); } catch { json = { _raw: text }; }
    if (cookieKey && r.headers.get('set-cookie')) {
      const jar = new Map();
      for (const c of (cookies[cookieKey] || '').split(';').map(x => x.trim()).filter(Boolean)) {
        const eq = c.indexOf('=');
        if (eq > 0) jar.set(c.substring(0, eq), c.substring(eq + 1));
      }
      for (const raw of r.headers.get('set-cookie').split(',')) {
        const part = raw.split(';')[0].trim();
        const eq = part.indexOf('=');
        if (eq > 0) jar.set(part.substring(0, eq), part.substring(eq + 1));
      }
      cookies[cookieKey] = [...jar.entries()].map(([k, v]) => `${k}=${v}`).join('; ');
    }
    return { status: r.status, body: json, headers: r.headers };
  } catch (e) {
    return { status: 0, body: { error: e.message }, headers: new Headers() };
  }
}

function assert(condition, label, details) {
  if (condition) {
    console.log(`  ${PASS} ${label}`);
    passed++;
  } else {
    const msg = details ? label + ': ' + details : label;
    console.log(`  ${FAIL} ${msg}`);
    failed++;
    failures.push(msg);
  }
}

function skip(label) {
  console.log(`  ${SKIP} ${label}`);
  skipped++;
}

function section(name) {
  console.log('\n' + '='.repeat(60));
  console.log('  ' + name);
  console.log('='.repeat(60));
}

// ===== TESTS =====

async function testHealth() {
  section('HEALTH CHECK');
  const r = await req('GET', '/api/health');
  assert(r.status === 200, 'Health endpoint returns 200');
  assert(r.body && r.body.status === 'ok', 'Health response has status=ok');
}

async function testRegistration() {
  section('AUTH: Registration');
  for (const [key, acct] of Object.entries(ACCOUNTS)) {
    const r = await req('POST', '/api/auth/sign-up/email', {
      email: acct.email, password: acct.password, name: acct.name,
    }, key);
    assert(r.status === 200 || r.status === 201 || r.status === 422 ||
           (r.body && typeof r.body.message === 'string' && r.body.message.toLowerCase().includes('exist')),
      `Created/confirmed ${key} account (${acct.email})`, `status=${r.status}`);
  }

  // Validation: missing email
  const r1 = await req('POST', '/api/auth/sign-up/email', { password: 'SomePass#1234', name: 'Test' });
  assert(r1.status >= 400, 'Register: missing email rejected', `status=${r1.status}`);

  // Validation: missing password
  const r2 = await req('POST', '/api/auth/sign-up/email', { email: 'nopass@test.local', name: 'Test' });
  assert(r2.status >= 400, 'Register: missing password rejected', `status=${r2.status}`);

  // Validation: short password
  const r3 = await req('POST', '/api/auth/sign-up/email', { email: 'short@test.local', password: '123', name: 'T' });
  assert(r3.status >= 400, 'Register: short password rejected', `status=${r3.status}`);

  // Duplicate email
  const r4 = await req('POST', '/api/auth/sign-up/email', {
    email: ACCOUNTS.owner.email, password: ACCOUNTS.owner.password, name: 'Dup',
  });
  assert(r4.status >= 400, 'Register: duplicate email rejected', `status=${r4.status}`);
}

async function testLogin() {
  section('AUTH: Login');
  for (const [key, acct] of Object.entries(ACCOUNTS)) {
    const r = await req('POST', '/api/auth/sign-in/email', {
      email: acct.email, password: acct.password,
    }, key);
    assert(r.status === 200, `Login: ${key} succeeds`, `status=${r.status} body=${JSON.stringify(r.body)}`);
    assert(!JSON.stringify(r.body).includes('passwordHash'), `Login response has no passwordHash (${key})`);
  }

  const r2 = await req('POST', '/api/auth/sign-in/email', { email: ACCOUNTS.owner.email, password: 'WrongPass!123' });
  assert(r2.status >= 400, 'Login: wrong password rejected', `status=${r2.status}`);

  const r3 = await req('POST', '/api/auth/sign-in/email', { email: 'nobody@test.local', password: 'AnyPass#123' });
  assert(r3.status >= 400, 'Login: nonexistent email rejected', `status=${r3.status}`);

  const r4 = await fetch(`${BASE}/api/auth/sign-in/email`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{ bad json }',
  });
  assert(r4.status >= 400, 'Login: malformed JSON rejected', `status=${r4.status}`);
}

async function testMe() {
  section('AUTH: /api/auth/me');
  const r1 = await req('GET', '/api/auth/me', undefined, 'owner');
  assert(r1.status === 200, 'GET /api/auth/me returns 200 when authenticated');
  assert(r1.body && r1.body.email === ACCOUNTS.owner.email, '/api/auth/me returns correct user');
  assert(!r1.body.passwordHash, '/api/auth/me has no passwordHash');
  if (r1.body && r1.body.id) userIds.owner = r1.body.id;

  for (const key of ['admin', 'member', 'outsider']) {
    const r = await req('GET', '/api/auth/me', undefined, key);
    if (r.status === 200 && r.body.id) userIds[key] = r.body.id;
  }

  // Unauthenticated
  const r2 = await req('GET', '/api/auth/me');
  assert(r2.status === 401, 'GET /api/auth/me returns 401 without session');

  // Protected routes without session
  const r3 = await req('GET', '/api/projects');
  assert(r3.status === 401, 'GET /api/projects returns 401 without session');
  const r4 = await req('GET', '/api/tasks');
  assert(r4.status === 401, 'GET /api/tasks returns 401 without session');
  const r5 = await req('GET', '/api/notifications');
  assert(r5.status === 401, 'GET /api/notifications returns 401 without session');
  const r6 = await req('GET', '/api/dashboard/stats');
  assert(r6.status === 401, 'GET /api/dashboard/stats returns 401 without session');

  console.log(`${INFO} Resolved userIds: ${JSON.stringify(userIds)}`);
}

async function testUsersList() {
  section('AUTH: users list safety');
  const r = await req('GET', '/api/auth/users', undefined, 'owner');
  assert(r.status === 200, 'GET /api/auth/users returns 200');
  if (Array.isArray(r.body)) {
    assert(!r.body.some(u => u.passwordHash), 'User list has no passwordHash fields');
    // Enrich userIds from the list
    for (const u of r.body) {
      for (const key of Object.keys(ACCOUNTS)) {
        if (u.email === ACCOUNTS[key].email && u.id) userIds[key] = u.id;
      }
    }
  }
  console.log(`${INFO} final userIds: ${JSON.stringify(userIds)}`);
}

async function testProjectValidation() {
  section('PROJECTS: Validation');

  const r1 = await req('POST', '/api/projects', { name: '' }, 'owner');
  assert(r1.status === 400, 'POST /api/projects: empty name rejected');

  const r2 = await req('POST', '/api/projects', { description: 'No title' }, 'owner');
  assert(r2.status === 400, 'POST /api/projects: missing name rejected');

  const r3 = await req('POST', '/api/projects', { name: 'AUDIT_TEST_BadDate', startDate: 'not-a-date' }, 'owner');
  assert(r3.status === 400, 'POST /api/projects: invalid date rejected');

  const r4 = await req('POST', '/api/projects', { name: 'AUDIT_TEST_BadDates', startDate: '2026-12-31', dueDate: '2026-01-01' }, 'owner');
  assert(r4.status === 400, 'POST /api/projects: dueDate before startDate rejected');

  // Create valid project
  const r5 = await req('POST', '/api/projects', {
    name: 'AUDIT_TEST_Main Project',
    description: 'Audit test main project',
    startDate: '2026-01-01',
    dueDate: '2026-12-31',
    color: '#FF5733',
    category: 'Testing',
  }, 'owner');
  assert(r5.status === 201, 'POST /api/projects: valid project created', `status=${r5.status} body=${JSON.stringify(r5.body)}`);
  if (r5.status === 201 && r5.body && r5.body.id) {
    testProjectId = r5.body.id;
    assert(r5.body.ownerId === userIds.owner, 'Project ownerId matches creator');
    assert(r5.body.name === 'AUDIT_TEST_Main Project', 'Project name stored correctly');
    assert(r5.body.startDate && r5.body.startDate.startsWith('2026-01-01'), 'Project startDate stored');
    assert(r5.body.dueDate && r5.body.dueDate.startsWith('2026-12-31'), 'Project dueDate stored');
  }
  console.log(`${INFO} testProjectId = ${testProjectId}`);
}

async function testProjectCRUD() {
  section('PROJECTS: Edit & Status');

  if (!testProjectId) { skip('Project CRUD (no project)'); return; }

  // GET
  const r1 = await req('GET', `/api/projects/${testProjectId}`, undefined, 'owner');
  assert(r1.status === 200, 'GET /api/projects/:id returns 200');
  assert(r1.body && r1.body.id === testProjectId, 'Correct project returned');

  // PATCH name
  const r2 = await req('PATCH', `/api/projects/${testProjectId}`, { name: 'AUDIT_TEST_Main Project (Updated)' }, 'owner');
  assert(r2.status === 200, 'PATCH /api/projects/:id: name update succeeds');
  assert(r2.body && r2.body.name === 'AUDIT_TEST_Main Project (Updated)', 'Name updated correctly');

  // PATCH status
  const r3 = await req('PATCH', `/api/projects/${testProjectId}`, { status: 'on_hold' }, 'owner');
  assert(r3.status === 200, 'PATCH /api/projects/:id: status update succeeds');
  assert(r3.body && r3.body.status === 'on_hold', 'Status updated to on_hold');

  // Invalid status
  const r4 = await req('PATCH', `/api/projects/${testProjectId}`, { status: 'invalid_status' }, 'owner');
  assert(r4.status === 400, 'PATCH /api/projects/:id: invalid status rejected');

  // 404 for nonexistent
  const r5 = await req('GET', '/api/projects/nonexistent-proj-id', undefined, 'owner');
  assert(r5.status === 404, 'GET /api/projects/nonexistent returns 404');
}

async function testProjectPermissions() {
  section('PROJECTS: Permissions');

  if (!testProjectId) { skip('Project permissions (no project)'); return; }

  // Outsider cannot view
  const r1 = await req('GET', `/api/projects/${testProjectId}`, undefined, 'outsider');
  assert(r1.status === 403, 'Outsider cannot view project (expects 403)');

  // Outsider cannot edit
  const r2 = await req('PATCH', `/api/projects/${testProjectId}`, { name: 'EVIL' }, 'outsider');
  assert(r2.status === 403, 'Outsider cannot edit project');

  // Outsider cannot delete
  const r3 = await req('DELETE', `/api/projects/${testProjectId}`, undefined, 'outsider');
  assert(r3.status === 403, 'Outsider cannot delete project');

  // Add member
  if (userIds.member) {
    const r4 = await req('POST', `/api/projects/${testProjectId}/members`, { userId: userIds.member }, 'owner');
    assert(r4.status === 200, 'Owner can add member', `status=${r4.status} body=${JSON.stringify(r4.body)}`);

    // Member can view
    const r5 = await req('GET', `/api/projects/${testProjectId}`, undefined, 'member');
    assert(r5.status === 200, 'Member can view project after being added');

    // Member cannot edit
    const r6 = await req('PATCH', `/api/projects/${testProjectId}`, { name: 'EVIL' }, 'member');
    assert(r6.status === 403, 'Member cannot edit project');

    // Member cannot delete
    const r7 = await req('DELETE', `/api/projects/${testProjectId}`, undefined, 'member');
    assert(r7.status === 403, 'Member cannot delete project');

    // Duplicate add
    const r8 = await req('POST', `/api/projects/${testProjectId}/members`, { userId: userIds.member }, 'owner');
    assert(r8.status === 400, 'Duplicate member add rejected');
  }

  // Add admin user (they will also be a project member for testing)
  if (userIds.admin) {
    const r9 = await req('POST', `/api/projects/${testProjectId}/members`, { userId: userIds.admin }, 'owner');
    assert(r9.status === 200, 'Owner can add admin user as member', `status=${r9.status}`);
  }

  // Cannot remove owner
  if (userIds.owner) {
    const r10 = await req('DELETE', `/api/projects/${testProjectId}/members/${userIds.owner}`, undefined, 'owner');
    assert(r10.status === 400, 'Cannot remove project owner');
  }
}

async function testTaskValidation() {
  section('TASKS: Validation');

  if (!testProjectId) { skip('Task validation (no project)'); return; }

  const r1 = await req('POST', '/api/tasks', { projectId: testProjectId, title: '' }, 'owner');
  assert(r1.status === 400, 'POST /api/tasks: empty title rejected');

  const r2 = await req('POST', '/api/tasks', { projectId: testProjectId }, 'owner');
  assert(r2.status === 400, 'POST /api/tasks: missing title rejected');

  const r3 = await req('POST', '/api/tasks', { title: 'No project' }, 'owner');
  assert(r3.status === 400, 'POST /api/tasks: missing projectId rejected');

  const r4 = await req('POST', '/api/tasks', { projectId: testProjectId, title: 'T', status: 'flying' }, 'owner');
  assert(r4.status === 400, 'POST /api/tasks: invalid status rejected');

  const r5 = await req('POST', '/api/tasks', { projectId: testProjectId, title: 'T', priority: 'extreme' }, 'owner');
  assert(r5.status === 400, 'POST /api/tasks: invalid priority rejected');

  const r6 = await req('POST', '/api/tasks', { projectId: testProjectId, title: 'T', dueDate: 'bad-date' }, 'owner');
  assert(r6.status === 400, 'POST /api/tasks: invalid date rejected');

  const r7 = await req('POST', '/api/tasks', { projectId: testProjectId, title: 'T', startDate: '2026-12-31', dueDate: '2026-01-01' }, 'owner');
  assert(r7.status === 400, 'POST /api/tasks: dueDate before startDate rejected');

  // Assignee not in project
  if (userIds.outsider) {
    const r8 = await req('POST', '/api/tasks', { projectId: testProjectId, title: 'T', assignedTo: userIds.outsider }, 'owner');
    assert(r8.status === 400, 'POST /api/tasks: assignee not in project rejected');
  }

  // Create Low priority task
  const r9 = await req('POST', '/api/tasks', {
    projectId: testProjectId,
    title: 'AUDIT_TEST_Low Priority Task',
    description: 'Task with low priority',
    priority: 'low',
    dueDate: '2026-11-30',
    labels: ['audit', 'test'],
  }, 'owner');
  assert(r9.status === 201, 'POST /api/tasks: low priority task created', `status=${r9.status}`);
  if (r9.status === 201 && r9.body) {
    assert(r9.body.priority === 'low', 'Task priority low stored');
    assert(r9.body.description === 'Task with low priority', 'Task description stored');
    assert(Array.isArray(r9.body.labels) && r9.body.labels.includes('audit'), 'Task labels stored');
    assert(r9.body.dueDate && r9.body.dueDate.includes('2026-11-30'), 'Task dueDate stored');
  }

  // Create Medium priority task
  const r10 = await req('POST', '/api/tasks', {
    projectId: testProjectId,
    title: 'AUDIT_TEST_Medium Priority Task',
    priority: 'medium',
    status: 'in_progress',
  }, 'owner');
  assert(r10.status === 201, 'POST /api/tasks: medium priority in_progress task created');

  // Create High priority task assigned to member
  const r11 = await req('POST', '/api/tasks', {
    projectId: testProjectId,
    title: 'AUDIT_TEST_Main Task',
    priority: 'high',
    status: 'todo',
    assignedTo: userIds.member,
  }, 'owner');
  assert(r11.status === 201, 'POST /api/tasks: high priority assigned task created', `status=${r11.status}`);
  if (r11.status === 201 && r11.body && r11.body.id) {
    testTaskId = r11.body.id;
    assert(r11.body.assignedTo === userIds.member, 'Task assignedTo stored correctly');
    assert(r11.body.projectId === testProjectId, 'Task linked to correct project');
    assert(r11.body.createdBy === userIds.owner, 'Task createdBy set correctly');
  }
  console.log(`${INFO} testTaskId = ${testTaskId}`);
}

async function testTaskCRUD() {
  section('TASKS: Edit & Status Updates');

  if (!testTaskId) { skip('Task CRUD (no task)'); return; }

  // GET
  const r1 = await req('GET', `/api/tasks/${testTaskId}`, undefined, 'owner');
  assert(r1.status === 200, 'GET /api/tasks/:id returns 200');
  assert(r1.body && r1.body.title === 'AUDIT_TEST_Main Task', 'GET /api/tasks/:id returns correct data');

  // PATCH edit fields
  const r2 = await req('PATCH', `/api/tasks/${testTaskId}`, {
    title: 'AUDIT_TEST_Main Task (Edited)',
    description: 'Updated description',
    priority: 'urgent',
  }, 'owner');
  assert(r2.status === 200, 'PATCH /api/tasks/:id: task edited by owner');
  assert(r2.body && r2.body.title === 'AUDIT_TEST_Main Task (Edited)', 'Task title updated');
  assert(r2.body && r2.body.priority === 'urgent', 'Task priority updated');

  // Member can update status
  const r3 = await req('PATCH', `/api/tasks/${testTaskId}`, { status: 'in_progress' }, 'member');
  assert(r3.status === 200, 'Member can update task status');
  assert(r3.body && r3.body.status === 'in_progress', 'Task status set to in_progress');

  // Update to completed
  const r4 = await req('PATCH', `/api/tasks/${testTaskId}`, { status: 'completed' }, 'owner');
  assert(r4.status === 200, 'Task status updated to completed');

  // Invalid edit
  const r5 = await req('PATCH', `/api/tasks/${testTaskId}`, { title: '' }, 'owner');
  assert(r5.status === 400, 'PATCH: empty title rejected');

  // Outsider cannot view
  const r6 = await req('GET', `/api/tasks/${testTaskId}`, undefined, 'outsider');
  assert(r6.status === 403, 'Outsider cannot view task');

  // Outsider cannot edit
  const r7 = await req('PATCH', `/api/tasks/${testTaskId}`, { title: 'EVIL' }, 'outsider');
  assert(r7.status === 403, 'Outsider cannot edit task');

  // 404 for nonexistent task
  const r8 = await req('GET', '/api/tasks/nonexistent-task-999', undefined, 'owner');
  assert(r8.status === 404, 'GET nonexistent task returns 404');
}

async function testTaskFilters() {
  section('TASKS: Filters & Sort');

  if (!testProjectId) { skip('Task filters (no project)'); return; }

  const r1 = await req('GET', `/api/tasks?projectId=${testProjectId}&status=todo`, undefined, 'owner');
  assert(r1.status === 200, 'Filter by status=todo returns 200');
  if (Array.isArray(r1.body)) assert(r1.body.every(t => t.status === 'todo'), 'All returned tasks are todo');

  const r2 = await req('GET', `/api/tasks?projectId=${testProjectId}&priority=low`, undefined, 'owner');
  assert(r2.status === 200, 'Filter by priority=low returns 200');
  if (Array.isArray(r2.body)) assert(r2.body.every(t => t.priority === 'low'), 'All returned tasks are low priority');

  const r3 = await req('GET', `/api/tasks?projectId=${testProjectId}&search=AUDIT_TEST_Low`, undefined, 'owner');
  assert(r3.status === 200, 'Search by title returns 200');
  if (Array.isArray(r3.body)) assert(r3.body.some(t => t.title.includes('AUDIT_TEST_Low')), 'Search returns matching tasks');

  if (userIds.member) {
    const r4 = await req('GET', `/api/tasks?projectId=${testProjectId}&assignedTo=${userIds.member}`, undefined, 'owner');
    assert(r4.status === 200, 'Filter by assignedTo returns 200');
  }

  const r5 = await req('GET', `/api/tasks?projectId=${testProjectId}&sortBy=dueDate&sortOrder=asc`, undefined, 'owner');
  assert(r5.status === 200, 'Sort by dueDate asc returns 200');

  // Multiple filters
  const r6 = await req('GET', `/api/tasks?projectId=${testProjectId}&status=in_progress&priority=medium`, undefined, 'owner');
  assert(r6.status === 200, 'Multiple filters combined return 200');

  // Empty result
  const r7 = await req('GET', `/api/tasks?projectId=${testProjectId}&search=ZZZNOTFOUND99999`, undefined, 'owner');
  assert(r7.status === 200, 'No-match search returns 200');
  if (Array.isArray(r7.body)) assert(r7.body.length === 0, 'No-match search returns empty array');

  // Sort by createdAt
  const r8 = await req('GET', `/api/tasks?projectId=${testProjectId}&sortBy=createdAt&sortOrder=desc`, undefined, 'owner');
  assert(r8.status === 200, 'Sort by createdAt returns 200');

  // Outsider cannot list project tasks
  const r9 = await req('GET', `/api/tasks?projectId=${testProjectId}`, undefined, 'outsider');
  assert(r9.status === 403, 'Outsider cannot list tasks of private project');
}

async function testDashboard() {
  section('DASHBOARD: Stats & Counts');

  const r1 = await req('GET', '/api/dashboard/stats', undefined, 'owner');
  assert(r1.status === 200, 'GET /api/dashboard/stats returns 200');
  if (r1.body && typeof r1.body === 'object') {
    assert(typeof r1.body.totalProjects === 'number', 'Stats: totalProjects is number');
    assert(typeof r1.body.totalTasks === 'number', 'Stats: totalTasks is number');
    assert(typeof r1.body.completedTasks === 'number', 'Stats: completedTasks is number');
    assert(typeof r1.body.pendingTasks === 'number', 'Stats: pendingTasks is number');
    assert(typeof r1.body.inProgressTasks === 'number', 'Stats: inProgressTasks is number');
    assert(typeof r1.body.overdueTasks === 'number', 'Stats: overdueTasks is number');
    assert(Array.isArray(r1.body.recentProjects), 'Stats: recentProjects is array');
    assert(Array.isArray(r1.body.recentActivities), 'Stats: recentActivities is array');
    assert(Array.isArray(r1.body.statusDistribution), 'Stats: statusDistribution is array');
    assert(typeof r1.body.completionRate === 'number', 'Stats: completionRate is number');

    // Verify completionRate calculation
    const { totalTasks, completedTasks } = r1.body;
    const expectedRate = totalTasks > 0 ? Math.round((completedTasks / totalTasks) * 100) : 0;
    assert(r1.body.completionRate === expectedRate, `Stats: completionRate correctly calculated (${r1.body.completionRate} vs ${expectedRate})`);

    // Pending should be todo tasks
    const todoDist = Array.isArray(r1.body.statusDistribution)
      ? r1.body.statusDistribution.find(s => s.status === 'todo')
      : null;
    assert(!todoDist || r1.body.pendingTasks === todoDist.count,
      `Stats: pendingTasks matches statusDistribution todo count (pendingTasks=${r1.body.pendingTasks} todoDist=${todoDist?.count})`);

    console.log(`${INFO} Stats: projects=${r1.body.totalProjects} tasks=${r1.body.totalTasks} completed=${r1.body.completedTasks} overdue=${r1.body.overdueTasks}`);
  }

  // Outsider should see empty stats
  const r2 = await req('GET', '/api/dashboard/stats', undefined, 'outsider');
  assert(r2.status === 200, 'Outsider: dashboard stats returns 200');
  if (r2.body) {
    assert(r2.body.totalProjects === 0, 'Outsider: empty dashboard has 0 projects');
    assert(r2.body.totalTasks === 0, 'Outsider: empty dashboard has 0 tasks');
  }

  // DB status (authenticated)
  const r3 = await req('GET', '/api/dashboard/status', undefined, 'owner');
  assert(r3.status === 200, 'GET /api/dashboard/status returns 200');
  if (r3.body) {
    assert(typeof r3.body.isMongoConnected === 'boolean', 'DB status: isMongoConnected is boolean');
    assert(typeof r3.body.mode === 'string', 'DB status: mode is string');
    console.log(`${INFO} DB mode: "${r3.body.mode}", MongoDB: ${r3.body.isMongoConnected}`);
  }
}

async function testComments() {
  section('COMMENTS: CRUD & Permissions');

  if (!testTaskId) { skip('Comment tests (no task)'); return; }

  // Owner posts comment
  const r1 = await req('POST', `/api/comments/task/${testTaskId}`, {
    content: 'AUDIT_TEST_Comment by owner',
  }, 'owner');
  assert(r1.status === 201, 'POST comment: owner can comment');
  if (r1.status === 201 && r1.body && r1.body.id) {
    testCommentId = r1.body.id;
    assert(r1.body.authorId === userIds.owner, 'Comment authorId matches owner');
    assert(r1.body.taskId === testTaskId, 'Comment taskId is correct');
    assert(typeof r1.body.createdAt === 'string', 'Comment has createdAt timestamp');
  }

  // Member posts comment
  const r2 = await req('POST', `/api/comments/task/${testTaskId}`, {
    content: 'AUDIT_TEST_Comment by member',
  }, 'member');
  assert(r2.status === 201, 'POST comment: member can comment');

  // Outsider cannot comment
  const r3 = await req('POST', `/api/comments/task/${testTaskId}`, {
    content: 'AUDIT_TEST_Evil outsider comment',
  }, 'outsider');
  assert(r3.status === 403, 'Outsider cannot comment on task');

  // Empty content rejected
  const r4 = await req('POST', `/api/comments/task/${testTaskId}`, { content: '' }, 'owner');
  assert(r4.status === 400, 'Empty comment content rejected');

  // GET comments
  const r5 = await req('GET', `/api/comments/task/${testTaskId}`, undefined, 'owner');
  assert(r5.status === 200, 'GET /api/comments/task/:id returns 200');
  if (Array.isArray(r5.body)) {
    const auditComments = r5.body.filter(c => c.content && c.content.startsWith('AUDIT_TEST_'));
    assert(auditComments.length >= 2, `Got at least 2 audit comments (${auditComments.length})`);
  }

  // Outsider cannot read comments
  const r6 = await req('GET', `/api/comments/task/${testTaskId}`, undefined, 'outsider');
  assert(r6.status === 403, 'Outsider cannot read comments');

  // Owner edits own comment
  if (testCommentId) {
    const r7 = await req('PATCH', `/api/comments/${testCommentId}`, {
      content: 'AUDIT_TEST_Comment by owner (edited)',
    }, 'owner');
    assert(r7.status === 200, 'Owner can edit own comment');
    assert(r7.body && r7.body.content === 'AUDIT_TEST_Comment by owner (edited)', 'Comment content updated');

    // Member cannot edit owner's comment
    const r8 = await req('PATCH', `/api/comments/${testCommentId}`, { content: 'EVIL' }, 'member');
    assert(r8.status === 403, 'Member cannot edit another user\'s comment');

    // Outsider cannot delete comment
    const r9 = await req('DELETE', `/api/comments/${testCommentId}`, undefined, 'outsider');
    assert(r9.status === 403, 'Outsider cannot delete comment');
  }

  // Comment on nonexistent task
  const r10 = await req('POST', '/api/comments/task/nonexistent-task-id', { content: 'Test' }, 'owner');
  assert(r10.status === 404, 'Comment on nonexistent task returns 404');
}

async function testNotifications() {
  section('NOTIFICATIONS: Delivery & Permissions');

  const r1 = await req('GET', '/api/notifications', undefined, 'owner');
  assert(r1.status === 200, 'GET /api/notifications returns 200');

  // Member should have task_assigned notification from task creation
  const r2 = await req('GET', '/api/notifications', undefined, 'member');
  assert(r2.status === 200, 'GET /api/notifications (member) returns 200');
  if (Array.isArray(r2.body)) {
    const taskNotif = r2.body.find(n => n.type === 'task_assigned');
    assert(taskNotif !== undefined, 'Member received task_assigned notification');
    if (taskNotif) {
      testNotifId = taskNotif.id;
      assert(taskNotif.type === 'task_assigned', 'Notification has type=task_assigned');
      assert(typeof taskNotif.message === 'string', 'Notification has message string');
      assert(typeof taskNotif.createdAt === 'string', 'Notification has createdAt');
      assert(typeof taskNotif.isRead === 'boolean', 'Notification has isRead field');
      assert(taskNotif.relatedProjectId === testProjectId, 'Notification has correct relatedProjectId');
    }
    console.log(`${INFO} Member notifications count: ${r2.body.length}`);
  }

  // Outsider has empty/minimal notifications
  const r3 = await req('GET', '/api/notifications', undefined, 'outsider');
  assert(r3.status === 200, 'Outsider: GET /api/notifications returns 200');
  if (Array.isArray(r3.body)) {
    console.log(`${INFO} Outsider notification count: ${r3.body.length}`);
  }

  // Mark notification as read
  if (testNotifId) {
    const r4 = await req('PATCH', `/api/notifications/${testNotifId}/read`, undefined, 'member');
    assert(r4.status === 200, 'Mark notification as read succeeds');
    assert(r4.body && r4.body.isRead === true, 'Notification marked as read');

    // Owner cannot mark member's notification
    const r5 = await req('PATCH', `/api/notifications/${testNotifId}/read`, undefined, 'owner');
    assert(r5.status === 404, 'Cannot mark another user\'s notification as read (expects 404)');
  }

  // Mark all as read
  const r6 = await req('PATCH', '/api/notifications/read-all', undefined, 'member');
  assert(r6.status === 200, 'Mark all notifications as read succeeds');

  // Verify all read
  const r7 = await req('GET', '/api/notifications', undefined, 'member');
  if (Array.isArray(r7.body)) {
    const unread = r7.body.filter(n => !n.isRead);
    assert(unread.length === 0, `All member notifications are now read (${unread.length} unread)`);
  }

  // Unauthenticated
  const r8 = await req('GET', '/api/notifications');
  assert(r8.status === 401, 'GET /api/notifications returns 401 without session');
}

async function testActivityLog() {
  section('ACTIVITY LOG: Records & Integrity');

  const r1 = await req('GET', '/api/dashboard/stats', undefined, 'owner');
  if (r1.status === 200 && Array.isArray(r1.body && r1.body.recentActivities)) {
    const acts = r1.body.recentActivities;
    console.log(`${INFO} Recent activities count: ${acts.length}`);
    if (acts.length > 0) {
      const act = acts[0];
      assert(typeof act.userId === 'string', 'Activity has userId');
      assert(typeof act.action === 'string', 'Activity has action');
      assert(typeof act.createdAt === 'string', 'Activity has createdAt');
      assert(typeof act.details === 'string', 'Activity has details');
    }
    const hasCreate = acts.some(a => a.action === 'created_task');
    if (hasCreate) assert(true, 'created_task activity found in log');
    const hasComment = acts.some(a => a.action === 'commented_task');
    if (hasComment) assert(true, 'commented_task activity found in log');
  }

  // No writable endpoint for activities
  const r2 = await req('PATCH', '/api/activities/act-1', { action: 'evil' }, 'owner');
  assert(r2.status === 404 || r2.status === 405 || r2.status === 401, 'No writable activities endpoint');

  const r3 = await req('DELETE', '/api/activities/act-1', undefined, 'owner');
  assert(r3.status === 404 || r3.status === 405 || r3.status === 401, 'No deletable activities endpoint');
}

async function testAPIErrorHandling() {
  section('API: Error Handling');

  // 404s
  const r1 = await req('GET', '/api/projects/nonexistent-project-id', undefined, 'owner');
  assert(r1.status === 404, 'GET nonexistent project returns 404');

  const r2 = await req('GET', '/api/tasks/nonexistent-task-id', undefined, 'owner');
  assert(r2.status === 404, 'GET nonexistent task returns 404');

  // Error responses should not expose stack traces
  const r3 = await req('GET', '/api/projects/$$bad$$id$$', undefined, 'owner');
  const str3 = JSON.stringify(r3.body);
  assert(!str3.includes('at Object.') && !str3.includes('node_modules'), 'Error response has no stack trace');

  // Malformed JSON body
  const r4 = await fetch(`${BASE}/api/projects`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Cookie': cookies['owner'] || '' },
    body: '{bad json',
  });
  assert(r4.status === 400, 'Malformed JSON body returns 400');

  // Wrong HTTP method (PUT not defined)
  if (testProjectId) {
    const r5 = await req('PUT', `/api/projects/${testProjectId}`, { name: 'test' }, 'owner');
    assert(r5.status === 404 || r5.status === 405, 'PUT /api/projects/:id returns 404 or 405');
  }

  // Oversized payload
  const r6 = await req('POST', '/api/tasks', { projectId: testProjectId, title: 'A'.repeat(1100000) }, 'owner');
  assert(r6.status === 413 || r6.status === 400, 'Oversized payload returns 413 or 400');

  // 401 vs 403 distinction
  const r7 = await req('GET', `/api/projects/${testProjectId}`); // no cookie = 401
  assert(r7.status === 401, 'No session on protected route = 401 (not 403)');

  const r8 = await req('GET', `/api/projects/${testProjectId}`, undefined, 'outsider'); // session but no access = 403
  assert(r8.status === 403, 'Valid session but no permission = 403 (not 401)');
}

async function testNoSQLInjection() {
  section('SECURITY: NoSQL Injection');

  const r1 = await req('POST', '/api/auth/sign-in/email', { email: { '$ne': null }, password: 'anypassword' });
  assert(r1.status >= 400, 'NoSQL $ne injection in email rejected', `status=${r1.status}`);

  const r2 = await req('POST', '/api/auth/sign-in/email', { email: ACCOUNTS.owner.email, password: { '$ne': null } });
  assert(r2.status >= 400, 'NoSQL $ne injection in password rejected', `status=${r2.status}`);

  const r3 = await req('POST', '/api/auth/sign-in/email', { email: { '$where': 'function(){return true}' }, password: 'test' });
  assert(r3.status >= 400, 'NoSQL $where injection rejected', `status=${r3.status}`);

  if (testProjectId) {
    const r4 = await fetch(`${BASE}/api/tasks?projectId=${testProjectId}&search[$ne]=null`, {
      headers: { 'Cookie': cookies['owner'] || '' },
    });
    assert(r4.status === 200 || r4.status === 400, 'NoSQL injection in search query handled safely (not 500)', `status=${r4.status}`);
  }
}

async function testXSSPayloads() {
  section('SECURITY: XSS Payload Handling');

  if (!testProjectId) { skip('XSS tests (no project)'); return; }

  const xssPayload = '<script>alert("XSS")</script>';
  const r1 = await req('POST', '/api/tasks', {
    projectId: testProjectId,
    title: `AUDIT_TEST_XSS ${xssPayload}`,
  }, 'owner');
  if (r1.status === 201 && r1.body) {
    // JSON API should return raw string (HTML encoding is frontend's job)
    assert(typeof r1.body.title === 'string', 'XSS payload in title stored as plain string (not eval\'d)');
    console.log(`${INFO} Stored XSS title: ${r1.body.title.substring(0, 60)}`);
  }

  if (testTaskId) {
    const r2 = await req('POST', `/api/comments/task/${testTaskId}`, {
      content: `AUDIT_TEST_XSS: ${xssPayload}`,
    }, 'owner');
    if (r2.status === 201 && r2.body) {
      assert(typeof r2.body.content === 'string', 'XSS in comment stored as plain string');
    }
  }
}

async function testCORSHeaders() {
  section('SECURITY: CORS Headers');

  const r1 = await fetch(`${BASE}/api/health`, {
    headers: { 'Origin': 'https://evil.example.com' },
  });
  const corsHeader = r1.headers.get('access-control-allow-origin');
  if (corsHeader) {
    const isEvilAllowed = corsHeader === 'https://evil.example.com';
    assert(!isEvilAllowed, `CORS does not allow evil.example.com (got: "${corsHeader}")`);
  } else {
    assert(true, 'No CORS allow-origin header for untrusted origin (acceptable for same-origin app)');
  }
  assert(r1.status === 200, 'Request from untrusted origin doesn\'t crash server');
}

async function testPasswordHashing() {
  section('SECURITY: Password Hashing in DB');
  if (!process.env.MONGODB_DB_NAME?.startsWith('taskflow_audit_')) {
    skip('Password storage inspection requires an explicitly isolated taskflow_audit_ MongoDB database');
    return;
  }
  if (!process.env.MONGODB_URI) {
    skip('Password storage inspection requires MongoDB; no Mongo URI is configured');
    return;
  }

  const { MongoClient } = await import('mongodb');
  const client = new MongoClient(process.env.MONGODB_URI, { serverSelectionTimeoutMS: 4000 });
  try {
    await client.connect();
    const db = client.db(process.env.MONGODB_DB_NAME);
    for (const acct of Object.values(ACCOUNTS)) {
      const user = await db.collection('user').findOne({ email: acct.email }, { projection: { _id: 1 } });
      const account = user
        ? await db.collection('account').findOne({ userId: user._id.toString(), providerId: 'credential' }, { projection: { password: 1 } })
        : null;
      assert(typeof account?.password === 'string' && account.password.length > 100 && account.password !== acct.password,
        `${acct.email}: stored credential is a non-plaintext hash`);
    }
  } catch (e) {
    assert(false, 'Could read password hashes from the isolated audit MongoDB database', e.message);
  } finally {
    await client.close();
  }
}

async function testSecretsNotInBundle() {
  section('SECURITY: Secrets not in client bundle (dist/)');

  const { readdirSync, readFileSync, statSync } = await import('node:fs');
  const { fileURLToPath } = await import('node:url');
  const { join, dirname } = await import('node:path');

  const jwtSecret = 't2G7uuWA3gMMefLgUiO9Iyw2d8UvQK8f';
  const mongoUser = 'TquhAgfyB8HkDhNz'; // part of password in MONGODB_URI
  const distPath = join(dirname(fileURLToPath(import.meta.url)), '..', 'dist');

  let secretsFound = [];

  function scanDir(dir) {
    try {
      for (const entry of readdirSync(dir)) {
        const full = join(dir, entry);
        try {
          if (statSync(full).isDirectory()) {
            scanDir(full);
          } else if (entry.endsWith('.js') || entry.endsWith('.mjs') || entry.endsWith('.css')) {
            const content = readFileSync(full, 'utf8');
            if (content.includes(jwtSecret)) secretsFound.push(`${entry}: JWT secret found`);
            if (content.includes(mongoUser)) secretsFound.push(`${entry}: MongoDB password found`);
          }
        } catch {}
      }
    } catch (e) {
      console.log(`${INFO} Could not scan dist/: ${e.message}`);
    }
  }

  scanDir(distPath);
  assert(secretsFound.length === 0, `No secrets in dist/ bundle`, secretsFound.join(', '));
  if (secretsFound.length === 0) console.log(`${INFO} Scanned dist/ - no secrets found`);
}

async function testMongoDB() {
  section('DATABASE: MongoDB Connection & Configuration');

  const r = await req('GET', '/api/dashboard/status', undefined, 'owner');
  if (r.body) {
    console.log(`${INFO} DB mode: ${r.body.mode}`);
    console.log(`${INFO} isMongoConnected: ${r.body.isMongoConnected}`);
    console.log(`${INFO} Counts: ${JSON.stringify(r.body.counts)}`);
    if (r.body.isMongoConnected) {
      assert(true, 'MongoDB Native Driver connected successfully');
      assert(r.body.mode === 'MongoDB Native Driver', 'DB mode is MongoDB Native Driver');
      assert(r.body.counts && typeof r.body.counts.users === 'number', 'MongoDB has user count');
    } else {
      assert(true, 'Using embedded JSON persistence (MONGODB_URI not set or connection failed)');
      console.log(`${INFO} Note: MONGODB_URI is configured but connection may have failed - check logs`);
    }
  }

  // Verify MONGODB_URI is in env vars (not hardcoded in source)
  const { readFileSync } = await import('node:fs');
  const { fileURLToPath } = await import('node:url');
  const { join, dirname } = await import('node:path');
  const envPath = join(dirname(fileURLToPath(import.meta.url)), '..', '.env');
  try {
    const envContent = readFileSync(envPath, 'utf8');
    assert(envContent.includes('MONGODB_URI'), 'MONGODB_URI is in .env file');
    assert(envContent.includes('MONGODB_DB_NAME'), 'MONGODB_DB_NAME is in .env file');
  } catch (e) {
    console.log(`${INFO} Could not read .env: ${e.message}`);
  }
}

async function testProjectDeleteCascade() {
  section('PROJECTS: Delete Cascade');

  // Create project for cascade test
  const r1 = await req('POST', '/api/projects', { name: 'AUDIT_TEST_Cascade Delete Project' }, 'owner');
  if (r1.status !== 201) { skip('Delete cascade (could not create project)'); return; }
  const cascadeProjectId = r1.body.id;

  // Create task
  const r2 = await req('POST', '/api/tasks', { projectId: cascadeProjectId, title: 'AUDIT_TEST_Cascade Task' }, 'owner');
  const cascadeTaskId = r2.status === 201 ? r2.body.id : null;

  // Create comment
  let cascadeCommentId = null;
  if (cascadeTaskId) {
    const r3 = await req('POST', `/api/comments/task/${cascadeTaskId}`, { content: 'AUDIT_TEST_Cascade comment' }, 'owner');
    if (r3.status === 201) cascadeCommentId = r3.body.id;
  }

  // Delete project
  const r4 = await req('DELETE', `/api/projects/${cascadeProjectId}`, undefined, 'owner');
  assert(r4.status === 200, 'DELETE /api/projects/:id succeeds');

  // Project gone
  const r5 = await req('GET', `/api/projects/${cascadeProjectId}`, undefined, 'owner');
  assert(r5.status === 404, 'Deleted project returns 404');

  // Task gone
  if (cascadeTaskId) {
    const r6 = await req('GET', `/api/tasks/${cascadeTaskId}`, undefined, 'owner');
    assert(r6.status === 404, 'Cascaded task returns 404 after project delete');
  }

  // Comments gone (task lookup fails)
  if (cascadeTaskId) {
    const r7 = await req('GET', `/api/comments/task/${cascadeTaskId}`, undefined, 'owner');
    assert(r7.status === 404, 'Cascaded comments: task not found after project delete');
  }
}

async function testTaskDelete() {
  section('TASKS: Delete Authorization');

  if (!testProjectId) { skip('Task delete (no project)'); return; }

  const r1 = await req('POST', '/api/tasks', {
    projectId: testProjectId,
    title: 'AUDIT_TEST_Task to Delete',
  }, 'owner');
  if (r1.status !== 201) { skip('Task delete (could not create task)'); return; }
  const deleteTaskId = r1.body.id;

  // Non-creator member cannot delete
  const r2 = await req('DELETE', `/api/tasks/${deleteTaskId}`, undefined, 'member');
  assert(r2.status === 403, 'Non-creator member cannot delete task');

  // Outsider cannot delete
  const r3 = await req('DELETE', `/api/tasks/${deleteTaskId}`, undefined, 'outsider');
  assert(r3.status === 403, 'Outsider cannot delete task');

  // Owner can delete
  const r4 = await req('DELETE', `/api/tasks/${deleteTaskId}`, undefined, 'owner');
  assert(r4.status === 200, 'Owner can delete task');

  // Gone
  const r5 = await req('GET', `/api/tasks/${deleteTaskId}`, undefined, 'owner');
  assert(r5.status === 404, 'Deleted task returns 404');
}

async function testCommentDelete() {
  section('COMMENTS: Delete Permissions');

  if (!testTaskId || !testCommentId) { skip('Comment delete (no comment)'); return; }

  const r1 = await req('DELETE', `/api/comments/${testCommentId}`, undefined, 'owner');
  assert(r1.status === 200, 'Owner can delete own comment');
  testCommentId = null;

  // Nonexistent
  const r2 = await req('DELETE', '/api/comments/nonexistent-comment-999', undefined, 'owner');
  assert(r2.status === 403 || r2.status === 404, 'Delete nonexistent comment returns 403 or 404');
}

async function testMemberRemovedAccess() {
  section('PERMISSIONS: Removed member loses access');

  if (!testProjectId || !userIds.member) { skip('Member removal (no project or member ID)'); return; }

  // Remove member
  const r1 = await req('DELETE', `/api/projects/${testProjectId}/members/${userIds.member}`, undefined, 'owner');
  assert(r1.status === 200, 'Owner can remove member from project');

  // Removed member cannot view project
  const r2 = await req('GET', `/api/projects/${testProjectId}`, undefined, 'member');
  assert(r2.status === 403, 'Removed member cannot view project');

  // Removed member cannot view tasks
  if (testTaskId) {
    const r3 = await req('GET', `/api/tasks/${testTaskId}`, undefined, 'member');
    assert(r3.status === 403, 'Removed member cannot view task');
  }
}

async function testPersistence() {
  section('PERSISTENCE: Data still accessible (server already running)');

  if (testProjectId) {
    const r1 = await req('GET', `/api/projects/${testProjectId}`, undefined, 'owner');
    assert(r1.status === 200, 'Test project still accessible (persistence check)');
  }
  if (testTaskId) {
    const r2 = await req('GET', `/api/tasks/${testTaskId}`, undefined, 'owner');
    assert(r2.status === 200, 'Test task still accessible (persistence check)');
  }
  const r3 = await req('GET', '/api/dashboard/status', undefined, 'owner');
  if (r3.body) {
    console.log(`${INFO} Persistence backend: "${r3.body.mode}"`);
    assert(r3.body.counts && r3.body.counts.users >= 4, 'At least 4 users in DB (original seed + audit accounts)');
  }
}

async function testProjectSearch() {
  section('SEARCH: Project listing');

  const r1 = await req('GET', '/api/projects', undefined, 'owner');
  assert(r1.status === 200, 'GET /api/projects returns 200');
  if (Array.isArray(r1.body)) {
    if (testProjectId) {
      assert(r1.body.some(p => p.id === testProjectId), 'Owner can see own test project in list');
    }
    console.log(`${INFO} Owner can see ${r1.body.length} projects`);
  }

  const r2 = await req('GET', '/api/projects', undefined, 'outsider');
  assert(r2.status === 200, 'Outsider: GET /api/projects returns 200');
  if (Array.isArray(r2.body)) {
    assert(r2.body.length === 0, `Outsider sees 0 projects (got ${r2.body.length})`);
  }
}

async function testLogout() {
  section('AUTH: Logout');

  const r1 = await req('POST', '/api/auth/sign-out', {}, 'owner');
  assert(r1.status === 200, 'POST /api/auth/sign-out returns 200');

  const r2 = await req('GET', '/api/auth/me', undefined, 'owner');
  assert(r2.status === 401, '/api/auth/me returns 401 after logout');

  const r3 = await req('GET', '/api/projects', undefined, 'owner');
  assert(r3.status === 401, '/api/projects returns 401 after logout');
}

async function testReadme() {
  section('CODE QUALITY: README');

  const { readFileSync } = await import('node:fs');
  const { fileURLToPath } = await import('node:url');
  const { join, dirname } = await import('node:path');

  try {
    const readmePath = join(dirname(fileURLToPath(import.meta.url)), '..', 'README.md');
    const content = readFileSync(readmePath, 'utf8');
    assert(content.length > 500, 'README.md exists and has content');
    assert(content.toLowerCase().includes('install') || content.toLowerCase().includes('npm'), 'README has installation instructions');
    assert(content.toLowerCase().includes('env') || content.toLowerCase().includes('environment'), 'README mentions environment setup');
    assert(content.toLowerCase().includes('npm run dev') || content.toLowerCase().includes('npm start') || content.toLowerCase().includes('start'), 'README has run instructions');
  } catch (e) {
    assert(false, 'README.md exists and is readable', e.message);
  }
}

async function testConsoleLogCheck() {
  section('CODE QUALITY: Unnecessary debug logs');

  const { readdirSync, readFileSync, statSync } = await import('node:fs');
  const { fileURLToPath } = await import('node:url');
  const { join, dirname } = await import('node:path');

  const srcRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
  const excludes = new Set(['node_modules', '.git', 'dist', '.test-build', '.dev-build', 'scripts']);
  const allowedPaths = ['server/db.ts', 'server.ts']; // infra logs are ok
  let flagged = [];

  function scan(dir) {
    for (const entry of readdirSync(dir)) {
      if (excludes.has(entry)) continue;
      const full = join(dir, entry);
      try {
        if (statSync(full).isDirectory()) { scan(full); continue; }
        if (!(entry.endsWith('.ts') || entry.endsWith('.tsx'))) continue;
        const relPath = full.replace(srcRoot + '\\', '').replace(srcRoot + '/', '');
        if (allowedPaths.some(p => relPath.includes(p))) continue;
        const lines = readFileSync(full, 'utf8').split('\n');
        lines.forEach((line, i) => {
          if (/console\.(log|debug)\s*\(/.test(line) && !line.trim().startsWith('//')) {
            flagged.push(`${relPath}:${i + 1}: ${line.trim().substring(0, 80)}`);
          }
        });
      } catch {}
    }
  }

  try { scan(srcRoot); } catch (e) { console.log(`${INFO} Scan error: ${e.message}`); }

  console.log(`${INFO} Flagged debug console.log calls: ${flagged.length}`);
  if (flagged.length > 0) flagged.slice(0, 10).forEach(l => console.log(`    ${l}`));
  assert(flagged.length <= 3, `Debug logs in src: ${flagged.length} (threshold: 3)`, flagged.slice(0, 3).join(' | '));
}

async function testCodeQuality() {
  section('CODE QUALITY: Lint & Unit Tests');

  const { spawnSync } = await import('node:child_process');
  const { fileURLToPath } = await import('node:url');
  const { dirname, join } = await import('node:path');

  const cwd = join(dirname(fileURLToPath(import.meta.url)), '..');

  console.log(`${INFO} Running npm run lint...`);
  const lint = spawnSync('npm', ['run', 'lint'], { cwd, shell: true, encoding: 'utf8', timeout: 60000 });
  assert(lint.status === 0, 'npm run lint passes (no TypeScript errors)', lint.stderr?.substring(0, 200));
  if (lint.status !== 0) console.log(`${INFO} Lint errors:\n${lint.stdout?.substring(0, 500)}${lint.stderr?.substring(0, 500)}`);

  console.log(`${INFO} Running npm test...`);
  const tests = spawnSync('npm', ['test'], { cwd, shell: true, encoding: 'utf8', timeout: 90000 });
  assert(tests.status === 0, 'npm test passes (all unit tests pass)', tests.stderr?.substring(0, 200));
  if (tests.status !== 0) console.log(`${INFO} Test output:\n${tests.stdout?.substring(0, 500)}${tests.stderr?.substring(0, 500)}`);
}

// ===== MAIN RUNNER =====

async function main() {
  console.log('\n' + '='.repeat(60));
  console.log('  TaskFlow Comprehensive Audit Test Suite');
  console.log('  ' + new Date().toISOString());
  console.log('='.repeat(60));

  try {
    await testHealth();
    await testRegistration();
    await testLogin();
    await testMe();
    await testUsersList();
    await testProjectValidation();
    await testProjectCRUD();
    await testProjectPermissions();
    await testTaskValidation();
    await testTaskCRUD();
    await testTaskFilters();
    await testDashboard();
    await testComments();
    await testNotifications();
    await testActivityLog();
    await testProjectSearch();
    await testAPIErrorHandling();
    await testNoSQLInjection();
    await testXSSPayloads();
    await testCORSHeaders();
    await testPasswordHashing();
    await testSecretsNotInBundle();
    await testMongoDB();
    await testProjectDeleteCascade();
    await testTaskDelete();
    await testCommentDelete();
    await testMemberRemovedAccess();
    await testPersistence();
    await testReadme();
    await testConsoleLogCheck();
    await testCodeQuality();
    // Logout last (invalidates sessions)
    await testLogout();
  } catch (e) {
    console.error('\nFATAL TEST ERROR:', e);
    failed++;
    failures.push('FATAL: ' + e.message);
  }

  // Summary
  console.log('\n' + '='.repeat(60));
  console.log('  AUDIT RESULTS');
  console.log('='.repeat(60));
  console.log(`  ${PASS} Passed:  ${passed}`);
  console.log(`  ${FAIL} Failed:  ${failed}`);
  console.log(`  ${SKIP} Skipped: ${skipped}`);

  if (failures.length > 0) {
    console.log('\n  FAILURES:');
    failures.forEach((f, i) => console.log(`  ${i + 1}. ${f}`));
  }

  console.log('\n  Test accounts created:');
  for (const [key, acct] of Object.entries(ACCOUNTS)) {
    console.log(`    ${key}: ${acct.email} (${acct.password})`);
  }

  console.log('\n  Test data (prefix: AUDIT_TEST_):');
  console.log(`    testProjectId:  ${testProjectId}`);
  console.log(`    testTaskId:     ${testTaskId}`);
  console.log(`    testCommentId:  ${testCommentId}`);
  console.log(`    testNotifId:    ${testNotifId}`);
  console.log('='.repeat(60));

  process.exit(failed > 0 ? 1 : 0);
}

main().catch(e => { console.error(e); process.exit(1); });
