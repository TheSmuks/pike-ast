# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Token class with type classification and position tracking
- Lexer module wrapping Parser.Pike.split() for typed tokenization
- Node base class and 28 concrete AST node types
- Recursive descent parser for Pike source code
- DocExtractor for //! doc comments with @-tag markup parsing
- Query engine for finding nodes by type, name, location, and pattern
- Visitor and Transformer classes for AST traversal and modification
- 120 tests covering all modules
- CI via GitHub Actions (pike 8.0 + pmp)
- Conventional commit enforcement, changelog checks, blob size policy
