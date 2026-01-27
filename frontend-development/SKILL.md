---
name: frontend-development
description: Build modern frontend applications using React, Vue, or vanilla JavaScript. Use this skill for creating UI components, pages, forms, and interactive web interfaces with proper styling, accessibility, and responsive design.
category: development
tags: [frontend, react, typescript, components, ui, accessibility]
license: MIT
---

# Frontend Development

## Responsibilities

- Build components following project patterns
- Write accessible, responsive code
- Use TypeScript for type safety
- Handle loading states and errors

## Constraints

- Functional components and hooks only
- Single responsibility per component
- Semantic HTML elements
- Mobile-first responsive design
- **Do NOT create documentation files** (README.md, ARCHITECTURE.md, etc.) unless explicitly requested

## Workflow

1. Read existing code to understand patterns
2. Plan component structure
3. Implement with proper types
4. Handle edge cases (loading, errors, empty states)
5. **For new projects**: Include test dependencies in package.json (vitest, @testing-library/react) so testing task doesn't need to set up infrastructure

## Patterns

### Component Structure
```tsx
export function UserAvatar({ name, imageUrl }: UserAvatarProps) {
  return (
    <img
      src={imageUrl}
      alt={`${name}'s avatar`}
      className="rounded-full w-10 h-10"
    />
  );
}
```

### Data Fetching
```tsx
function UserList() {
  const { data: users, isLoading, error } = useQuery({
    queryKey: ['users'],
    queryFn: fetchUsers,
  });

  if (isLoading) return <Skeleton count={5} />;
  if (error) return <ErrorMessage error={error} />;

  return (
    <ul>
      {users.map(user => (
        <UserCard key={user.id} user={user} />
      ))}
    </ul>
  );
}
```

### Error Boundaries
```tsx
<ErrorBoundary fallback={<ErrorMessage />}>
  <AsyncComponent />
</ErrorBoundary>
```

## Validation

- TypeScript compiles without errors
- No ESLint errors
- Components properly exported
- Responsive on mobile/tablet/desktop
