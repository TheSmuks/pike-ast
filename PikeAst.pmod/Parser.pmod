//! Recursive descent parser: token stream to AST.
//!
//! Parses Pike source code into a tree of Node objects using
//! the typed Token array from the Lexer module.

inherit .Nodes;

//! Parse Pike source code into an AST.
//!
//! @param source
//!   Pike source code string.
//! @param filename
//!   Optional filename for source location tracking.
//! @returns
//!   A Program node on success.
//! @throws
//!   Error on syntax errors.
object(Program) parse(string source, void|string filename) {
  array tokens = PikeAst.Lexer.tokenize(source, filename);
  return _parse_tokens(tokens, filename);
}

//! Parse a file into an AST.
//!
//! @param path
//!   Path to the Pike source file.
//! @returns
//!   A Program node.
object(Program) parse_file(string path) {
  string source = Stdio.read_file(path);
  if (!source)
    error("Could not read file: %O\n", path);
  return parse(source, path);
}

//! Parse a declaration from a token range.
//!
//! @param tokens
//!   Token array.
//! @param pos
//!   Starting position in the token array.
//! @returns
//!   Parsed node.
object parse_declaration(array tokens, int pos) {
  return _parse_declaration(tokens, pos);
}

// ── Internal Parser State ────────────────────────────────────────────

// Parser state, stored in a mapping for easy passing
#define POS state->pos
#define TOK state->tokens
#define ADVANCE() (POS++)
#define PEEK() (POS < sizeof(TOK) ? TOK[POS] : 0)
#define PEEK_AHEAD(n) ((POS + (n)) < sizeof(TOK) ? TOK[POS + (n)] : 0)

// Internal: parse full token stream into Program
private object(Program) _parse_tokens(array tokens, void|string filename) {
  mapping state = (["tokens": tokens, "pos": 0]);
  object(Program) prog = Program((["filename": filename]));

  while (POS < sizeof(TOK)) {
    object tok = PEEK();
    if (!tok) break;

    // Skip whitespace, comments, preprocessor
    if (tok->is_whitespace() || tok->is_comment() || tok->is_preprocessor()) {
      ADVANCE();
      continue;
    }

    // Try to parse a top-level declaration
    object|void decl = _parse_declaration_state(state);
    if (decl) {
      prog->add_child(decl);
    } else {
      // Skip unknown token
      ADVANCE();
    }
  }

  // Set source range from first/last tokens
  if (sizeof(tokens) > 0) {
    object first = tokens[0];
    object last = tokens[-1];
    if (first && last) {
      prog->source_range = SourceRange(
        first->line, first->column,
        last->line, last->column + sizeof(last->text),
        filename);
    }
  }

  return prog;
}

// Internal: parse a declaration using state mapping
private object|void _parse_declaration_state(mapping state) {
  object tok = PEEK();
  if (!tok) return UNDEFINED;

  // Modifiers: protected, private, public, static, final, etc.
  array(string) modifiers = ({});
  while (tok && tok->is_keyword() &&
         PikeAst.Token.MODIFIER_KEYWORDS[tok->text]) {
    modifiers += ({ tok->text });
    ADVANCE();
    tok = PEEK();
    // Skip whitespace between modifiers
    while (tok && tok->is_whitespace()) {
      ADVANCE();
      tok = PEEK();
    }
  }

  if (!tok) return UNDEFINED;

  switch(tok->text) {
    case "class":
      return _parse_class(state, modifiers);
    case "constant":
      return _parse_constant(state, modifiers);
    case "enum":
      return _parse_enum(state, modifiers);
    case "typedef":
      return _parse_typedef(state, modifiers);
    case "import":
      return _parse_import(state);
    case "inherit":
      return _parse_inherit(state);
  }

  // Check for function/method/variable declaration:
  // type name ( ... ) { ... }   -> function/method
  // type name = ... ;           -> variable
  // type name ;                 -> variable
  if (tok->is_keyword() || tok->is_identifier()) {
    return _parse_type_or_decl(state, modifiers);
  }

  return UNDEFINED;
}

// Internal: parse a declaration from token array at position
private object|void _parse_declaration(array tokens, int pos) {
  mapping state = (["tokens": tokens, "pos": pos]);
  return _parse_declaration_state(state);
}

