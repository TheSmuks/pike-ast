# Architecture

## Module Diagram

```
Source code (string)
    |
    v
+---------+
|  Lexer  |  Parser.Pike.split() + classify_token()
+---------+
    |
    v
Token[] (typed, positioned)
    |
    v
+----------+
|  Parser  |  Recursive descent
+----------+
    |
    v
Node tree (Program -> ClassDecl -> MethodDecl -> ...)
    |        |
    |        +-- DocExtractor --> Doc objects attached to nodes
    |
    +-- Query (find by type/name/location/pattern)
    |
    +-- Visitor/Transformer (traverse/modify)
```

## Data Flow

1. **Tokenization**: `Lexer.tokenize(source)` wraps `Parser.Pike.split()` to produce typed `Token` objects with position info and classification (keyword, identifier, operator, etc.)

2. **Parsing**: `Parser.parse(source)` runs a recursive descent parser over the token stream to produce an AST of `Node` objects. Each node has a `node_type`, optional `token`, `children`, `parent`, and `attributes`.

3. **Doc extraction**: `DocExtractor.parse_with_docs(source)` first parses the AST, then scans for `//!` comment blocks and attaches `Doc` objects to the nearest following declaration node.

4. **Querying**: `Query` class wraps an AST root and provides search methods (by_type, by_name, at_location, match pattern).

5. **Traversal**: `Visitor` and `Transformer` base classes for walking and modifying trees.

## Extension Points

- **New node types**: Add a class inheriting `Node` in `Nodes.pmod`
- **New query methods**: Add methods to the `Query` class in `Query.pmod`
- **New @tags**: The doc parser handles unknown tags via `doc->custom`
- **Incremental parsing**: `parse_declaration()` parses a single top-level decl

## Node Type Hierarchy

```
Node (base)
  Program
  ClassDecl
  MethodDecl
  FunctionDecl
  VariableDecl
  ImportDecl
  InheritDecl
  ConstantDecl
  EnumDecl
  TypedefDecl
  Block
  IfStmt / ForStmt / ForEachStmt / WhileStmt / DoWhileStmt / SwitchStmt
  ReturnStmt / ThrowStmt / CatchBlock
  Expression / CallExpr / MemberExpr / IndexExpr / BinaryExpr / UnaryExpr
  LiteralExpr / Identifier / LambdaExpr / Annotation
```
