---
name: backend-testing
description: >
  API testing protocol — start the stack, discover endpoints, test each one with assertions,
  and report results using the verdict protocol. Use when: (1) testing API endpoints after
  development, (2) verifying service health and endpoint correctness, (3) running regression
  tests on backend services. NOT for: frontend/UI testing, deployment, or code changes.
---

# Backend Testing

## Starting the Stack

Always start from a clean state:

```bash
# Tear down any existing state
docker compose down -v 2>/dev/null

# Build and start fresh
docker compose up -d --build

# Wait for services to be healthy (poll every 5s, timeout after 120s)
timeout=120
elapsed=0
while [ $elapsed -lt $timeout ]; do
  if docker compose ps --format json | jq -e 'all(.Health == "healthy" or .Health == "")' > /dev/null 2>&1; then
    echo "All services healthy"
    break
  fi
  sleep 5
  elapsed=$((elapsed + 5))
done

if [ $elapsed -ge $timeout ]; then
  echo "TIMEOUT: Services not healthy after ${timeout}s"
  docker compose ps
  docker compose logs --tail=50
fi
```

If services don't become healthy, check logs and report as `status="failed"` (infrastructure issue, not test failure).

## Discovering Endpoints

Check these sources in order:

1. **OpenAPI/Swagger spec** — look for `openapi.json`, `swagger.json`, `openapi.yaml` in the project root or `docs/` directory. Also check if the running API serves it at `/api-docs`, `/swagger`, `/openapi.json`.

2. **Route files** — grep the codebase for route definitions:
   ```bash
   # Express.js
   grep -rn "router\.\(get\|post\|put\|delete\|patch\)" src/
   # FastAPI
   grep -rn "@app\.\(get\|post\|put\|delete\|patch\)" src/
   # Go (gin/echo/chi)
   grep -rn "\.\(GET\|POST\|PUT\|DELETE\|PATCH\)" src/
   ```

3. **README or docs** — check for documented endpoints.

4. **Test files** — existing test files often reveal endpoints.

Build a complete endpoint list: method, path, expected request body, expected response.

## Testing Each Endpoint

For every discovered endpoint, test in this order:

### 1. Happy Path
Send a valid request with all required fields. Verify:
- Status code matches expectation (200, 201, etc.)
- Response body has expected shape and fields
- Content-Type header is correct

### 2. Validation / Error Cases
- Missing required fields → expect 400
- Invalid field types (string where number expected) → expect 400
- Empty body when body required → expect 400

### 3. Auth Cases (if endpoint requires auth)
- No auth header → expect 401
- Invalid/expired token → expect 401 or 403
- Valid token but wrong role → expect 403

### 4. Edge Cases
- Very long strings (boundary values)
- Special characters in string fields
- Duplicate creation (POST twice with same unique field) → expect 409
- GET/DELETE/PUT on non-existent ID → expect 404

### Request Format

Use curl for consistency:
```bash
# GET
curl -s -w "\n%{http_code}" http://localhost:3000/api/resource

# POST with JSON body
curl -s -w "\n%{http_code}" -X POST http://localhost:3000/api/resource \
  -H "Content-Type: application/json" \
  -d '{"field": "value"}'

# With auth
curl -s -w "\n%{http_code}" -X GET http://localhost:3000/api/protected \
  -H "Authorization: Bearer $TOKEN"
```

Always capture both response body and status code.

## Recording Results

For each endpoint tested, record:

```
ENDPOINT: POST /api/auth/login
REQUEST: {"email": "test@example.com", "password": "validpass"}
EXPECTED: 200 with {"token": "<jwt>", "user": {...}}
ACTUAL: 200 with {"token": "eyJ...", "user": {"id": 1, "email": "test@example.com"}}
RESULT: ✅ PASS

ENDPOINT: POST /api/auth/login
REQUEST: {"email": "test@example.com"} (missing password)
EXPECTED: 400 with error message
ACTUAL: 500 with {"error": "Cannot read property 'length' of undefined"}
RESULT: ❌ FAIL — unhandled error instead of validation response
```

## Reporting via Verdict Protocol

Compile all results and report using the verdict protocol:

**All tests pass:**
```bash
npx mcporter call aramb_tasks.update project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="done" \
  outputs='{"verdict":"pass","summary":"All 15 endpoints tested (45 test cases), all passing"}'
```

**Some tests fail:**
```bash
npx mcporter call aramb_tasks.update project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="done" \
  outputs='{"verdict":"fail","summary":"12/15 endpoints passing, 3 failing","details":"POST /api/users: 500 on valid input (expected 201). GET /api/users/:id: returns 404 for valid ID. DELETE /api/users/:id: timeout after 30s."}'
```

**NEVER use `status="failed"` for test failures.** Only use `status="failed"` when you cannot perform testing at all (stack won't start, repo missing, docker unavailable).

## Teardown

After testing is complete:
```bash
docker compose down -v
```

Clean up any test data or temporary files created during testing.