// Skip whitespace tokens, returning the next non-whitespace token
private object|void _skip_ws(mapping state) {
  while (POS < sizeof(TOK)) {
    object tok = TOK[POS];
    if (tok && !tok->is_whitespace()) return tok;
    POS++;
  }
  return UNDEFINED;
}

// Advance past whitespace
private void _advance_ws(mapping state) {
  while (POS < sizeof(TOK) && TOK[POS] && TOK[POS]->is_whitespace()) {
    POS++;
  }
}

// Consume a specific token text, advancing past it and whitespace
private int(0..1) _expect(mapping state, string text) {
  _advance_ws(state);
  if (POS < sizeof(TOK) && TOK[POS] && TOK[POS]->text == text) {
    POS++;
    return 1;
  }
  return 0;
}

// ── Declaration Parsers ──────────────────────────────────────────────

private object|void _parse_class(mapping state, array(string) modifiers) {
  // class Name [{ ... }]
  ADVANCE(); // skip "class"
  _advance_ws(state);

  object name_tok = _skip_ws(state);
  if (!name_tok || !name_tok->is_identifier()) return UNDEFINED;
  string name = name_tok->text;
  POS++;

  object(ClassDecl) cls = ClassDecl(name, name_tok, modifiers);

  _advance_ws(state);

  // Optional: inherit clauses before body
  if (POS < sizeof(TOK)) {
    object next = _skip_ws(state);
    // Check for body
    if (next && next->text == "{") {
      POS++; // skip {
      _parse_class_body(state, cls);
    }
  }

  return cls;
}

private void _parse_class_body(mapping state, object cls) {
  mixed prev_in_class = state->in_class;
  state->in_class = 1;
  while (POS < sizeof(TOK)) {
    object tok = _skip_ws(state);
    if (!tok) break;
    if (tok->text == "}") {
      POS++; // skip }
      break;
    }

    object|void decl = _parse_declaration_state(state);
    if (decl) {
      cls->add_child(decl);
    } else {
      POS++; // skip unknown
    }
  }
  state->in_class = prev_in_class;
}

private object|void _parse_constant(mapping state, array(string) modifiers) {
  // constant name = value;
  ADVANCE(); // skip "constant"
  _advance_ws(state);

  object name_tok = _skip_ws(state);
  if (!name_tok) return UNDEFINED;
  string name = name_tok->text;
  POS++;

  // Skip = value ;
  _advance_ws(state);
  if (_expect(state, "=")) {
    // Skip until semicolon
    while (POS < sizeof(TOK)) {
      object t = _skip_ws(state);
      if (!t) break;
      if (t->text == ";") { POS++; break; }
      POS++;
    }
  }

  return ConstantDecl(name);
}

private object|void _parse_enum(mapping state, array(string) modifiers) {
  // enum Name { A, B, C }
  ADVANCE(); // skip "enum"
  _advance_ws(state);

  object name_tok = _skip_ws(state);
  if (!name_tok) return UNDEFINED;
  string name = name_tok->text;
  POS++;

  object(EnumDecl) e = EnumDecl(name);

  _advance_ws(state);
  if (_expect(state, "{")) {
    // Parse enum constants
    while (POS < sizeof(TOK)) {
      object tok = _skip_ws(state);
      if (!tok || tok->text == "}") { POS++; break; }
      if (tok->text == ",") { POS++; continue; }
      // Add enum constant as child
      object c = ConstantDecl(tok->text);
      e->add_child(c);
      POS++;
      _advance_ws(state);
      // Skip optional = value
      tok = _skip_ws(state);
      if (tok && tok->text == "=") {
        POS++;
        while (POS < sizeof(TOK)) {
          tok = _skip_ws(state);
          if (!tok || tok->text == "," || tok->text == "}") break;
          POS++;
        }
      }
    }
  }

  return e;
}

private object|void _parse_typedef(mapping state, array(string) modifiers) {
  // typedef type Name;
  ADVANCE(); // skip "typedef"
  _advance_ws(state);

  // Collect base type
  string base_type = _read_type(state);
  _advance_ws(state);

  object name_tok = _skip_ws(state);
  if (!name_tok) return UNDEFINED;
  string name = name_tok->text;
  POS++;

  _expect(state, ";");

  return TypedefDecl(name, base_type);
}

private object|void _parse_import(mapping state) {
  // import Module.Path;
  // import "." . "Path";
  // import Stdio.File;
  ADVANCE(); // skip "import"
  _advance_ws(state);

  string path = _read_dotted_name(state);

