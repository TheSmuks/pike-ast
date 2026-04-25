//! Tokenize Pike source code into typed Token array.
//!
//! Wraps @expr{Parser.Pike.split@} to produce @expr{Token@} objects
//! with type classification, source positions, and filename tracking.

//! Tokenize Pike source code into a typed Token array.
//!
//! @param source
//!   Pike source code string.
//! @param filename
//!   Optional filename for source location tracking.
//! @returns
//!   Array of Token objects.
//! @throws
//!   @expr{Parser.Pike.UnterminatedStringError@} on unterminated strings.
array(PikeAst.Token.Token) tokenize(string source, void|string filename) {
  // Use Parser.Pike.split for raw tokens
  array(string) raw_tokens;
  if (mixed e = catch {
    raw_tokens = Parser.Pike.split(source);
  }) {
    throw(e);
  }

  array(PikeAst.Token.Token) result = ({});
  int pos = 0;       // byte offset in source
  int line = 1;      // 1-indexed line
  int col = 0;       // 0-indexed column

  foreach(raw_tokens; ; string text) {
    string type = PikeAst.Token.classify_token(text);

    PikeAst.Token.Token t =
      PikeAst.Token.Token(text, line, col, type, pos, pos + sizeof(text),
                           filename);
    result += ({ t });

    // Advance position
    pos += sizeof(text);

    // Count newlines to track line/column
    int nl_count = String.count(text, "\n");
    if (nl_count > 0) {
      line += nl_count;
      // Column is offset after last newline
      int nl_pos = sizeof(text) - 1;
      while(nl_pos >= 0 && text[nl_pos] != '\n') nl_pos--;
      col = sizeof(text) - nl_pos - 1;
    } else {
      col += sizeof(text);
    }
  }

  return result;
}

//! Tokenize a file.
//!
//! @param path
//!   Path to the Pike source file.
//! @returns
//!   Array of Token objects.
//! @throws
//!   Error if file cannot be read.
array(PikeAst.Token.Token) tokenize_file(string path) {
  string source = Stdio.read_file(path);
  if (!source)
    error("Could not read file: %O\n", path);
  return tokenize(source, path);
}
