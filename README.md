# pike-ast

[![CI](https://github.com/TheSmuks/pike-ast/actions/workflows/ci.yml/badge.svg)](https://github.com/TheSmuks/pike-ast/actions/workflows/ci.yml)
[![Commit Lint](https://github.com/TheSmuks/pike-ast/actions/workflows/commit-lint.yml/badge.svg)](https://github.com/TheSmuks/pike-ast/actions/workflows/commit-lint.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0-blue.svg)](https://github.com/TheSmuks/pike-ast/releases/tag/v0.1.0)
[![Pike 8.0](https://img.shields.io/badge/pike-8.0-informational.svg)](https://pike.lysator.liu.se/)


AST library for Pike source code — tokenization, parsing, tree traversal, querying, and pattern matching.

Built on `Parser.Pike.split()` and `group()` from the Pike stdlib.

## Installation

```bash
# Add to pike.json
{
  "dependencies": {
    "PikeAst": "github.com:TheSmuks/pike-ast"
  }
}

# Install via pmp
pike path/to/pmp/bin/pmp.pike install
```

## Quick Start

### Tokenize

```pike
import PikeAst;

array(Token) tokens = PikeAst.Lexer.tokenize("int x = 1;");
// tokens[0]->text == "int", tokens[0]->type == "keyword"
// tokens[2]->text == "x",  tokens[2]->type == "identifier"
```

### Parse to AST

```pike
object prog = PikeAst.Parser.parse("class Foo { int x; }");
// prog->node_type == "program"
// prog->children[0]->node_type == "class"
// prog->children[0]->attributes->name == "Foo"
```

### Extract Documentation

```pike
object prog = PikeAst.DocExtractor.parse_with_docs(
  "//! A simple class.\n"
  "class Foo {\n"
  "  //! The x coordinate.\n"
  "  //! @param val The new value\n"
  "  void set_x(int val) {}\n"
  "}\n"
);

object cls = prog->find_first("class");
cls->doc->summary;  // "A simple class."
```

### Query the AST

```pike
object q = PikeAst.Query.query("class Foo { int bar() { return 1; } }");
array methods = q->by_type("method");
// methods[0]->attributes->name == "bar"
```

### Pattern Matching

```pike
object q = PikeAst.Query.query(source);
array calls = q->match("call write");
array classes = q->match("class $NAME");
```

### Traverse with Visitor

```pike
class MethodCollector {
  inherit PikeAst.Visitor.Visitor;
  array(string) methods = ({});
  int enter(object n) {
    if (n->node_type == "method")
      methods += ({ n->attributes->name });
    return 1;
  }
}

object v = MethodCollector();
v->visit(prog);
// v->methods == ({ "set_x", "bar", ... })
```

## Module Overview

| Module | Purpose |
|--------|---------|
| `Token` | Typed tokens with position tracking and classification |
| `Lexer` | Tokenize Pike source into typed Token array |
| `Nodes` | AST node types (Program, ClassDecl, MethodDecl, etc.) |
| `Parser` | Recursive descent parser: source to AST |
| `DocExtractor` | Extract //! doc comments into structured Doc objects |
| `Query` | Find nodes by type, name, location, pattern |
| `Visitor` | Visitor and Transformer for tree traversal |

## Running Tests

```bash
pike path/to/pmp/bin/pmp.pike install
pike path/to/pmp/bin/pmp.pike run run_tests.pike tests/
```

## License

MIT
