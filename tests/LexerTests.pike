//! Lexer tokenization tests.

import PUnit;
inherit PUnit.TestCase;

void test_tokenize_simple_declaration() {
  array tokens = PikeAst.Lexer.tokenize("int x = 1;");
  // "int" " " "x" " " "=" " " "1" ";" "\n"
  assert_true(sizeof(tokens) >= 7);
  assert_equal("keyword", tokens[0]->type);
  assert_equal("int", tokens[0]->text);
  assert_equal("identifier", tokens[2]->type);
  assert_equal("x", tokens[2]->text);
}

void test_tokenize_tracks_line_numbers() {
  array tokens = PikeAst.Lexer.tokenize("int x;\nstring y;\n");
  // Find the tokens with type "keyword"
  array kw_tokens = filter(tokens, lambda(object t) { return t->is_keyword(); });
  assert_equal(2, sizeof(kw_tokens));
  assert_equal(1, kw_tokens[0]->line);
  assert_equal(2, kw_tokens[1]->line);
}

void test_tokenize_tracks_columns() {
  array tokens = PikeAst.Lexer.tokenize("int x;");
  // "int" at col 0, " " at col 3, "x" at col 4
  assert_equal(0, tokens[0]->column);
  assert_equal("int", tokens[0]->text);
  assert_equal(4, tokens[2]->column);
  assert_equal("x", tokens[2]->text);
}

void test_tokenize_byte_offsets() {
  array tokens = PikeAst.Lexer.tokenize("int x;");
  // "int" starts at 0, ends at 3
  assert_equal(0, tokens[0]->start);
  assert_equal(3, tokens[0]->end);
  // "x" starts at 4
  assert_equal(4, tokens[2]->start);
}

void test_tokenize_filename() {
  array tokens = PikeAst.Lexer.tokenize("int x;", "test.pike");
  assert_equal("test.pike", tokens[0]->filename);
}

void test_tokenize_string_literal() {
  array tokens = PikeAst.Lexer.tokenize("string s = \"hello\";");
  array str_tokens = filter(tokens,
    lambda(object t) { return t->type == "string"; });
  assert_true(sizeof(str_tokens) >= 1);
  assert_equal("\"hello\"", str_tokens[0]->text);
}

void test_tokenize_comments() {
  string code = "// comment\nint x; /* block */";
  array tokens = PikeAst.Lexer.tokenize(code);
  array comment_tokens = filter(tokens,
    lambda(object t) { return t->is_comment(); });
  assert_equal(2, sizeof(comment_tokens));
}

void test_tokenize_class_declaration() {
  string code = "class Foo {\n"
                "  int x;\n"
                "}\n";
  array tokens = PikeAst.Lexer.tokenize(code);
  // Find "class" keyword
  array class_tokens = filter(tokens,
    lambda(object t) { return t->text == "class"; });
  assert_equal(1, sizeof(class_tokens));
  assert_equal("keyword", class_tokens[0]->type);
}

void test_tokenize_preprocessor() {
  string code = "#define FLAG 1\n"
                "#if FLAG\n"
                "int x;\n"
                "#endif\n";
  array tokens = PikeAst.Lexer.tokenize(code);
  array pp_tokens = filter(tokens,
    lambda(object t) { return t->is_preprocessor(); });
  assert_equal(3, sizeof(pp_tokens));
}

void test_tokenize_multiline_source() {
  string code = "class Foo {\n"
                "  int x = 1;\n"
                "  string name = \"hello\";\n"
                "}\n";
  array tokens = PikeAst.Lexer.tokenize(code);
  // Verify line tracking for "string" keyword (line 3)
  array str_kw = filter(tokens,
    lambda(object t) { return t->text == "string"; });
  assert_true(sizeof(str_kw) >= 1);
  assert_equal(3, str_kw[0]->line);
}

void test_tokenize_operators() {
  string code = "x = y + z;";
  array tokens = PikeAst.Lexer.tokenize(code);
  // x = y + z ;
  // 0 1 2 3 4 5 6 7 8
  array op_tokens = filter(tokens,
    lambda(object t) { return t->is_operator(); });
  assert_true(sizeof(op_tokens) >= 2);  // = and +
}

void test_tokenize_file() {
  // Create a temp file
  string tmp = Stdio.append_path(getcwd(), "test_tmp_" + gethrtime() + ".pike");
  Stdio.write_file(tmp, "int x = 1;\n");
  array tokens = PikeAst.Lexer.tokenize_file(tmp);
  assert_true(sizeof(tokens) >= 5);
  assert_equal(tmp, tokens[0]->filename);
  rm(tmp);
}

void test_tokenize_empty_source() {
  array tokens = PikeAst.Lexer.tokenize("");
  // Parser.Pike.split("") returns ({"\n"})
  assert_true(sizeof(tokens) >= 1);
}

void test_tokenize_hex_literals() {
  array tokens = PikeAst.Lexer.tokenize("0xff 0xABCD");
  array int_tokens = filter(tokens,
    lambda(object t) { return t->type == "int"; });
  assert_equal(2, sizeof(int_tokens));
  assert_equal("0xff", int_tokens[0]->text);
  assert_equal("0xABCD", int_tokens[1]->text);
}

void test_tokenize_float_literals() {
  array tokens = PikeAst.Lexer.tokenize("3.14");
  array float_tokens = filter(tokens,
    lambda(object t) { return t->type == "float"; });
  assert_equal(1, sizeof(float_tokens));
  assert_equal("3.14", float_tokens[0]->text);
}
