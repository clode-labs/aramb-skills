---
name: backend-testing
description: Write comprehensive tests for backend code. Use this skill for creating unit tests for services and utilities, integration tests for APIs and database operations, and e2e tests using pytest, Go testing, Jest, or similar frameworks.
category: testing
tags: [backend, testing, golang, pytest, integration, unit-tests]
license: MIT
---

# Backend Testing

Write comprehensive tests for backend applications.

## Responsibilities

- Write unit tests for services and utilities
- Write integration tests for API endpoints
- Write database integration tests
- Ensure adequate test coverage
- Follow testing best practices

## Constraints

- Follow existing test patterns in the codebase
- Use the project's established testing framework
- Keep tests focused and independent
- Use test fixtures and factories for data setup
- Clean up test data after tests

## Workflow

1. **Read existing tests** to understand patterns
2. **Identify test cases** based on requirements
3. **Write unit tests** for business logic
4. **Write integration tests** for APIs and database
5. **Run tests** to verify they pass

## Test Types

### Unit Tests (Go)
Test business logic in isolation.

```go
func TestCalculateTotal(t *testing.T) {
    items := []Item{
        {Price: 10.00},
        {Price: 20.00},
    }

    total := CalculateTotal(items)

    if total != 30.00 {
        t.Errorf("expected 30.00, got %f", total)
    }
}
```

### Table-Driven Tests (Go)
Test multiple cases efficiently.

```go
func TestValidateEmail(t *testing.T) {
    tests := []struct {
        name    string
        email   string
        wantErr bool
    }{
        {"valid email", "user@example.com", false},
        {"missing @", "userexample.com", true},
        {"missing domain", "user@", true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := ValidateEmail(tt.email)
            if (err != nil) != tt.wantErr {
                t.Errorf("ValidateEmail() error = %v, wantErr %v", err, tt.wantErr)
            }
        })
    }
}
```

### API Integration Tests (Go)
Test HTTP handlers with real requests.

```go
func TestCreateUser(t *testing.T) {
    router := setupTestRouter()

    body := `{"email": "test@example.com", "name": "Test User"}`
    req := httptest.NewRequest("POST", "/api/v1/users", strings.NewReader(body))
    req.Header.Set("Content-Type", "application/json")
    w := httptest.NewRecorder()

    router.ServeHTTP(w, req)

    assert.Equal(t, http.StatusCreated, w.Code)

    var response UserResponse
    json.Unmarshal(w.Body.Bytes(), &response)
    assert.Equal(t, "test@example.com", response.Email)
}
```

### Database Tests (Go)
Test database operations with test database.

```go
func TestUserRepository_Create(t *testing.T) {
    db := setupTestDB(t)
    defer db.Close()

    repo := NewUserRepository(db)

    user := &User{Email: "test@example.com"}
    err := repo.Create(context.Background(), user)

    assert.NoError(t, err)
    assert.NotZero(t, user.ID)
}
```

### Python Tests (pytest)

```python
def test_calculate_total():
    items = [{"price": 10.0}, {"price": 20.0}]
    assert calculate_total(items) == 30.0

@pytest.mark.asyncio
async def test_create_user(client: AsyncClient):
    response = await client.post("/api/v1/users", json={
        "email": "test@example.com",
        "name": "Test User"
    })
    assert response.status_code == 201
    assert response.json()["email"] == "test@example.com"
```

## Best Practices

- **AAA Pattern**: Arrange, Act, Assert
- **Test one thing per test**: Single assertion focus
- **Use descriptive names**: Describe the scenario and expected outcome
- **Test edge cases**: Empty inputs, nulls, boundaries
- **Mock external services**: APIs, message queues
- **Use transactions**: Rollback database changes after tests

## Security Tests

- Test authentication is required on protected routes
- Test authorization (users can't access others' data)
- Test input validation (SQL injection, XSS)
- Test rate limiting if applicable

## Output Validation

- All tests pass
- No skipped tests without explanation
- Tests cover happy path and error cases
- Coverage meets project requirements
- Tests run in reasonable time
