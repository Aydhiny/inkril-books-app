# Contributing to Inkril

## Getting Started

1. Read the `README.md` for full architecture and setup documentation
2. Create a feature branch from `main`: `git checkout -b feature/your-feature`
3. Follow the coding conventions in `.editorconfig`
4. Submit a pull request with a clear description

## Branch Naming

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feature/short-description` | `feature/pdf-reader` |
| Bug fix | `fix/issue-description` | `fix/streak-reset` |
| Chore | `chore/description` | `chore/update-deps` |

## Commit Messages

```
<type>(<scope>): <short description>

[optional body]
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`
Scopes: `api`, `worker`, `mobile`, `desktop`, `infra`, `domain`

## Backend (.NET)

- Follow Clean Architecture — no Domain/Infrastructure imports in API layer
- Every command/query must go through MediatR
- All config via `appsettings.json` or environment variables — no hardcoded values
- New entities need: EF config in `InkrilDbContext`, migration, seed data

## Flutter

- Feature-first folder structure: `lib/features/<feature>/`
- State management: Riverpod — use `FutureProvider` for async, `StateNotifierProvider` for complex state
- API URL must be configured via `--dart-define=API_BASE_URL=...`, never hardcoded
- Run `flutter analyze` before committing

## Code Review Checklist

- [ ] No hardcoded secrets or connection strings
- [ ] Input validation present (backend + UI)
- [ ] No unused widgets or dead code
- [ ] Dropdown/select fields populated from API, not hardcoded
- [ ] Confirmation dialogs on destructive/irreversible actions
- [ ] Validation messages shown below fields, not in dialogs
