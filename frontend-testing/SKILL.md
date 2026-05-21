---
name: frontend-testing
description: >
  Playwright-based UI testing protocol — start the stack, navigate pages, fill forms, click
  buttons, verify renders, capture screenshots on failure, handle waits and loading states.
  Use when: (1) testing frontend UI flows after development, (2) verifying pages render and
  interactions work, (3) regression testing UI components. NOT for: API testing, deployment,
  or code changes.
---

# Frontend Testing

## Starting the Stack

Always start from a clean state:

```bash
# Tear down any existing state
docker compose down -v 2>/dev/null

# Build and start fresh
docker compose up -d --build
```

Wait for the frontend to be reachable before any testing:

```bash
FRONTEND_URL="http://localhost:3000"  # adjust based on docker-compose.yml
timeout=120
elapsed=0
while [ $elapsed -lt $timeout ]; do
  if curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL" | grep -q "200\|301\|302"; then
    echo "Frontend reachable at $FRONTEND_URL"
    break
  fi
  sleep 5
  elapsed=$((elapsed + 5))
done

if [ $elapsed -ge $timeout ]; then
  echo "TIMEOUT: Frontend not reachable after ${timeout}s"
  docker compose logs --tail=50
fi
```

## Discovering UI Flows

Identify what to test by checking:

1. **Route definitions** — check the frontend router (React Router, Vue Router, Next.js pages):
   ```bash
   # React Router
   grep -rn "Route\|path=" src/
   # Next.js
   ls -R pages/ app/
   # Vue Router
   grep -rn "path:" src/router/
   ```

2. **Navigation components** — find menus, navbars, sidebars that reveal available pages.

3. **Task description** — the task may specify exact flows to test.

4. **README** — may document available pages and features.

Build a flow list: flow name, starting URL, steps (click X, fill Y, verify Z).

## Playwright Test Patterns

### Page Navigation
```javascript
await page.goto('http://localhost:3000/login');
await page.waitForLoadState('networkidle');
```

### Form Filling
```javascript
await page.fill('input[name="email"]', 'test@example.com');
await page.fill('input[name="password"]', 'password123');
await page.click('button[type="submit"]');
```

### Waiting for Elements
Always use Playwright's built-in waiting. Never use `page.waitForTimeout()` (fixed sleep).

```javascript
// Wait for element to appear
await page.waitForSelector('.dashboard-content', { timeout: 10000 });

// Wait for navigation after click
await Promise.all([
  page.waitForNavigation(),
  page.click('a[href="/dashboard"]'),
]);

// Wait for element to disappear (loading spinner)
await page.waitForSelector('.loading-spinner', { state: 'hidden' });
```

### Assertions
```javascript
// Element exists and is visible
await expect(page.locator('h1')).toBeVisible();

// Text content
await expect(page.locator('.welcome-message')).toContainText('Welcome');

// URL changed
await expect(page).toHaveURL(/\/dashboard/);

// Element count
await expect(page.locator('.todo-item')).toHaveCount(3);
```

### Screenshot on Failure
```javascript
try {
  await expect(page.locator('.submit-btn')).toBeVisible();
} catch (error) {
  await page.screenshot({ path: '/tmp/test-screenshots/submit-btn-missing.png', fullPage: true });
  throw error;
}
```

Create the screenshot directory before tests:
```bash
mkdir -p /tmp/test-screenshots
```

## Selector Strategy

Prefer selectors in this order (most reliable first):

1. `data-testid` attributes — `[data-testid="login-button"]`
2. ARIA roles — `role=button[name="Submit"]`
3. Semantic HTML — `button[type="submit"]`, `input[name="email"]`
4. Text content — `text=Sign In` (use sparingly, breaks with i18n)
5. CSS classes — `.login-btn` (fragile, use as last resort)

## Recording Results

For each flow tested, record:

```
FLOW: User Login
STEPS:
  1. Navigate to /login — ✅ Page renders, form visible
  2. Fill email "test@example.com" — ✅ Input accepted
  3. Fill password "password123" — ✅ Input accepted
  4. Click "Sign In" button — ✅ Button clicked
  5. Verify redirect to /dashboard — ❌ FAIL: stayed on /login, error message "Invalid credentials"
RESULT: ❌ FAIL
SCREENSHOT: /tmp/test-screenshots/login-fail.png
```

## Reporting via Verdict Protocol

Compile all results and report:

**All flows pass:**
```bash
npx mcporter call brahmi.update_task project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="done" \
  outputs='{"verdict":"pass","summary":"All 6 UI flows verified — login, signup, dashboard, create, edit, delete"}'
```

**Some flows fail:**
```bash
npx mcporter call brahmi.update_task project_id="<PROJECT_ID>" task_id="<TASK_UUID>" status="done" \
  outputs='{"verdict":"fail","summary":"4/6 flows passing, 2 failing","details":"Create flow: submit button unresponsive (screenshot: /tmp/test-screenshots/create-fail.png). Delete flow: confirmation modal never appears (screenshot: /tmp/test-screenshots/delete-fail.png)."}'
```

**NEVER use `status="failed"` for test failures.** Only use `status="failed"` when you cannot perform testing at all.

## Teardown

After testing is complete:
```bash
docker compose down -v
```