  // Check for specific imports: import foo in "bar"
  array(string) specifics = ({});
  _advance_ws(state);

  _expect(state, ";");

  return ImportDecl(path, specifics);
}

private object|void _parse_inherit(mapping state) {
  // inherit Module.Path;
  // inherit Parent : name;
  ADVANCE(); // skip "inherit"
  _advance_ws(state);

  string path = _read_dotted_name(state);
  _advance_ws(state);

  string|void alias;
  if (POS < sizeof(TOK)) {
    object tok = _skip_ws(state);
    if (tok && tok->text == ":") {
      POS++;
      _advance_ws(state);
      object name_tok = _skip_ws(state);
      if (name_tok) {
        alias = name_tok->text;
        POS++;
      }
    }
  }

  _expect(state, ";");

  return InheritDecl(path, alias);
}

private object|void _parse_type_or_decl(mapping state,
                                          array(string) modifiers) {
  // type name ( ... ) { ... } -> method/function
  // type name ;               -> variable
  // type name = expr ;        -> variable

  string type = _read_type(state);
  _advance_ws(state);

  object name_tok = _skip_ws(state);
  if (!name_tok || !name_tok->is_identifier()) return UNDEFINED;
  string name = name_tok->text;
  POS++;

  _advance_ws(state);

  // Check what follows the name
  object next = _skip_ws(state);
  if (!next) return VariableDecl(name, type, modifiers);

  if (next->text == "(") {
    // Function/method declaration
    array params = _parse_parameter_list(state);
    _advance_ws(state);

    string|void return_type = type;

    if (sizeof(modifiers) > 0 || state->in_class) {
      // Inside a class -> method
      object method = MethodDecl(name, return_type, modifiers, params);
      _advance_ws(state);
      // Parse body if present
      next = _skip_ws(state);
      if (next && next->text == "{") {
        POS++; // skip {
        _skip_block_body(state);
      }
      return method;
    } else {
      // Top-level -> function
      object func = FunctionDecl(name, return_type, params);
      _advance_ws(state);
      next = _skip_ws(state);
      if (next && next->text == "{") {
        POS++; // skip {
        _skip_block_body(state);
      }
      return func;
    }
  }

  // Variable declaration
  if (next->text == "=") {
    // Skip until semicolon
    POS++; // skip =
    while (POS < sizeof(TOK)) {
      object t = _skip_ws(state);
      if (!t) break;
      if (t->text == ";") { POS++; break; }
      // Handle nested braces/parens
      if (t->is_block_start()) {
        _skip_balanced(state, t->text);
      } else {
        POS++;
      }
    }
  } else if (next->text == ";") {
    POS++; // skip ;
  }

  return VariableDecl(name, type, modifiers);
}

// ── Helper Functions ─────────────────────────────────────────────────

// Read a type expression (possibly compound: array(int), mapping(string:string), etc.)
private string _read_type(mapping state) {
  _advance_ws(state);
  object tok = _skip_ws(state);
  if (!tok) return "mixed";

  string type = "";

  // Read base type
  if (tok->is_keyword() && (PikeAst.Token.TYPE_KEYWORDS[tok->text] ||
      tok->text == "mixed")) {
    type = tok->text;
    POS++;
    _advance_ws(state);

    // Check for type parameters: array(int), mapping(string:string), etc.
    tok = _skip_ws(state);
    if (tok && tok->text == "(") {
      type += "(";
      POS++; // skip (
      // Read inner type until matching )
      int depth = 1;
      while (POS < sizeof(TOK) && depth > 0) {
        tok = TOK[POS];
        if (!tok) break;
        if (tok->text == "(") depth++;
        else if (tok->text == ")") {
          depth--;
          if (depth == 0) {
            type += ")";
            POS++;
            break;
          }
        }
        if (depth > 0) {
          if (!tok->is_whitespace())
            type += tok->text;
          POS++;
        }
      }
    }
  } else if (tok->is_identifier()) {
    type = tok->text;
    POS++;
    _advance_ws(state);
    // Check for dotted path: Foo.Bar.Baz
    while (POS < sizeof(TOK)) {
      tok = _skip_ws(state);
      if (tok && tok->text == ".") {
        type += ".";
        POS++;
        _advance_ws(state);
        tok = _skip_ws(state);
        if (tok && (tok->is_identifier() || tok->is_keyword())) {
          type += tok->text;
          POS++;
        } else break;
      } else break;
    }
  } else if (tok->text == "|") {
    // Union type: int|string
    type = _read_union_type(state);
  } else {
    type = tok->text;
    POS++;
  }

  // Check for trailing void: type|void
  _advance_ws(state);
  if (POS < sizeof(TOK)) {
    tok = _skip_ws(state);
    if (tok && tok->text == "|") {
      POS++;
      _advance_ws(state);
      tok = _skip_ws(state);
      if (tok) {
        type += "|" + tok->text;
        POS++;
      }
    }
  }

  return type;
}

