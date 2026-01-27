---
name: frontend-testing
description: Write comprehensive tests for frontend code. Use this skill for creating unit tests for components and hooks, integration tests for user flows, and e2e tests using Jest, Vitest, React Testing Library, Playwright, or Cypress.
category: testing
tags: [frontend, testing, vitest, jest, playwright, react-testing-library]
license: MIT
---

# Frontend Testing

Write comprehensive tests for frontend applications.

## Responsibilities

- Write unit tests for components and hooks
- Write integration tests for user flows
- Write e2e tests for critical paths
- Ensure adequate test coverage
- Follow testing best practices

## Constraints

- Follow existing test patterns in the codebase
- Use the project's established testing framework
- Keep tests focused and independent
- Don't over-mock - test real behavior when possible
- **Do NOT create documentation files** (TEST_SUMMARY.md, README.md, guides) - only create test files
- **Do NOT set up test infrastructure from scratch** - if vitest/jest is not configured, add minimal config to existing files (package.json, vite.config.ts) rather than creating elaborate setups

## Workflow

1. **Check test setup first**
   - Look at package.json for existing test dependencies (vitest, jest, @testing-library/react)
   - If missing, add minimal dependencies - don't create elaborate configs
   - Check if vite.config.ts already has test config

2. **Read existing tests** to understand patterns
   - If no existing tests, use simple patterns from this skill

3. **Identify test cases** based on requirements
   - Focus on critical paths from validation_criteria
   - Don't over-test - cover what's specified

4. **Write tests carefully the first time**
   - Think through test logic before writing
   - Avoid obvious errors that will require re-runs
   - Use correct selectors (check component source for actual text/roles)

5. **Run tests once** to verify they pass
   - If tests fail, fix the actual issue - don't blindly iterate

## Test Types

### Unit Tests
Test individual components and hooks in isolation.

```tsx
describe('Button', () => {
  it('renders with label', () => {
    render(<Button label="Click me" />);
    expect(screen.getByText('Click me')).toBeInTheDocument();
  });

  it('calls onClick when clicked', async () => {
    const handleClick = vi.fn();
    render(<Button label="Click" onClick={handleClick} />);

    await userEvent.click(screen.getByRole('button'));
    expect(handleClick).toHaveBeenCalledOnce();
  });
});
```

### Hook Tests
Test custom hooks with renderHook.

```tsx
describe('useCounter', () => {
  it('increments count', () => {
    const { result } = renderHook(() => useCounter());

    act(() => {
      result.current.increment();
    });

    expect(result.current.count).toBe(1);
  });
});
```

### Integration Tests
Test feature flows with multiple components.

```tsx
describe('LoginForm', () => {
  it('submits credentials and redirects on success', async () => {
    render(<LoginPage />);

    await userEvent.type(screen.getByLabelText('Email'), 'user@example.com');
    await userEvent.type(screen.getByLabelText('Password'), 'password123');
    await userEvent.click(screen.getByRole('button', { name: 'Sign in' }));

    await waitFor(() => {
      expect(mockRouter.push).toHaveBeenCalledWith('/dashboard');
    });
  });
});
```

### E2E Tests (Playwright)

```ts
test('user can complete checkout', async ({ page }) => {
  await page.goto('/products');
  await page.click('[data-testid="add-to-cart"]');
  await page.click('[data-testid="checkout-button"]');

  await page.fill('[name="email"]', 'test@example.com');
  await page.click('[data-testid="place-order"]');

  await expect(page.locator('.order-confirmation')).toBeVisible();
});
```

## Best Practices

- **AAA Pattern**: Arrange, Act, Assert
- **Test behavior, not implementation**: What the user sees/does
- **Use semantic queries**: getByRole, getByLabelText over getByTestId
- **Avoid testing styles**: Focus on functionality
- **Mock external dependencies**: APIs, third-party services

## Output Validation

- All tests pass
- No skipped tests without explanation
- Tests cover happy path and error cases
- Tests are readable and maintainable
