---
name: e2e-testing
description: >
  End-to-end testing protocol — test complete user journeys across services, verify data flows
  through API, UI, and database as a coherent system. Use when: (1) verifying full user journeys
  after backend and frontend pass individual tests, (2) testing cross-service data flows, (3)
  regression testing complete workflows. NOT for: individual endpoint testing (use backend-testing),
  individual UI testing (use frontend-testing), or code changes.
---

# End-to-End Testing

## Starting the Stack

Always start from a clean state with all services:

```bash
docker compose down -v 2>/dev/null
docker compose up -d --build

# Wait for ALL services to be healthy
timeout=180  # longer timeout — multiple services
elapsed=0
while [ $elapsed -lt $timeout ]; do
  unhealthy=$(docker compose ps --format json | jq -r 'select(.Health == "starting" or .State != "running") | .Service' 2>/dev/null)
  if [ -z "$unhealthy" ]; then
    echo "All services healthy"
    break
  fi
  echo "Waiting for: $unhealthy"
  sleep 5
  elapsed=$((elapsed + 5))
done
```

Verify inter-service connectivity before testing:
```bash
# Verify API can reach database
docker compose exec api curl -s http://localhost:3000/health

# Verify frontend can reach API (if applicable)
curl -s http://localhost:3000
```

## Designing User Journeys

A journey is a complete user workflow that touches multiple services. Design journeys that verify the seams between services.

### Journey Template
```
JOURNEY: <name>
SERVICES: <which services are involved>
STEPS:
  1. <action> → <expected result> → <verification>
  2. <action> → <expected result> → <verification>
  ...
DATA FLOW: <how data moves between services>
```

### Common Journey Patterns

**Authentication Journey:**
1. Register new user (API) → 201 Created → verify user in database
2. Login with credentials (API) → receive JWT → verify token is valid
3. Access protected resource (API) → 200 OK → verify user context
4. Access with expired/invalid token → 401 → verify rejection

**CRUD Journey:**
1. Create resource (API or UI) → verify in database
2. Read resource (API or UI) → verify matches what was created
3. Update resource (API or UI) → verify change in database
4. List resources → verify the updated resource appears correctly
5. Delete resource (API or UI) → verify removed from database
6. Attempt to read deleted resource → verify 404 / empty

**Cross-Service Journey:**
1. User action in frontend → API receives request → database stores data
2. Verify each layer saw the correct data
3. Another user action → verify cascading effects across services

## Executing Journeys

### API Calls with State
Journeys carry state between steps. Capture and reuse:

```bash
# Step 1: Register
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"e2e@test.com","password":"testpass123","name":"E2E User"}')
USER_ID=$(echo "$REGISTER_RESPONSE" | jq -r '.user.id')

# Step 2: Login (using credentials from step 1)
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"e2e@test.com","password":"testpass123"}')
TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.token')

# Step 3: Create resource (using token from step 2)
CREATE_RESPONSE=$(curl -s -X POST http://localhost:3000/api/todos \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"title":"E2E Test Todo","description":"Created by integration test"}')
TODO_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id')
```

### Database Verification
Verify data at the source of truth:

```bash
# PostgreSQL
docker compose exec -T db psql -U app -d appdb -c \
  "SELECT id, email, name FROM users WHERE email='e2e@test.com';"

# MongoDB
docker compose exec -T db mongosh appdb --eval \
  "db.users.findOne({email: 'e2e@test.com'})"

# MySQL
docker compose exec -T db mysql -u app -p'password' appdb -e \
  "SELECT id, email, name FROM users WHERE email='e2e@test.com';"
```

### UI + API Combined Journeys
For journeys that span UI and API:

1. Perform action in UI (via Playwright or curl if the frontend is an SPA with API calls)
2. Verify the API received the request (check API logs or database)
3. Verify the UI updated to reflect the change

## Recording Results

For each journey:

```
JOURNEY: User Registration → Login → Create Todo → Verify → Delete
SERVICES: frontend, api, database

STEP 1: Register user via POST /api/auth/register
  → Expected: 201, user in database
  → Actual: 201, user confirmed in database (id=42)
  → ✅ PASS

STEP 2: Login via POST /api/auth/login
  → Expected: 200 with JWT token
  → Actual: 200, token received (valid JWT, expires in 24h)
  → ✅ PASS

STEP 3: Create todo via POST /api/todos (with auth)
  → Expected: 201, todo in database linked to user 42
  → Actual: 201, todo created (id=7, user_id=42 confirmed in DB)
  → ✅ PASS

STEP 4: Verify todo appears in GET /api/todos
  → Expected: list includes todo id=7
  → Actual: list has 1 item, id=7, title matches
  → ✅ PASS

STEP 5: Delete todo via DELETE /api/todos/7
  → Expected: 200 or 204, todo removed from database
  → Actual: 204, database confirms deletion
  → ✅ PASS

JOURNEY RESULT: ✅ PASS (5/5 steps)
```

## Reporting via Verdict Protocol

**All journeys pass:**
```bash
npx mcporter call brahmi.update_my_task status="done" \
  outputs='{"verdict":"pass","summary":"All 3 user journeys verified end-to-end (auth flow, CRUD flow, search flow)"}'
```

**Some journeys fail:**
```bash
npx mcporter call brahmi.update_my_task status="done" \
  outputs='{"verdict":"fail","summary":"2/3 journeys passing, 1 failing","details":"CRUD journey fails at step 4: created todo (id=7) not returned by GET /api/todos — API returns empty list despite DB confirming record exists. Likely a query/filter issue in the list endpoint."}'
```

**NEVER use `status="failed"` for test failures.**

## Cleanup

After all journeys complete:
```bash
docker compose down -v
```