// Read a union type: int|string|array
private string _read_union_type(mapping state) {
  string result = "";
  while (POS < sizeof(TOK)) {
    object tok = _skip_ws(state);
    if (!tok) break;
    if (tok->text == "|") {
      result += "|";
      POS++;
      continue;
    }
    if (tok->is_keyword() || tok->is_identifier()) {
      result += tok->text;
      POS++;
    } else break;
  }
  return result;
}

// Read a dotted name: Foo.Bar.Baz
private string _read_dotted_name(mapping state) {
  _advance_ws(state);
  object tok = _skip_ws(state);
  if (!tok) return "";

  string name = "";
  while (POS < sizeof(TOK)) {
    tok = _skip_ws(state);
    if (!tok) break;

    if (tok->is_identifier() || tok->is_keyword()) {
      name += tok->text;
      POS++;
      _advance_ws(state);
      // Check for . -> next segment
      object next = _skip_ws(state);
      if (next && next->text == ".") {
        name += ".";
        POS++;
        _advance_ws(state);
      } else break;
    } else if (tok->text == "\"") {
      // String import: import "path/to/module"
      name += tok->text;
      POS++;
      break;
    } else break;
  }

  return name;
}

// Parse a parameter list: (type name, type name, ...)
private array _parse_parameter_list(mapping state) {
  _advance_ws(state);
  if (!_expect(state, "(")) return ({});

  array params = ({});
  while (POS < sizeof(TOK)) {
    _advance_ws(state);
    object tok = _skip_ws(state);
    if (!tok || tok->text == ")") {
      if (tok) POS++; // skip )
      break;
    }
    if (tok->text == ",") { POS++; continue; }

    // Read parameter: [type] name [= default]
    // ... or ...   (rest)
    if (tok->text == "...") {
      // variadic marker
      POS++;
      _advance_ws(state);
      tok = _skip_ws(state);
    }

    string param_type = "";
    string param_name = "";

    // Read type if present
    if (tok->is_keyword() || tok->is_identifier()) {
      // Peek ahead: is this a type followed by a name?
      if (PEEK_AHEAD(2) &&
          !(PEEK_AHEAD(1)->is_whitespace() &&
            PEEK_AHEAD(2)->is_identifier())) {
        // Probably just a name, not type+name
        param_name = tok->text;
        POS++;
      } else {
        param_type = tok->text;
        POS++;
        _advance_ws(state);
        tok = _skip_ws(state);
        if (tok && tok->is_identifier()) {
          param_name = tok->text;
          POS++;
        }
      }
    }

    if (param_name == "" && param_type != "") {
      param_name = param_type;
      param_type = "";
    }

    params += ({ (["name": param_name, "type": param_type]) });

    // Skip default value
    _advance_ws(state);
    tok = _skip_ws(state);
    if (tok && tok->text == "=") {
      POS++;
      while (POS < sizeof(TOK)) {
        tok = _skip_ws(state);
        if (!tok || tok->text == "," || tok->text == ")") break;
        if (tok->is_block_start()) _skip_balanced(state, tok->text);
        else POS++;
      }
    }
  }

  return params;
}

// Skip a balanced block: { ... }, ( ... ), [ ... ]
private void _skip_balanced(mapping state, string open) {
  mapping(string:string) pairs = (["{": "}", "(": ")", "[": "]"]);
  string|void close = pairs[open];
  if (!close) return;

  int depth = 1;
  POS++; // skip opening

  while (POS < sizeof(TOK) && depth > 0) {
    object tok = TOK[POS];
    if (!tok) break;
    if (tok->text == open) depth++;
    else if (tok->text == close) depth--;
    if (depth > 0) POS++;
    else { POS++; break; }
  }
}

// Skip a block body until matching }
private void _skip_block_body(mapping state) {
  _skip_balanced(state, "{");
}
