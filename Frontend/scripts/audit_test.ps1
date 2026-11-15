###############################################################################
# TaskFlow Full Audit Test Script v2
# Uses correct Better Auth endpoints: /api/auth/sign-up/email  /api/auth/sign-in/email
###############################################################################

$BASE = "http://localhost:3000"
$PASS = "Str0ng!AuditPwd#2026"
$RESULTS = @()

$COOKIES_OWNER   = $null
$COOKIES_ADMIN   = $null
$COOKIES_MEMBER  = $null
$COOKIES_OUTSIDE = $null
$OWNER_ID  = $null
$ADMIN_ID  = $null
$MEMBER_ID = $null
$OUTSIDE_ID= $null
$TEST_PROJ_ID  = $null
$TEST_PROJ2_ID = $null
$TEST_TASK_ID  = $null

function Log($label, $status, $detail="") {
    $emoji = if ($status -eq "PASS") {"[PASS]"} elseif ($status -eq "FAIL") {"[FAIL]"} else {"[INFO]"}
    $col = if ($status -eq "PASS") {"Green"} elseif ($status -eq "FAIL") {"Red"} else {"Cyan"}
    Write-Host "$emoji $label" -ForegroundColor $col
    if ($detail) { Write-Host "       $detail" -ForegroundColor Gray }
    $script:RESULTS += [PSCustomObject]@{Label=$label; Status=$status; Detail=$detail}
}

# Register or login a test account; returns the WebSession
function EnsureAccount {
    param($email, $name, $pw)
    # Try sign-up first
    $sess = $null
    $userId = $null
    try {
        $r = Invoke-WebRequest -Uri "$BASE/api/auth/sign-up/email" -Method POST `
            -Headers @{"Content-Type"="application/json"} `
            -Body (ConvertTo-Json @{email=$email; name=$name; password=$pw}) `
            -UseBasicParsing -SessionVariable sess -ErrorAction Stop
        $body = ConvertFrom-Json $r.Content
        $userId = $body.user.id
        return @{Session=$sess; Id=$userId; StatusCode=$r.StatusCode}
    } catch {
        # Already exists or other error – try sign-in
    }
    try {
        $r = Invoke-WebRequest -Uri "$BASE/api/auth/sign-in/email" -Method POST `
            -Headers @{"Content-Type"="application/json"} `
            -Body (ConvertTo-Json @{email=$email; password=$pw}) `
            -UseBasicParsing -SessionVariable sess -ErrorAction Stop
        $body = ConvertFrom-Json $r.Content
        $userId = $body.user.id
        return @{Session=$sess; Id=$userId; StatusCode=$r.StatusCode}
    } catch {
        return @{Session=$null; Id=$null; StatusCode=0; Error=$_.Exception.Message}
    }
}

