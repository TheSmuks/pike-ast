# AGENTS.md

## Project overview

PikeAst is an AST library for Pike source code. It provides tokenization, parsing, tree traversal, querying, and pattern matching. Built on top of `Parser.Pike.split()` and `group()` from the Pike stdlib.

- **Name**: pike-ast
- **Description**: AST library for Pike source code
- **Primary Language**: Pike 8.0.1116+

## Setup commands

- Install dependencies: `pike /tank/appdata/pike-dev/projects/pmp/bin/pmp.pike install`
- Run all tests: `pike /tank/appdata/pike-dev/projects/pmp/bin/pmp.pike run run_tests.pike tests/`
- Run one file: `pike /tank/appdata/pike-dev/projects/pmp/bin/pmp.pike run run_tests.pike tests/TokenTests.pike`
- Verbose output: `pike /tank/appdata/pike-dev/projects/pmp/bin/pmp.pike run run_tests.pike -v tests/`

## Architecture

- `PikeAst.pmod/module.pmod` — Re-exports all sub-modules
- `PikeAst.pmod/Version.pmod` — PIKE_AST_VERSION constant
- `PikeAst.pmod/Token.pmod` — Token class with type classification
- `PikeAst.pmod/Lexer.pmod` — Tokenize Pike source into typed Token array
- `PikeAst.pmod/Nodes.pmod` — AST node classes (Node, Program, ClassDecl, MethodDecl, etc.)
- `PikeAst.pmod/Parser.pmod` — Recursive descent parser: token stream → AST
- `PikeAst.pmod/DocExtractor.pmod` — Extract //! doc comments into structured Doc objects
- `PikeAst.pmod/Query.pmod` — AST query engine
- `PikeAst.pmod/Visitor.pmod` — Visitor pattern for tree traversal/transformation
- `run_tests.pike` — PUnit test runner
- `tests/` — Test files (one per module)

## Code style

- Pike 8.0 syntax, 2-space indent, no tabs
- `//!` doc comments for public declarations
- Arrays: `({})`, mappings: `([])`, multisets: `(<>)`
- `catch` blocks: `if (mixed e = catch { ... })` pattern
- Follow existing patterns in the codebase

## Testing instructions

- Every change must be verified with `pmp run run_tests.pike tests/`
- Test files must `import PUnit` and `inherit PUnit.TestCase`
- Test methods must be named `test_*`
- No mocks — test against real Pike source strings

## Commit conventions

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`, `perf`
Scopes: `token`, `lexer`, `nodes`, `parser`, `doc`, `query`, `visitor`

## Pike gotchas

- Pike arrays use `({})`, not `[]`. Mappings use `([])`, not `{}`. Multisets use `(<>)`, not `set()`.
- `sprintf("%O", val)` gives debug output. `sprintf("%q", str)` gives quoted string.
- `multiset` without type parameters (no `multiset(string)`).
- `catch` does not use `try/catch` syntax. Use `if (mixed e = catch { ... })`.
- String multiplication: `"str" * 3` gives `"strstrstr"`.
- `predef::` prefix for builtin overloads (e.g., `predef::`+(...)`).
