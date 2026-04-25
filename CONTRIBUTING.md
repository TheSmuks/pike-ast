# Contributing to pike-ast

## Development Setup

1. Clone the repository
2. Install dependencies: `pike path/to/pmp/bin/pmp.pike install`
3. Run tests: `pike path/to/pmp/bin/pmp.pike run run_tests.pike tests/`

## Commit Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`, `perf`

Scopes: `token`, `lexer`, `nodes`, `parser`, `doc`, `query`, `visitor`

## Pull Requests

- Update CHANGELOG.md under [Unreleased]
- Run the full test suite before submitting
- One concern per PR
