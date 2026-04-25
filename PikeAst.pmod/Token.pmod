//! Typed token for Pike source code.
//!
//! Wraps raw token text with type classification, source position,
//! and classification helpers.

//! Pike reserved keywords.
constant KEYWORDS = (<
  "if", "else", "for", "foreach", "while", "do", "switch",
  "case", "default", "return", "break", "continue",
  "class", "inherit", "import", "constant", "enum", "typedef",
  "void", "int", "float", "string",
  "array", "mapping", "multiset", "mixed", "object", "program", "function",
  "protected", "private", "public", "static", "final", "inline", "optional",
  "variant", "nomask", "extern", "local",
  "lambda", "gauge", "catch", "typeof", "sscanf",
  "throw", "this", "this_program",
  "true", "false",
  "global",
>);

//! Pike type keywords (used in declarations, not standalone).
constant TYPE_KEYWORDS = (<
  "void", "int", "float", "string",
  "array", "mapping", "multiset", "mixed", "object", "program", "function",
>);

//! Pike modifier keywords.
constant MODIFIER_KEYWORDS = (<
  "protected", "private", "public", "static", "final", "inline", "optional",
  "variant", "nomask", "extern", "local",
>);

//! Delimiter characters.
constant DELIMITERS = (< ";", ",", ".", ":" >);

//! Block start characters.
constant BLOCK_STARTS = (< "{", "(", "[" >);

//! Block end characters.
constant BLOCK_ENDS = (< "}", ")", "]" >);

//! Operators (single and multi-character).
constant OPERATORS = (<
  "=", "==", "===", "!=", "!==" , ">", "<", ">=", "<=",
  "+", "-", "*", "/", "%",
  "+=", "-=", "*=", "/=", "%=",
  "&", "|", "^", "~",
  "&=", "|=", "^=", "<<", ">>", "<<=", ">>=",
  "&&", "||", "!",
  "++", "--",
  "..", "...",
  "?",
  "@",
  "=>",
  "->", "::",
>);

class Token {
  //! Raw token text.
  string text;

  //! 1-indexed line number.
  int line;

  //! 0-indexed column offset on the line.
  int column;

  //! Token type: one of "keyword", "identifier", "string", "int", "float",
  //! "operator", "delimiter", "whitespace", "comment", "preprocessor", "eof".
  string type;

  //! Byte offset of token start in source.
  int start;

  //! Byte offset of token end in source (exclusive).
  int end;

  //! Source filename, if known.
  string|void filename;

  //! Create a Token.
  //!
  //! @param text
  //!   Raw token text.
  //! @param line
  //!   1-indexed line number.
  //! @param column
  //!   0-indexed column offset.
  //! @param type
  //!   Token type string.
  //! @param start
  //!   Byte offset in source.
  //! @param end
  //!   Byte offset of token end (exclusive).
  //! @param filename
  //!   Optional source filename.
  protected void create(string text, int line, int column, string type,
                        int start, int end, void|string filename) {
    this_program::text = text;
    this_program::line = line;
    this_program::column = column;
    this_program::type = type;
    this_program::start = start;
    this_program::end = end;
    this_program::filename = filename;
  }

  //! Returns 1 if this token is a keyword.
  int(0..1) is_keyword() {
    return type == "keyword";
  }

  //! Returns 1 if this token is an identifier.
  int(0..1) is_identifier() {
    return type == "identifier";
  }

  //! Returns 1 if this token is a literal (int, float, string).
  int(0..1) is_literal() {
    return (< "int", "float", "string", "char" >)[type];
  }

  //! Returns 1 if this token is an operator.
  int(0..1) is_operator() {
    return type == "operator";
  }

  //! Returns 1 if this token is a block start: @expr{{@}, @expr{(@}, @expr{[@}.
  int(0..1) is_block_start() {
    return BLOCK_STARTS[text];
  }

  //! Returns 1 if this token is a block end: @expr{}@}, @expr{)@}, @expr{]@}.
  int(0..1) is_block_end() {
    return BLOCK_ENDS[text];
  }

  //! Returns 1 if this token is whitespace.
  int(0..1) is_whitespace() {
    return type == "whitespace";
  }

  //! Returns 1 if this token is a comment.
  int(0..1) is_comment() {
    return type == "comment";
  }

  //! Returns 1 if this token is a preprocessor directive.
  int(0..1) is_preprocessor() {
    return type == "preprocessor";
  }

  //! Returns 1 if this token is a delimiter.
  int(0..1) is_delimiter() {
    return type == "delimiter";
  }

  protected string _sprintf(int how) {
    switch(how) {
      case 'O':
        return sprintf("Token(%O, %O, %d:%d)", type, text, line, column);
      case 's':
        return text;
    }
  }
}

private Regexp IDENT_RE = Regexp("^[a-zA-Z_][a-zA-Z0-9_]*$");

//! Classify a raw token string into a type.
//!
//! @param text
//!   Raw token text from @expr{Parser.Pike.split@}.
//! @returns
//!   Token type string.
string classify_token(string text) {
  if (text == "") return "whitespace";

  // Pure whitespace
  if (sizeof(text) > 0 && String.trim_all_whites(text) == "")
    return "whitespace";

  // Preprocessor directives start with #
  if (sizeof(text) > 0 && text[0] == '#')
    return "preprocessor";

  // Comments
  if (sizeof(text) >= 2) {
    if (text[0..1] == "//") return "comment";
    if (text[0..1] == "/*") return "comment";
  }

  // String literals
  if (sizeof(text) >= 1 && text[0] == '"') return "string";

  // Character literals
  if (sizeof(text) >= 1 && text[0] == '\'') return "char";

  // Block delimiters
  if (BLOCK_STARTS[text] || BLOCK_ENDS[text]) return "delimiter";

  // Multi-char operators and delimiters
  if (DELIMITERS[text]) return "delimiter";
  if (OPERATORS[text]) return "operator";

  // Single character operators
  if (sizeof(text) == 1) {
    switch(text[0]) {
      case '=': case '+': case '-': case '*': case '/':
      case '%': case '&': case '|': case '^': case '~':
      case '!': case '<': case '>': case '?': case '@':
        return "operator";
    }
  }

  // Keywords
  if (KEYWORDS[text]) return "keyword";

  // Numeric literals: starts with a digit
  if (sizeof(text) > 0 && text[0] >= '0' && text[0] <= '9') {
    // Hex: 0x...
    if (has_prefix(text, "0x") || has_prefix(text, "0X")) {
      if (sizeof(text) > 2) return "int";
    }
    // Binary: 0b...
    else if (has_prefix(text, "0b") || has_prefix(text, "0B")) {
      if (sizeof(text) > 2) return "int";
    }
    // Check for float (contains . or e/E)
    if (search(text, ".") >= 0 || search(text, "e") >= 0 ||
        search(text, "E") >= 0)
      return "float";
    return "int";
  }

  // Identifiers: start with letter or underscore, followed by
  // letters, digits, or underscores
  if (IDENT_RE->match(text)) return "identifier";

  // Fallback: treat unknown single chars as operators if they're punctuation
  if (sizeof(text) == 1 && text[0] < '0')
    return "operator";

  return "identifier";
}
