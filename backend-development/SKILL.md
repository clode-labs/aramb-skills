---
name: backend-development
description: Build backend services, APIs, and server-side applications. Use this skill for creating REST/GraphQL APIs, database integrations, authentication systems, and server-side business logic in Go, Python, or Node.js.
category: development
tags: [backend, api, rest, golang, python, nodejs, database]
license: MIT
---

# Backend Development

## Responsibilities

- Build APIs following project patterns
- Implement proper validation and error handling
- Write secure, maintainable code
- Follow existing conventions

## Constraints

- Always validate input data
- Use parameterized queries (never string concatenation)
- Follow OWASP security guidelines
- Include structured logging

## Workflow

1. Read existing code to understand patterns
2. Design data models and API contracts
3. Implement with validation
4. Add error handling with proper status codes
5. Write tests for critical paths

## Patterns

### REST API Structure
```
GET    /api/v1/users          # List
GET    /api/v1/users/:id      # Get
POST   /api/v1/users          # Create
PUT    /api/v1/users/:id      # Update
DELETE /api/v1/users/:id      # Delete
```

### Input Validation
```go
type CreateUserRequest struct {
    Email    string `json:"email" validate:"required,email"`
    Password string `json:"password" validate:"required,min=8"`
}
```

### Error Response
```go
type ErrorResponse struct {
    Error   string `json:"error"`
    Message string `json:"message"`
    Code    int    `json:"code"`
}
```

### Parameterized Queries
```go
// GOOD
query := "SELECT * FROM users WHERE email = $1"
row := db.QueryRow(query, email)

// BAD - SQL injection risk
// query := "SELECT * FROM users WHERE email = '" + email + "'"
```

## Security Checklist

- Input validation on all endpoints
- Parameterized database queries
- Authentication on protected routes
- Authorization checks (users access only their data)
- Sensitive data not logged
- Passwords hashed (bcrypt/argon2)

## Validation

- Code compiles/runs without errors
- Tests pass
- No security vulnerabilities
- Proper HTTP status codes
- Migrations run successfully