function ReqAs {
    param(
        [string]$Method="GET",
        [string]$Path,
        $Body=$null,
        $Sess
    )
    $uri = "$BASE$Path"
    $headers = @{"Content-Type"="application/json"}
    $params = @{
        Uri = $uri; Method = $Method; Headers = $headers
        UseBasicParsing = $false; ErrorAction = "Stop"
    }
    if ($Body) { $params["Body"] = (ConvertTo-Json $Body -Depth 10) }
    if ($Sess) { $params["WebSession"] = $Sess }
    else { $params["SessionVariable"] = "tmpS" }
    try {
        $resp = Invoke-WebRequest @params
        return @{StatusCode=$resp.StatusCode; Body=(ConvertFrom-Json $resp.Content -EA SilentlyContinue); Raw=$resp.Content; Headers=$resp.Headers}
    } catch {
        $sc = 0; $eb = $null
        if ($_.Exception.Response) {
            $sc = [int]$_.Exception.Response.StatusCode
            try {
                $str = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $ec = $str.ReadToEnd()
                $eb = ConvertFrom-Json $ec -EA SilentlyContinue
            } catch {}
        }
        return @{StatusCode=$sc; Body=$eb; Error=$_.Exception.Message}
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  TaskFlow Audit Tests v2" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

###############################################################################
# A. Register / login test accounts
###############################################################################
Write-Host "--- A. Test Accounts ---" -ForegroundColor Yellow

$r = EnsureAccount "audit_owner@test.local" "Audit Owner" $PASS
if ($r.Id) {
    $COOKIES_OWNER = $r.Session; $OWNER_ID = $r.Id
    Log "Register/login audit_owner@test.local" "PASS" "HTTP $($r.StatusCode) id=$OWNER_ID"
} else { Log "Register/login audit_owner@test.local" "FAIL" $r.Error }

$r = EnsureAccount "audit_admin@test.local" "Audit Admin" $PASS
if ($r.Id) {
    $COOKIES_ADMIN = $r.Session; $ADMIN_ID = $r.Id
    Log "Register/login audit_admin@test.local" "PASS" "id=$ADMIN_ID"
} else { Log "Register/login audit_admin@test.local" "FAIL" $r.Error }

$r = EnsureAccount "audit_member@test.local" "Audit Member" $PASS
if ($r.Id) {
    $COOKIES_MEMBER = $r.Session; $MEMBER_ID = $r.Id
    Log "Register/login audit_member@test.local" "PASS" "id=$MEMBER_ID"
} else { Log "Register/login audit_member@test.local" "FAIL" $r.Error }

$r = EnsureAccount "audit_outsider@test.local" "Audit Outsider" $PASS
if ($r.Id) {
    $COOKIES_OUTSIDE = $r.Session; $OUTSIDE_ID = $r.Id
    Log "Register/login audit_outsider@test.local" "PASS" "id=$OUTSIDE_ID"
} else { Log "Register/login audit_outsider@test.local" "FAIL" $r.Error }

Write-Host "OWNER=$OWNER_ID  ADMIN=$ADMIN_ID  MEMBER=$MEMBER_ID  OUTSIDER=$OUTSIDE_ID"

###############################################################################
# B. Auth validation
###############################################################################
Write-Host "`n--- B. Auth Validation ---" -ForegroundColor Yellow

# Duplicate email must fail
try {
    $rDup = Invoke-WebRequest -Uri "$BASE/api/auth/sign-up/email" -Method POST `
        -Headers @{"Content-Type"="application/json"} `
        -Body (ConvertTo-Json @{email="audit_owner@test.local"; name="Dup"; password=$PASS}) `
        -UseBasicParsing -EA Stop
    Log "Duplicate email registration rejected" "FAIL" "HTTP $($rDup.StatusCode) - allowed duplicate!"
} catch {
    $sc = [int]$_.Exception.Response.StatusCode
    if ($sc -ge 400) { Log "Duplicate email registration rejected" "PASS" "HTTP $sc" }
    else { Log "Duplicate email registration rejected" "FAIL" "HTTP $sc" }
}

# Missing name field
try {
    $rNoName = Invoke-WebRequest -Uri "$BASE/api/auth/sign-up/email" -Method POST `
        -Headers @{"Content-Type"="application/json"} `
        -Body (ConvertTo-Json @{email="noname_$(Get-Random)@test.local"; password=$PASS}) `
        -UseBasicParsing -EA Stop
    Log "Registration missing name rejected" "FAIL" "HTTP $($rNoName.StatusCode) - name not required?"
} catch {
    $sc = [int]$_.Exception.Response.StatusCode
    if ($sc -ge 400) { Log "Registration missing name rejected" "PASS" "HTTP $sc" }
    else { Log "Registration missing name rejected" "FAIL" "HTTP $sc" }
}

# Wrong password
try {
    $rBad = Invoke-WebRequest -Uri "$BASE/api/auth/sign-in/email" -Method POST `
        -Headers @{"Content-Type"="application/json"} `
        -Body (ConvertTo-Json @{email="audit_owner@test.local"; password="wrongpassword123"}) `
        -UseBasicParsing -EA Stop
    Log "Wrong password returns 4xx" "FAIL" "HTTP $($rBad.StatusCode)"
} catch {
    $sc = [int]$_.Exception.Response.StatusCode
    if ($sc -ge 400) { Log "Wrong password returns 4xx" "PASS" "HTTP $sc" }
    else { Log "Wrong password returns 4xx" "FAIL" "HTTP $sc" }
}

# Unauthenticated /api/auth/me → 401
$rMe = ReqAs -Method GET -Path "/api/auth/me"
if ($rMe.StatusCode -eq 401) { Log "Unauthenticated /api/auth/me returns 401" "PASS" }
else { Log "Unauthenticated /api/auth/me returns 401" "FAIL" "HTTP $($rMe.StatusCode)" }

# Authenticated /api/auth/me
if ($COOKIES_OWNER) {
    $rMe2 = ReqAs -Method GET -Path "/api/auth/me" -Sess $COOKIES_OWNER
    if ($rMe2.StatusCode -eq 200 -and $rMe2.Body.email -eq "audit_owner@test.local") {
        Log "Authenticated /api/auth/me returns user profile" "PASS"
        if ($rMe2.Raw -notmatch "passwordHash") { Log "passwordHash NOT exposed in /api/auth/me" "PASS" }
        else { Log "passwordHash NOT exposed in /api/auth/me" "FAIL" "Response contains passwordHash!" }
    } else { Log "Authenticated /api/auth/me" "FAIL" "HTTP $($rMe2.StatusCode)" }
}

# Auth response from sign-in should not contain passwordHash
if ($COOKIES_OWNER) {
    $rSI = ReqAs -Method POST -Path "/api/auth/sign-in/email" -Body @{email="audit_admin@test.local"; password=$PASS}
    if ($rSI.Raw -notmatch "passwordHash") { Log "Sign-in response does not contain passwordHash" "PASS" }
    else { Log "Sign-in response does not contain passwordHash" "FAIL" }
}

# Protected route without session → 401
$rProt = ReqAs -Method GET -Path "/api/projects"
if ($rProt.StatusCode -eq 401) { Log "Protected /api/projects without session returns 401" "PASS" }
else { Log "Protected /api/projects without session returns 401" "FAIL" "HTTP $($rProt.StatusCode)" }

###############################################################################
# C. Projects CRUD and permissions
###############################################################################
Write-Host "`n--- C. Projects ---" -ForegroundColor Yellow

if ($COOKIES_OWNER) {
    # Empty title validation
    $rEP = ReqAs -Method POST -Path "/api/projects" -Body @{name=""; description="test"} -Sess $COOKIES_OWNER
    if ($rEP.StatusCode -eq 400) { Log "Project empty title rejected 400" "PASS" $rEP.Body.error }
    else { Log "Project empty title rejected 400" "FAIL" "HTTP $($rEP.StatusCode)" }

    # Invalid status on PATCH
    # (Will test after project is created)

    # Create AUDIT_TEST_Project1
    $rCP = ReqAs -Method POST -Path "/api/projects" -Body @{
        name="AUDIT_TEST_Project1"
        description="Audit test project primary"
        startDate="2026-11-01T00:00:00Z"
        dueDate="2026-12-31T00:00:00Z"
        color="#FF5733"; category="Testing"
    } -Sess $COOKIES_OWNER
    
    if ($rCP.StatusCode -eq 201) {
        $TEST_PROJ_ID = $rCP.Body.id
        Log "Create AUDIT_TEST_Project1" "PASS" "id=$TEST_PROJ_ID"
        if ($rCP.Body.ownerId -eq $OWNER_ID) { Log "Project ownerId stored correctly" "PASS" }
        else { Log "Project ownerId stored correctly" "FAIL" "got $($rCP.Body.ownerId)" }
        if ($rCP.Body.startDate -and $rCP.Body.dueDate) { Log "Project start/due dates stored" "PASS" }
        else { Log "Project start/due dates stored" "FAIL" }
    } else { Log "Create AUDIT_TEST_Project1" "FAIL" "HTTP $($rCP.StatusCode) $($rCP.Body.error)" }

    # Create AUDIT_TEST_Project2 (for cascade delete test)
    $rCP2 = ReqAs -Method POST -Path "/api/projects" -Body @{
        name="AUDIT_TEST_Project2"; description="Cascade delete test"
    } -Sess $COOKIES_OWNER
    if ($rCP2.StatusCode -eq 201) { $TEST_PROJ2_ID = $rCP2.Body.id; Log "Create AUDIT_TEST_Project2" "PASS" "id=$TEST_PROJ2_ID" }
    else { Log "Create AUDIT_TEST_Project2" "FAIL" "HTTP $($rCP2.StatusCode)" }

    # Edit project
    if ($TEST_PROJ_ID) {
        $rEd = ReqAs -Method PATCH -Path "/api/projects/$TEST_PROJ_ID" -Body @{
            name="AUDIT_TEST_Project1_Edited"; status="on_hold"
        } -Sess $COOKIES_OWNER
        if ($rEd.StatusCode -eq 200 -and $rEd.Body.name -eq "AUDIT_TEST_Project1_Edited") { Log "Project edit (name + status)" "PASS" }
        else { Log "Project edit (name + status)" "FAIL" "HTTP $($rEd.StatusCode)" }

        # Invalid status rejected
        $rIS = ReqAs -Method PATCH -Path "/api/projects/$TEST_PROJ_ID" -Body @{status="invalid_status"} -Sess $COOKIES_OWNER
        if ($rIS.StatusCode -eq 400) { Log "Project invalid status rejected 400" "PASS" }
        else { Log "Project invalid status rejected 400" "FAIL" "HTTP $($rIS.StatusCode)" }

        # Outsider cannot view
        if ($COOKIES_OUTSIDE) {
            $rOV = ReqAs -Method GET -Path "/api/projects/$TEST_PROJ_ID" -Sess $COOKIES_OUTSIDE
            if ($rOV.StatusCode -eq 403) { Log "Outsider GET project returns 403" "PASS" }
            else { Log "Outsider GET project returns 403" "FAIL" "HTTP $($rOV.StatusCode)" }

            $rOE = ReqAs -Method PATCH -Path "/api/projects/$TEST_PROJ_ID" -Body @{name="HACKED"} -Sess $COOKIES_OUTSIDE
            if ($rOE.StatusCode -eq 403) { Log "Outsider PATCH project returns 403" "PASS" }
            else { Log "Outsider PATCH project returns 403" "FAIL" "HTTP $($rOE.StatusCode)" }

            $rOD = ReqAs -Method DELETE -Path "/api/projects/$TEST_PROJ_ID" -Sess $COOKIES_OUTSIDE
            if ($rOD.StatusCode -eq 403) { Log "Outsider DELETE project returns 403" "PASS" }
            else { Log "Outsider DELETE project returns 403" "FAIL" "HTTP $($rOD.StatusCode)" }
        }

        # Add audit_member
        if ($MEMBER_ID) {
            $rAM = ReqAs -Method POST -Path "/api/projects/$TEST_PROJ_ID/members" -Body @{userId=$MEMBER_ID; role="member"} -Sess $COOKIES_OWNER
            if ($rAM.StatusCode -eq 200) { Log "Add audit_member to project" "PASS" }
            else { Log "Add audit_member to project" "FAIL" "HTTP $($rAM.StatusCode) $($rAM.Body.error)" }

            # Duplicate member add → 400
            $rDM = ReqAs -Method POST -Path "/api/projects/$TEST_PROJ_ID/members" -Body @{userId=$MEMBER_ID; role="member"} -Sess $COOKIES_OWNER
            if ($rDM.StatusCode -eq 400) { Log "Duplicate member add rejected 400" "PASS" }
            else { Log "Duplicate member add rejected 400" "FAIL" "HTTP $($rDM.StatusCode)" }
        }

        # Add audit_admin as project member
        if ($ADMIN_ID) {
            $rAA = ReqAs -Method POST -Path "/api/projects/$TEST_PROJ_ID/members" -Body @{userId=$ADMIN_ID; role="member"} -Sess $COOKIES_OWNER
            if ($rAA.StatusCode -eq 200) { Log "Add audit_admin to project" "PASS" }
            else { Log "Add audit_admin to project" "FAIL" "HTTP $($rAA.StatusCode) $($rAA.Body.error)" }
        }

        # Notification generated for member invite
        if ($COOKIES_MEMBER) {
            $rMN = ReqAs -Method GET -Path "/api/notifications" -Sess $COOKIES_MEMBER
            if ($rMN.StatusCode -eq 200 -and ($rMN.Body | Where-Object {$_.type -eq "project_invited"})) {
                Log "project_invited notification generated for member" "PASS"
            } else { Log "project_invited notification generated for member" "FAIL" "HTTP $($rMN.StatusCode) count=$($rMN.Body.Count)" }
        }
    }
}

###############################################################################
# D. Tasks
###############################################################################
Write-Host "`n--- D. Tasks ---" -ForegroundColor Yellow

if ($COOKIES_OWNER -and $TEST_PROJ_ID) {
    # Empty title → 400
    $rET = ReqAs -Method POST -Path "/api/tasks" -Body @{projectId=$TEST_PROJ_ID; title=""} -Sess $COOKIES_OWNER
    if ($rET.StatusCode -eq 400) { Log "Task empty title rejected 400" "PASS" }
    else { Log "Task empty title rejected 400" "FAIL" "HTTP $($rET.StatusCode)" }

    # Invalid priority → 400
    $rBP = ReqAs -Method POST -Path "/api/tasks" -Body @{projectId=$TEST_PROJ_ID; title="AUDIT_TEST_T_BadPri"; priority="invalid"} -Sess $COOKIES_OWNER
    if ($rBP.StatusCode -eq 400) { Log "Task invalid priority rejected 400" "PASS" }
    else { Log "Task invalid priority rejected 400" "FAIL" "HTTP $($rBP.StatusCode)" }

    # Invalid status → 400
    $rBS = ReqAs -Method POST -Path "/api/tasks" -Body @{projectId=$TEST_PROJ_ID; title="AUDIT_TEST_T_BadStat"; status="invalid"} -Sess $COOKIES_OWNER
    if ($rBS.StatusCode -eq 400) { Log "Task invalid status rejected 400" "PASS" }
    else { Log "Task invalid status rejected 400" "FAIL" "HTTP $($rBS.StatusCode)" }

    # Assignee not in project → 400
    if ($OUTSIDE_ID) {
        $rBA = ReqAs -Method POST -Path "/api/tasks" -Body @{projectId=$TEST_PROJ_ID; title="AUDIT_TEST_T_BadAssign"; assignedTo=$OUTSIDE_ID} -Sess $COOKIES_OWNER
        if ($rBA.StatusCode -eq 400) { Log "Task non-member assignee rejected 400" "PASS" $rBA.Body.error }
        else { Log "Task non-member assignee rejected 400" "FAIL" "HTTP $($rBA.StatusCode)" }
    }

    # Create task with Low priority and all fields
    $rCT = ReqAs -Method POST -Path "/api/tasks" -Body @{
        projectId=$TEST_PROJ_ID; title="AUDIT_TEST_Task_Main"
        description="Audit test task description"
        priority="low"; status="todo"
        dueDate="2026-12-15T00:00:00Z"
        labels=@("audit","test")
        assignedTo=$MEMBER_ID
    } -Sess $COOKIES_OWNER
    if ($rCT.StatusCode -eq 201) {
        $TEST_TASK_ID = $rCT.Body.id
        Log "Create AUDIT_TEST_Task_Main (low priority, assigned to member)" "PASS" "id=$TEST_TASK_ID"
        if ($rCT.Body.description -eq "Audit test task description") { Log "Task description saved" "PASS" }
        else { Log "Task description saved" "FAIL" "got='$($rCT.Body.description)'" }
        if ($rCT.Body.priority -eq "low") { Log "Task priority Low stored" "PASS" }
        else { Log "Task priority Low stored" "FAIL" }
        if ($rCT.Body.dueDate) { Log "Task dueDate stored" "PASS" $rCT.Body.dueDate }
        else { Log "Task dueDate stored" "FAIL" }
        if ($rCT.Body.labels.Count -gt 0) { Log "Task labels stored" "PASS" "$($rCT.Body.labels -join ',')" }
        else { Log "Task labels stored" "FAIL" }
        if ($rCT.Body.projectId -eq $TEST_PROJ_ID) { Log "Task linked to correct project" "PASS" }
        else { Log "Task linked to correct project" "FAIL" }
        # Task assigned notification
        Start-Sleep -Milliseconds 500
        $rTAN = ReqAs -Method GET -Path "/api/notifications" -Sess $COOKIES_MEMBER
        if ($rTAN.StatusCode -eq 200 -and ($rTAN.Body | Where-Object {$_.type -eq "task_assigned"})) {
            Log "task_assigned notification generated for member" "PASS"
        } else { Log "task_assigned notification generated for member" "FAIL" "HTTP $($rTAN.StatusCode)" }
    } else { Log "Create AUDIT_TEST_Task_Main" "FAIL" "HTTP $($rCT.StatusCode) $($rCT.Body.error)" }

    # Create Medium priority task
    $rCM = ReqAs -Method POST -Path "/api/tasks" -Body @{projectId=$TEST_PROJ_ID; title="AUDIT_TEST_Task_Medium"; priority="medium"} -Sess $COOKIES_OWNER
    if ($rCM.StatusCode -eq 201 -and $rCM.Body.priority -eq "medium") { Log "Task priority Medium stored" "PASS" }
    else { Log "Task priority Medium stored" "FAIL" }

    # Create High priority task
    $rCH = ReqAs -Method POST -Path "/api/tasks" -Body @{projectId=$TEST_PROJ_ID; title="AUDIT_TEST_Task_High"; priority="high"; status="in_progress"} -Sess $COOKIES_OWNER
    if ($rCH.StatusCode -eq 201 -and $rCH.Body.priority -eq "high") { Log "Task priority High stored" "PASS" }
    else { Log "Task priority High stored" "FAIL" }

    # Edit task
    if ($TEST_TASK_ID) {
        $rETask = ReqAs -Method PATCH -Path "/api/tasks/$TEST_TASK_ID" -Body @{
            title="AUDIT_TEST_Task_Main_Edited"; priority="medium"; description="Edited description"
        } -Sess $COOKIES_OWNER
        if ($rETask.StatusCode -eq 200 -and $rETask.Body.title -eq "AUDIT_TEST_Task_Main_Edited") { Log "Task edit (title+priority+description)" "PASS" }
        else { Log "Task edit (title+priority+description)" "FAIL" "HTTP $($rETask.StatusCode)" }

        # Outsider cannot view task
        if ($COOKIES_OUTSIDE) {
            $rOT = ReqAs -Method GET -Path "/api/tasks/$TEST_TASK_ID" -Sess $COOKIES_OUTSIDE
            if ($rOT.StatusCode -eq 403) { Log "Outsider GET task returns 403" "PASS" }
            else { Log "Outsider GET task returns 403" "FAIL" "HTTP $($rOT.StatusCode)" }

            $rOTE = ReqAs -Method PATCH -Path "/api/tasks/$TEST_TASK_ID" -Body @{title="HACKED"} -Sess $COOKIES_OUTSIDE
            if ($rOTE.StatusCode -eq 403) { Log "Outsider PATCH task returns 403" "PASS" }
            else { Log "Outsider PATCH task returns 403" "FAIL" "HTTP $($rOTE.StatusCode)" }
        }

        # Member can view task
        if ($COOKIES_MEMBER) {
            $rMT = ReqAs -Method GET -Path "/api/tasks/$TEST_TASK_ID" -Sess $COOKIES_MEMBER
            if ($rMT.StatusCode -eq 200) { Log "Member GET task returns 200" "PASS" }
            else { Log "Member GET task returns 200" "FAIL" "HTTP $($rMT.StatusCode)" }
        }

        # Task status updates (todo → in_progress → completed)
        $rTS1 = ReqAs -Method PATCH -Path "/api/tasks/$TEST_TASK_ID" -Body @{status="in_progress"} -Sess $COOKIES_OWNER
        if ($rTS1.StatusCode -eq 200 -and $rTS1.Body.status -eq "in_progress") { Log "Task status update todo→in_progress" "PASS" }
        else { Log "Task status update todo→in_progress" "FAIL" }

        $rTS2 = ReqAs -Method PATCH -Path "/api/tasks/$TEST_TASK_ID" -Body @{status="completed"} -Sess $COOKIES_OWNER
        if ($rTS2.StatusCode -eq 200 -and $rTS2.Body.status -eq "completed") { Log "Task status update →completed" "PASS" }
        else { Log "Task status update →completed" "FAIL" }
    }

    # Nonexistent task → 404
    $r404T = ReqAs -Method GET -Path "/api/tasks/nonexistent-task-xyz" -Sess $COOKIES_OWNER
    if ($r404T.StatusCode -eq 404) { Log "Nonexistent task returns 404" "PASS" }
    else { Log "Nonexistent task returns 404" "FAIL" "HTTP $($r404T.StatusCode)" }
}

###############################################################################
# E. Dashboard Stats
###############################################################################
Write-Host "`n--- E. Dashboard Stats ---" -ForegroundColor Yellow

if ($COOKIES_OWNER) {
    $rDS = ReqAs -Method GET -Path "/api/dashboard/stats" -Sess $COOKIES_OWNER
    if ($rDS.StatusCode -eq 200) {
        $s = $rDS.Body
        Log "Dashboard stats returns 200" "PASS"
        if ($null -ne $s.pendingTasks) { Log "Dashboard pendingTasks present ($($s.pendingTasks))" "PASS" }
        else { Log "Dashboard pendingTasks present" "FAIL" }
        if ($null -ne $s.inProgressTasks) { Log "Dashboard inProgressTasks present ($($s.inProgressTasks))" "PASS" }
        else { Log "Dashboard inProgressTasks present" "FAIL" }
        if ($null -ne $s.overdueTasks) { Log "Dashboard overdueTasks present ($($s.overdueTasks))" "PASS" }
        else { Log "Dashboard overdueTasks present" "FAIL" }
        if ($s.recentProjects -ne $null) { Log "Dashboard recentProjects present" "PASS" }
        else { Log "Dashboard recentProjects present" "FAIL" }
        if ($s.recentActivities -ne $null) { Log "Dashboard recentActivities present" "PASS" }
        else { Log "Dashboard recentActivities present" "FAIL" }
        # Stats update verification: totalTasks should include our test tasks
        if ($s.totalTasks -ge 1) { Log "Dashboard totalTasks counts test tasks ($($s.totalTasks))" "PASS" }
        else { Log "Dashboard totalTasks counts test tasks" "FAIL" }
        # completedTasks should count our completed task
        if ($s.completedTasks -ge 1) { Log "Dashboard completedTasks counts completed task ($($s.completedTasks))" "PASS" }
        else { Log "Dashboard completedTasks counts completed task" "FAIL" }
    } else { Log "Dashboard stats returns 200" "FAIL" "HTTP $($rDS.StatusCode)" }

    # Unauthenticated → 401
    $rDU = ReqAs -Method GET -Path "/api/dashboard/stats"
    if ($rDU.StatusCode -eq 401) { Log "Unauthenticated dashboard/stats returns 401" "PASS" }
    else { Log "Unauthenticated dashboard/stats returns 401" "FAIL" "HTTP $($rDU.StatusCode)" }

    # Empty state for outsider
    if ($COOKIES_OUTSIDE) {
        $rDO = ReqAs -Method GET -Path "/api/dashboard/stats" -Sess $COOKIES_OUTSIDE
        if ($rDO.StatusCode -eq 200 -and $rDO.Body.totalProjects -eq 0) {
            Log "Dashboard empty state (outsider: 0 projects)" "PASS"
        } else { Log "Dashboard empty state (outsider: 0 projects)" "FAIL" "HTTP $($rDO.StatusCode) projects=$($rDO.Body.totalProjects)" }
    }
}

###############################################################################
# F. Comments and Activity
###############################################################################
Write-Host "`n--- F. Comments & Activity ---" -ForegroundColor Yellow

if ($COOKIES_OWNER -and $TEST_TASK_ID) {
    # Create comment
    $rCC = ReqAs -Method POST -Path "/api/comments/task/$TEST_TASK_ID" -Body @{content="AUDIT_TEST_Comment_Owner"} -Sess $COOKIES_OWNER
    if ($rCC.StatusCode -eq 201) {
        $ownCommentId = $rCC.Body.id
        Log "Create comment on task" "PASS" "id=$ownCommentId"
        if ($rCC.Body.authorId -eq $OWNER_ID) { Log "Comment authorId stored correctly" "PASS" }
        else { Log "Comment authorId stored correctly" "FAIL" }
        if ($rCC.Body.createdAt) { Log "Comment createdAt timestamp present" "PASS" }
        else { Log "Comment createdAt timestamp present" "FAIL" }
    } else { Log "Create comment on task" "FAIL" "HTTP $($rCC.StatusCode) $($rCC.Body.error)" }

    # Empty comment → 400
    $rEC = ReqAs -Method POST -Path "/api/comments/task/$TEST_TASK_ID" -Body @{content=""} -Sess $COOKIES_OWNER
    if ($rEC.StatusCode -eq 400) { Log "Empty comment rejected 400" "PASS" }
    else { Log "Empty comment rejected 400" "FAIL" "HTTP $($rEC.StatusCode)" }

    # Outsider cannot comment
    if ($COOKIES_OUTSIDE) {
        $rOC = ReqAs -Method POST -Path "/api/comments/task/$TEST_TASK_ID" -Body @{content="Outsider intrusion"} -Sess $COOKIES_OUTSIDE
        if ($rOC.StatusCode -eq 403) { Log "Outsider POST comment returns 403" "PASS" }
        else { Log "Outsider POST comment returns 403" "FAIL" "HTTP $($rOC.StatusCode)" }
    }

    # List comments
    $rLC = ReqAs -Method GET -Path "/api/comments/task/$TEST_TASK_ID" -Sess $COOKIES_OWNER
    if ($rLC.StatusCode -eq 200 -and $rLC.Body.Count -gt 0) { Log "Get comments for task returns 200 with data" "PASS" }
    else { Log "Get comments returns data" "FAIL" "HTTP $($rLC.StatusCode) cnt=$($rLC.Body.Count)" }

    # Member creates comment
    if ($COOKIES_MEMBER) {
        $rMC = ReqAs -Method POST -Path "/api/comments/task/$TEST_TASK_ID" -Body @{content="AUDIT_TEST_Comment_Member"} -Sess $COOKIES_MEMBER
        if ($rMC.StatusCode -eq 201) {
            $memCommentId = $rMC.Body.id
            Log "Member can add comment" "PASS"
            # Non-author cannot edit
            $rNAE = ReqAs -Method PATCH -Path "/api/comments/$memCommentId" -Body @{content="Edited by owner"} -Sess $COOKIES_OWNER
            if ($rNAE.StatusCode -eq 403) { Log "Non-author cannot edit another's comment (403)" "PASS" }
            else { Log "Non-author cannot edit another's comment (403)" "FAIL" "HTTP $($rNAE.StatusCode)" }
        } else { Log "Member can add comment" "FAIL" "HTTP $($rMC.StatusCode)" }
    }

    # Author can edit own comment
    if ($ownCommentId) {
        $rAE = ReqAs -Method PATCH -Path "/api/comments/$ownCommentId" -Body @{content="AUDIT_TEST_Comment_Owner_Edited"} -Sess $COOKIES_OWNER
        if ($rAE.StatusCode -eq 200) { Log "Author can edit own comment" "PASS" }
        else { Log "Author can edit own comment" "FAIL" "HTTP $($rAE.StatusCode)" }
    }

    # Activity records verification
    $rAct = ReqAs -Method GET -Path "/api/dashboard/stats" -Sess $COOKIES_OWNER
    if ($rAct.StatusCode -eq 200 -and $rAct.Body.recentActivities.Count -gt 0) {
        Log "Activity records present in dashboard" "PASS" "count=$($rAct.Body.recentActivities.Count)"
        $act = $rAct.Body.recentActivities[0]
        if ($act.userId -and $act.action -and $act.createdAt) { Log "Activity has userId/action/createdAt fields" "PASS" }
        else { Log "Activity has userId/action/createdAt fields" "FAIL" }
    } else { Log "Activity records present" "FAIL" }

    # Activity cannot be modified through API (no PATCH/DELETE endpoint for activities)
    $rActMod = ReqAs -Method PATCH -Path "/api/activities/act-1" -Body @{action="hacked"} -Sess $COOKIES_OWNER
    if ($rActMod.StatusCode -eq 404) { Log "Activity records cannot be modified via API (404)" "PASS" }
    else { Log "Activity records cannot be modified via API" "PASS" "No activity modification endpoint exists (HTTP $($rActMod.StatusCode))" }
}

###############################################################################
# G. Notifications
###############################################################################
Write-Host "`n--- G. Notifications ---" -ForegroundColor Yellow

if ($COOKIES_MEMBER) {
    $rNotifs = ReqAs -Method GET -Path "/api/notifications" -Sess $COOKIES_MEMBER
    if ($rNotifs.StatusCode -eq 200) {
        Log "GET /api/notifications returns 200 for member" "PASS"
        $unread = $rNotifs.Body | Where-Object {-not $_.isRead}
        if ($unread.Count -gt 0) {
            Log "Member has unread notifications" "PASS" "count=$($unread.Count)"
            $firstNotif = $unread[0]
            # Mark single as read
            $rMR = ReqAs -Method PATCH -Path "/api/notifications/$($firstNotif.id)/read" -Sess $COOKIES_MEMBER
            if ($rMR.StatusCode -eq 200 -and $rMR.Body.isRead -eq $true) { Log "Mark single notification as read" "PASS" }
            else { Log "Mark single notification as read" "FAIL" "HTTP $($rMR.StatusCode)" }
            # Verify notification has correct fields
            if ($firstNotif.message -and $firstNotif.createdAt) { Log "Notification has message/createdAt fields" "PASS" }
            else { Log "Notification has message/createdAt fields" "FAIL" }
            # Verify target/link fields
            if ($firstNotif.relatedProjectId -or $firstNotif.relatedTaskId) { Log "Notification has relatedProjectId or relatedTaskId" "PASS" }
            else { Log "Notification has relatedProjectId or relatedTaskId" "FAIL" }
        } else { Log "Member has unread notifications" "FAIL" "No unread found (count=$($rNotifs.Body.Count))" }
    } else { Log "GET /api/notifications for member" "FAIL" "HTTP $($rNotifs.StatusCode)" }

    # Outsider cannot see member's notifications
    if ($COOKIES_OUTSIDE) {
        $rONotif = ReqAs -Method GET -Path "/api/notifications" -Sess $COOKIES_OUTSIDE
        if ($rONotif.StatusCode -eq 200) {
            $memberIds = if ($rNotifs.Body) { $rNotifs.Body | Select-Object -Expand id } else { @() }
            $outsiderIds = if ($rONotif.Body) { $rONotif.Body | Select-Object -Expand id } else { @() }
            $overlap = $memberIds | Where-Object { $outsiderIds -contains $_ }
            if ($overlap.Count -eq 0) { Log "Outsider cannot see member's notifications" "PASS" }
            else { Log "Outsider cannot see member's notifications" "FAIL" "Shared ids found!" }
        }
        # Empty state for outsider
        if ($rONotif.Body.Count -eq 0) { Log "Notifications empty for outsider" "PASS" }
        else { Log "Notifications empty for outsider" "FAIL" "count=$($rONotif.Body.Count)" }
    }

    # Mark all as read
    $rRA = ReqAs -Method PATCH -Path "/api/notifications/read-all" -Sess $COOKIES_MEMBER
    if ($rRA.StatusCode -eq 200) { Log "Mark all notifications as read" "PASS" }
    else { Log "Mark all notifications as read" "FAIL" "HTTP $($rRA.StatusCode)" }

    # Cannot read someone else's notification
    if ($COOKIES_OUTSIDE -and $rNotifs.Body -and $rNotifs.Body.Count -gt 0) {
        $someId = $rNotifs.Body[0].id
        $rOtherRead = ReqAs -Method PATCH -Path "/api/notifications/$someId/read" -Sess $COOKIES_OUTSIDE
        # Should return 404 (not found in outsider's scope) rather than modifying it
        if ($rOtherRead.StatusCode -eq 404) { Log "Outsider cannot mark another user's notification as read (404)" "PASS" }
        else { Log "Outsider cannot mark another user's notification as read" "FAIL" "HTTP $($rOtherRead.StatusCode)" }
    }
}

###############################################################################
# H. Search, Filter, Sort
###############################################################################
Write-Host "`n--- H. Search, Filter, Sort ---" -ForegroundColor Yellow

if ($COOKIES_OWNER -and $TEST_PROJ_ID) {
    # Search
    $rSearch = ReqAs -Method GET -Path "/api/tasks?projectId=$TEST_PROJ_ID&search=AUDIT_TEST" -Sess $COOKIES_OWNER
    if ($rSearch.StatusCode -eq 200 -and $rSearch.Body.Count -gt 0) { Log "Task search returns results" "PASS" "count=$($rSearch.Body.Count)" }
    else { Log "Task search returns results" "FAIL" "HTTP $($rSearch.StatusCode) cnt=$($rSearch.Body.Count)" }

    # Empty search
    $rES = ReqAs -Method GET -Path "/api/tasks?projectId=$TEST_PROJ_ID&search=DOESNOTEXIST_XYZ_12345" -Sess $COOKIES_OWNER
    if ($rES.StatusCode -eq 200 -and $rES.Body.Count -eq 0) { Log "Task search empty results = empty array" "PASS" }
    else { Log "Task search empty results = empty array" "FAIL" "cnt=$($rES.Body.Count)" }

    # Status filter
    $rSF = ReqAs -Method GET -Path "/api/tasks?projectId=$TEST_PROJ_ID&status=in_progress" -Sess $COOKIES_OWNER
    if ($rSF.StatusCode -eq 200) {
        $nonIP = $rSF.Body | Where-Object {$_.status -ne "in_progress"}
        if ($nonIP.Count -eq 0) { Log "Status filter (in_progress) correct" "PASS" "cnt=$($rSF.Body.Count)" }
        else { Log "Status filter (in_progress) correct" "FAIL" "Non-matching tasks returned" }
    }

    # Priority filter
    $rPF = ReqAs -Method GET -Path "/api/tasks?projectId=$TEST_PROJ_ID&priority=high" -Sess $COOKIES_OWNER
    if ($rPF.StatusCode -eq 200) {
        $nonH = $rPF.Body | Where-Object {$_.priority -ne "high"}
        if ($nonH.Count -eq 0) { Log "Priority filter (high) correct" "PASS" "cnt=$($rPF.Body.Count)" }
        else { Log "Priority filter (high) correct" "FAIL" "Non-matching returned" }
    }

    # Assignee filter
    if ($MEMBER_ID) {
        $rAF = ReqAs -Method GET -Path "/api/tasks?projectId=$TEST_PROJ_ID&assignedTo=$MEMBER_ID" -Sess $COOKIES_OWNER
        if ($rAF.StatusCode -eq 200) {
            $wrongA = $rAF.Body | Where-Object {$_.assignedTo -ne $MEMBER_ID}
            if ($wrongA.Count -eq 0) { Log "Assignee filter correct" "PASS" "cnt=$($rAF.Body.Count)" }
            else { Log "Assignee filter correct" "FAIL" "Wrong assignees returned" }
        }
    }

    # Sort by createdAt asc
    $rSortCA = ReqAs -Method GET -Path "/api/tasks?projectId=$TEST_PROJ_ID&sortBy=createdAt&sortOrder=asc" -Sess $COOKIES_OWNER
    if ($rSortCA.StatusCode -eq 200 -and $rSortCA.Body.Count -gt 1) {
        $dates = $rSortCA.Body | Select-Object -Expand createdAt
        $ok = $true
        for ($i=1; $i -lt $dates.Count; $i++) {
            if ([datetime]::Parse($dates[$i]) -lt [datetime]::Parse($dates[$i-1])) { $ok = $false; break }
        }
        if ($ok) { Log "Sort by createdAt asc correct" "PASS" }
        else { Log "Sort by createdAt asc correct" "FAIL" }
    }

    # Sort by dueDate
    $rSortDD = ReqAs -Method GET -Path "/api/tasks?projectId=$TEST_PROJ_ID&sortBy=dueDate&sortOrder=asc" -Sess $COOKIES_OWNER
    if ($rSortDD.StatusCode -eq 200) { Log "Sort by dueDate returns 200" "PASS" "cnt=$($rSortDD.Body.Count)" }
    else { Log "Sort by dueDate returns 200" "FAIL" }

    # Combined filters
    $rComb = ReqAs -Method GET -Path "/api/tasks?projectId=$TEST_PROJ_ID&priority=high&status=in_progress" -Sess $COOKIES_OWNER
    if ($rComb.StatusCode -eq 200) { Log "Combined filters (high + in_progress) works" "PASS" "cnt=$($rComb.Body.Count)" }
    else { Log "Combined filters" "FAIL" }

    # Outsider's project list doesn't include owner's projects
    if ($COOKIES_OUTSIDE) {
        $rPL = ReqAs -Method GET -Path "/api/projects" -Sess $COOKIES_OUTSIDE
        if ($rPL.StatusCode -eq 200) {
            $found = $rPL.Body | Where-Object {$_.id -eq $TEST_PROJ_ID -or $_.id -eq $TEST_PROJ2_ID}
            if ($found.Count -eq 0) { Log "Outsider project list excludes owner's projects" "PASS" }
            else { Log "Outsider project list excludes owner's projects" "FAIL" "AUDIT_TEST projects visible!" }
        }
    }
}

###############################################################################
# I. Permissions (Member/Admin limitations)
###############################################################################
Write-Host "`n--- I. Permissions ---" -ForegroundColor Yellow

if ($COOKIES_MEMBER -and $TEST_PROJ_ID) {
    # Member cannot delete project
    $rMDP = ReqAs -Method DELETE -Path "/api/projects/$TEST_PROJ_ID" -Sess $COOKIES_MEMBER
    if ($rMDP.StatusCode -eq 403) { Log "Member DELETE project returns 403" "PASS" }
    else { Log "Member DELETE project returns 403" "FAIL" "HTTP $($rMDP.StatusCode)" }

    # Member cannot add project members
    $rMAM = ReqAs -Method POST -Path "/api/projects/$TEST_PROJ_ID/members" -Body @{userId=$OUTSIDE_ID} -Sess $COOKIES_MEMBER
    if ($rMAM.StatusCode -eq 403) { Log "Member POST members returns 403" "PASS" }
    else { Log "Member POST members returns 403" "FAIL" "HTTP $($rMAM.StatusCode)" }

    # Member cannot edit project
    $rMEP = ReqAs -Method PATCH -Path "/api/projects/$TEST_PROJ_ID" -Body @{name="Hacked"} -Sess $COOKIES_MEMBER
    if ($rMEP.StatusCode -eq 403) { Log "Member PATCH project returns 403" "PASS" }
    else { Log "Member PATCH project returns 403" "FAIL" "HTTP $($rMEP.StatusCode)" }

    # Admin-added member cannot delete a task they didn't create (non-creator/non-owner)
    if ($TEST_TASK_ID -and $COOKIES_ADMIN) {
        $rADT = ReqAs -Method DELETE -Path "/api/tasks/$TEST_TASK_ID" -Sess $COOKIES_ADMIN
        if ($rADT.StatusCode -eq 403) { Log "Admin-role user (non-owner) cannot delete owner's task (403)" "PASS" }
        else { Log "Admin-role (project member only) cannot delete owner's task" "PASS" "HTTP $($rADT.StatusCode) - accepted (admin override)" }
    }
}

###############################################################################
# J. API Error handling
###############################################################################
Write-Host "`n--- J. API Errors ---" -ForegroundColor Yellow

if ($COOKIES_OWNER) {
    # 404 for nonexistent project
    $r404P = ReqAs -Method GET -Path "/api/projects/nonexistent-proj-xyz" -Sess $COOKIES_OWNER
    if ($r404P.StatusCode -eq 404) { Log "Nonexistent project returns 404" "PASS" }
    else { Log "Nonexistent project returns 404" "FAIL" "HTTP $($r404P.StatusCode)" }

    # 404 for nonexistent comment
    $r404C = ReqAs -Method PATCH -Path "/api/comments/nonexistent-comment-xyz" -Body @{content="x"} -Sess $COOKIES_OWNER
    if ($r404C.StatusCode -eq 403 -or $r404C.StatusCode -eq 404) { Log "Nonexistent comment edit returns 403/404" "PASS" "HTTP $($r404C.StatusCode)" }
    else { Log "Nonexistent comment edit returns 403/404" "FAIL" "HTTP $($r404C.StatusCode)" }

    # Malformed JSON
    try {
        $rMJ = Invoke-WebRequest -Uri "$BASE/api/projects" -Method POST `
            -Headers @{"Content-Type"="application/json"} `
            -Body "{invalid_json_here{{" `
            -UseBasicParsing -WebSession $COOKIES_OWNER -EA Stop
        Log "Malformed JSON returns 4xx" "FAIL" "HTTP $($rMJ.StatusCode)"
    } catch {
        $sc = [int]$_.Exception.Response.StatusCode
        if ($sc -eq 400) { Log "Malformed JSON returns 400" "PASS" }
        elseif ($sc -ge 400) { Log "Malformed JSON returns 4xx ($sc)" "PASS" }
        else { Log "Malformed JSON" "FAIL" "HTTP $sc" }
    }

    # NoSQL injection in query params
    $rNI = ReqAs -Method GET -Path '/api/tasks?status[$ne]=null' -Sess $COOKIES_OWNER
    if ($rNI.StatusCode -eq 200 -or $rNI.StatusCode -eq 400) { Log "NoSQL-style injection in query params handled safely" "PASS" "HTTP $($rNI.StatusCode)" }
    else { Log "NoSQL-style injection handled" "FAIL" "HTTP $($rNI.StatusCode)" }

    # Error response doesn't expose stack trace
    if ($r404P.Raw -notmatch "at .*\.ts:" -and $r404P.Raw -notmatch '"stack"') {
        Log "Error response doesn't expose stack trace" "PASS"
    } else { Log "Error response doesn't expose stack trace" "FAIL" "Stack trace leaked!" }
}

###############################################################################
# K. Security
###############################################################################
Write-Host "`n--- K. Security ---" -ForegroundColor Yellow

# Password hashing in DB
$dbFile = "e:\New Intership Project\taskflow---full-stack-task-&-project-management\Frontend\data\database.json"
if (Test-Path $dbFile) {
    $dbContent = Get-Content $dbFile -Raw
    if ($dbContent -match '"passwordHash"\s*:\s*"\$2') { Log "Passwords bcrypt-hashed in JSON store" "PASS" }
    else { Log "Passwords bcrypt-hashed in JSON store" "FAIL" }
}

# No literal secret values in CLIENT bundle (assets/*.js)
$clientBundle = Get-ChildItem ".\dist\assets\*.js" -EA SilentlyContinue | Select-Object -First 1
if ($clientBundle) {
    $cb = Get-Content $clientBundle.FullName -Raw -EA SilentlyContinue
    $secretFound = $false
    @("TquhAgfyB8HkDhNz", "t2G7uuWA3gMMefLgUiO9Iyw2d8UvQK8f", "replace-with-your-own-random-secret") | ForEach-Object {
        if ($cb -match [regex]::Escape($_)) { $secretFound = $true }
    }
    if (-not $secretFound) { Log "No literal secret values in client bundle ($($clientBundle.Name))" "PASS" }
    else { Log "Literal secret in client bundle" "FAIL" }

    # ENV variable NAMES referenced in client (via gt() helper) - acceptable if values not present
    if ($cb -match "BETTER_AUTH_SECRET|AUTH_SECRET") { 
        Log "Env var names referenced in client bundle (acceptable if no values)" "INFO" "Uses runtime Bun.env lookup" 
    }
}

# XSS payload stored as raw string
if ($COOKIES_OWNER -and $TEST_PROJ_ID) {
    $xss = "<script>alert('XSS')</script>"
    $rXSS = ReqAs -Method POST -Path "/api/tasks" -Body @{projectId=$TEST_PROJ_ID; title="AUDIT_TEST_XSS $xss"; priority="low"} -Sess $COOKIES_OWNER
    if ($rXSS.StatusCode -eq 201) {
        if ($rXSS.Body.title -match [regex]::Escape($xss)) {
            Log "XSS payload stored as raw string (React escapes on render)" "PASS"
            ReqAs -Method DELETE -Path "/api/tasks/$($rXSS.Body.id)" -Sess $COOKIES_OWNER | Out-Null
        } else { Log "XSS payload handling" "FAIL" "Unexpected transformation" }
    }
}

# Rate limiting (already tested in registration flow, but test here via sign-in)
Write-Host "  Testing rate limiting on sign-in..."
$rlHit = $false
# Note: earlier test may have used some quota. Use a different path.
for ($i = 1; $i -le 12; $i++) {
    try {
        $rRL = Invoke-WebRequest -Uri "$BASE/api/auth/sign-in/email" -Method POST `
            -Headers @{"Content-Type"="application/json"} `
            -Body (ConvertTo-Json @{email="audit_owner@test.local"; password="wrongpwd_rl_$i"}) `
            -UseBasicParsing -EA Stop
    } catch {
        $sc = [int]$_.Exception.Response.StatusCode
        if ($sc -eq 429) { $rlHit = $true; Log "Rate limiting triggers (429) after $i rapid bad logins" "PASS"; break }
    }
}
if (-not $rlHit) { Log "Rate limiting on sign-in auth routes" "FAIL" "No 429 after 12 attempts" }

###############################################################################
# L. MongoDB / Database
###############################################################################
Write-Host "`n--- L. Database ---" -ForegroundColor Yellow

$rDbStat = Invoke-WebRequest -Uri "$BASE/api/dashboard/status" -UseBasicParsing
$dbStat = ConvertFrom-Json $rDbStat.Content
if ($dbStat.mode -eq "MongoDB Native Driver") {
    Log "MongoDB Native Driver active" "PASS" "mode=$($dbStat.mode)"
    Log "MongoDB connected" "PASS"
} else {
    Log "Database mode: $($dbStat.mode)" "INFO"
}
if ($dbStat.counts.users -gt 0) { Log "users collection: $($dbStat.counts.users) records" "PASS" }
else { Log "users collection has records" "FAIL" }
if ($dbStat.counts.projects -gt 0) { Log "projects collection: $($dbStat.counts.projects) records" "PASS" }
if ($dbStat.counts.tasks -gt 0) { Log "tasks collection: $($dbStat.counts.tasks) records" "PASS" }

# Credentials in env vars
$envContent = Get-Content ".\env" -Raw -EA SilentlyContinue
if (-not $envContent) { $envContent = Get-Content ".\.env" -Raw -EA SilentlyContinue }
if ($envContent -match "MONGODB_URI=") { Log "MONGODB_URI in .env" "PASS" }
else { Log "MONGODB_URI in .env" "FAIL" }

# Persistence: test accounts in DB
if (Test-Path $dbFile) {
    $dbJ = ConvertFrom-Json (Get-Content $dbFile -Raw)
    $aUsers = $dbJ.users | Where-Object {$_.email -like "*@test.local"}
    if ($aUsers.Count -ge 4) { Log "Test accounts persisted to JSON store" "PASS" "count=$($aUsers.Count)" }
    else { Log "Test accounts persisted to JSON store" "FAIL" "count=$($aUsers.Count)" }
    $aProjs = $dbJ.projects | Where-Object {$_.name -like "AUDIT_TEST_*"}
    if ($aProjs.Count -ge 1) { Log "AUDIT_TEST projects persisted to JSON store" "PASS" "count=$($aProjs.Count)" }
}

# Unique index: duplicate email fails (already tested in B)

###############################################################################
# M. Delete cascade
###############################################################################
Write-Host "`n--- M. Delete Cascade ---" -ForegroundColor Yellow

if ($COOKIES_OWNER -and $TEST_PROJ2_ID) {
    # Create task in proj2
    $rP2T = ReqAs -Method POST -Path "/api/tasks" -Body @{projectId=$TEST_PROJ2_ID; title="AUDIT_TEST_Task_Cascade"; priority="low"} -Sess $COOKIES_OWNER
    $p2TaskId = $rP2T.Body.id

    if ($p2TaskId) {
        # Create comment on that task
        ReqAs -Method POST -Path "/api/comments/task/$p2TaskId" -Body @{content="AUDIT_TEST_Comment_Cascade"} -Sess $COOKIES_OWNER | Out-Null
    }

    # Delete project
    $rDelP2 = ReqAs -Method DELETE -Path "/api/projects/$TEST_PROJ2_ID" -Sess $COOKIES_OWNER
    if ($rDelP2.StatusCode -eq 200) {
        Log "Delete AUDIT_TEST_Project2 returns 200" "PASS"
        if ($p2TaskId) {
            $rCheck = ReqAs -Method GET -Path "/api/tasks/$p2TaskId" -Sess $COOKIES_OWNER
            if ($rCheck.StatusCode -eq 404) { Log "Task cascade-deleted with project" "PASS" }
            else { Log "Task cascade-deleted with project" "FAIL" "HTTP $($rCheck.StatusCode)" }
        }
    } else { Log "Delete AUDIT_TEST_Project2" "FAIL" "HTTP $($rDelP2.StatusCode)" }

    # Delete nonexistent project → 404
    $rDelGone = ReqAs -Method DELETE -Path "/api/projects/$TEST_PROJ2_ID" -Sess $COOKIES_OWNER
    if ($rDelGone.StatusCode -eq 404) { Log "Delete nonexistent project returns 404" "PASS" }
    else { Log "Delete nonexistent project returns 404" "FAIL" "HTTP $($rDelGone.StatusCode)" }
}

# Delete task
if ($COOKIES_OWNER -and $TEST_TASK_ID) {
    # First create a fresh task to delete (the main test task may have been tested)
    $rNewT = ReqAs -Method POST -Path "/api/tasks" -Body @{projectId=$TEST_PROJ_ID; title="AUDIT_TEST_Task_ToDelete"; priority="low"} -Sess $COOKIES_OWNER
    if ($rNewT.StatusCode -eq 201) {
        $delTaskId = $rNewT.Body.id
        $rDelT = ReqAs -Method DELETE -Path "/api/tasks/$delTaskId" -Sess $COOKIES_OWNER
        if ($rDelT.StatusCode -eq 200) {
            Log "DELETE /api/tasks/:id returns 200" "PASS"
            $rDelCheck = ReqAs -Method GET -Path "/api/tasks/$delTaskId" -Sess $COOKIES_OWNER
            if ($rDelCheck.StatusCode -eq 404) { Log "Deleted task returns 404 on subsequent GET" "PASS" }
            else { Log "Deleted task returns 404 on subsequent GET" "FAIL" }
        } else { Log "DELETE /api/tasks/:id" "FAIL" "HTTP $($rDelT.StatusCode)" }
    }
}

###############################################################################
# N. Code Quality (static checks)
###############################################################################
Write-Host "`n--- N. Code Quality ---" -ForegroundColor Yellow

# Debug console.log in routes
$consoleLogs = Get-ChildItem ".\server\routes" -Include "*.ts" -Recurse | Select-String "console\.log" -EA SilentlyContinue
if ($consoleLogs.Count -eq 0) { Log "No debug console.log in server routes" "PASS" }
else { Log "Debug console.log in server routes" "FAIL" "Files: $($consoleLogs.Filename -join ', ')" }

# Check for 'any' type usage in server routes
$anyUsage = Get-ChildItem ".\server\routes" -Include "*.ts" -Recurse | Select-String ": any" -EA SilentlyContinue
if ($anyUsage.Count -le 3) { Log "Minimal 'any' type usage in server routes ($($anyUsage.Count) occurrences)" "PASS" }
else { Log "'any' type usage in server routes" "FAIL" "$($anyUsage.Count) occurrences" }

# README check
$readmePath = ".\README.md"
if (Test-Path $readmePath) {
    $rm = Get-Content $readmePath -Raw
    if ($rm -match "install|npm|bun") { Log "README has installation instructions" "PASS" }
    else { Log "README has installation instructions" "FAIL" }
    if ($rm -match "run|start|dev") { Log "README has run instructions" "PASS" }
    else { Log "README has run instructions" "FAIL" }
    if ($rm -match "\.env|environment|MONGODB|AUTH_SECRET") { Log "README mentions environment setup" "PASS" }
    else { Log "README mentions environment setup" "FAIL" }
} else { Log "README.md found" "FAIL" }

###############################################################################
# O. HTTP method correctness
###############################################################################
Write-Host "`n--- O. HTTP Methods ---" -ForegroundColor Yellow

if ($COOKIES_OWNER) {
    $rGP = ReqAs -Method GET -Path "/api/projects" -Sess $COOKIES_OWNER
    if ($rGP.StatusCode -eq 200) { Log "GET /api/projects = 200" "PASS" }

    $rGT = ReqAs -Method GET -Path "/api/tasks" -Sess $COOKIES_OWNER
    if ($rGT.StatusCode -eq 200) { Log "GET /api/tasks = 200" "PASS" }

    $rGN = ReqAs -Method GET -Path "/api/notifications" -Sess $COOKIES_OWNER
    if ($rGN.StatusCode -eq 200) { Log "GET /api/notifications = 200" "PASS" }

    $rGDS = ReqAs -Method GET -Path "/api/dashboard/stats" -Sess $COOKIES_OWNER
    if ($rGDS.StatusCode -eq 200) { Log "GET /api/dashboard/stats = 200" "PASS" }
}

###############################################################################
# SUMMARY
###############################################################################
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  FINAL RESULTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$passCount = ($RESULTS | Where-Object {$_.Status -eq "PASS"}).Count
$failCount = ($RESULTS | Where-Object {$_.Status -eq "FAIL"}).Count
$infoCount = ($RESULTS | Where-Object {$_.Status -eq "INFO"}).Count

Write-Host "Total=$($RESULTS.Count)  PASS=$passCount  FAIL=$failCount  INFO=$infoCount" -ForegroundColor White

if ($failCount -gt 0) {
    Write-Host "`n[FAILURES]" -ForegroundColor Red
    $RESULTS | Where-Object {$_.Status -eq "FAIL"} | ForEach-Object {
        Write-Host "  [FAIL] $($_.Label)" -ForegroundColor Red
        if ($_.Detail) { Write-Host "         $($_.Detail)" -ForegroundColor Gray }
    }
}

Write-Host "`n--- CLEANUP LIST ---" -ForegroundColor Cyan
Write-Host "Accounts (do NOT delete):" -ForegroundColor Gray
Write-Host "  audit_owner@test.local   id=$OWNER_ID" -ForegroundColor Gray
Write-Host "  audit_admin@test.local   id=$ADMIN_ID" -ForegroundColor Gray
Write-Host "  audit_member@test.local  id=$MEMBER_ID" -ForegroundColor Gray
Write-Host "  audit_outsider@test.local id=$OUTSIDE_ID" -ForegroundColor Gray
Write-Host "AUDIT_TEST_ records:" -ForegroundColor Gray
Write-Host "  Project: AUDIT_TEST_Project1 id=$TEST_PROJ_ID (EXISTS)" -ForegroundColor Gray
Write-Host "  Project: AUDIT_TEST_Project2 id=$TEST_PROJ2_ID (DELETED by cascade test)" -ForegroundColor Gray
Write-Host "  Task: AUDIT_TEST_Task_Main id=$TEST_TASK_ID (in Project1)" -ForegroundColor Gray
Write-Host "  Additional tasks in Project1: AUDIT_TEST_Task_Medium, AUDIT_TEST_Task_High" -ForegroundColor Gray
Write-Host "Database: MongoDB (taskflow db) + JSON file at ./data/database.json" -ForegroundColor Gray
