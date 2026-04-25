//! Token class tests.

import PUnit;
inherit PUnit.TestCase;

void test_token_creation() {
  object t = PikeAst.Token.Token("int", 1, 0, "keyword", 0, 3, "test.pike");
  assert_equal("int", t->text);
  assert_equal(1, t->line);
  assert_equal(0, t->column);
  assert_equal("keyword", t->type);
  assert_equal(0, t->start);
  assert_equal(3, t->end);
  assert_equal("test.pike", t->filename);
}

void test_token_classification_helpers() {
  object kw = PikeAst.Token.Token("class", 1, 0, "keyword", 0, 5);
  assert_true(kw->is_keyword());
  assert_false(kw->is_identifier());
  assert_false(kw->is_operator());

  object id = PikeAst.Token.Token("foo", 1, 0, "identifier", 0, 3);
  assert_true(id->is_identifier());
  assert_false(id->is_keyword());

  object str = PikeAst.Token.Token("\"hello\"", 1, 0, "string", 0, 7);
  assert_true(str->is_literal());

  object num = PikeAst.Token.Token("42", 1, 0, "int", 0, 2);
  assert_true(num->is_literal());

  object op = PikeAst.Token.Token("+", 1, 0, "operator", 0, 1);
  assert_true(op->is_operator());

  object ws = PikeAst.Token.Token(" ", 1, 0, "whitespace", 0, 1);
  assert_true(ws->is_whitespace());

  object cmt = PikeAst.Token.Token("// hello\n", 1, 0, "comment", 0, 9);
  assert_true(cmt->is_comment());

  object pp = PikeAst.Token.Token("#if FLAG\n", 1, 0, "preprocessor", 0, 9);
  assert_true(pp->is_preprocessor());
}

void test_block_start_end() {
  object open_brace = PikeAst.Token.Token("{", 1, 0, "delimiter", 0, 1);
  assert_true(open_brace->is_block_start());
  assert_false(open_brace->is_block_end());

  object close_brace = PikeAst.Token.Token("}", 1, 0, "delimiter", 0, 1);
  assert_true(close_brace->is_block_end());
  assert_false(close_brace->is_block_start());

  object open_paren = PikeAst.Token.Token("(", 1, 0, "delimiter", 0, 1);
  assert_true(open_paren->is_block_start());

  object close_paren = PikeAst.Token.Token(")", 1, 0, "delimiter", 0, 1);
  assert_true(close_paren->is_block_end());

  object open_bracket = PikeAst.Token.Token("[", 1, 0, "delimiter", 0, 1);
  assert_true(open_bracket->is_block_start());

  object close_bracket = PikeAst.Token.Token("]", 1, 0, "delimiter", 0, 1);
  assert_true(close_bracket->is_block_end());
}

void test_token_sprintf() {
  object t = PikeAst.Token.Token("int", 1, 0, "keyword", 0, 3);
  string s = sprintf("%O", t);
  assert_contains("keyword", s);
  assert_contains("int", s);
}

void test_classify_keyword() {
  assert_equal("keyword", PikeAst.Token.classify_token("class"));
  assert_equal("keyword", PikeAst.Token.classify_token("if"));
  assert_equal("keyword", PikeAst.Token.classify_token("return"));
  assert_equal("keyword", PikeAst.Token.classify_token("int"));
  assert_equal("keyword", PikeAst.Token.classify_token("string"));
  assert_equal("keyword", PikeAst.Token.classify_token("protected"));
  assert_equal("keyword", PikeAst.Token.classify_token("inherit"));
  assert_equal("keyword", PikeAst.Token.classify_token("import"));
}

void test_classify_identifier() {
  assert_equal("identifier", PikeAst.Token.classify_token("foo"));
  assert_equal("identifier", PikeAst.Token.classify_token("_bar"));
  assert_equal("identifier", PikeAst.Token.classify_token("MyClass"));
  assert_equal("identifier", PikeAst.Token.classify_token("x123"));
}

void test_classify_literals() {
  assert_equal("int", PikeAst.Token.classify_token("42"));
  assert_equal("int", PikeAst.Token.classify_token("0xff"));
  assert_equal("int", PikeAst.Token.classify_token("0b1010"));
  assert_equal("int", PikeAst.Token.classify_token("0"));
  assert_equal("float", PikeAst.Token.classify_token("3.14"));
  assert_equal("string", PikeAst.Token.classify_token("\"hello\""));
  assert_equal("char", PikeAst.Token.classify_token("'a'"));
}

void test_classify_operators() {
  assert_equal("operator", PikeAst.Token.classify_token("="));
  assert_equal("operator", PikeAst.Token.classify_token("=="));
  assert_equal("operator", PikeAst.Token.classify_token("!="));
  assert_equal("operator", PikeAst.Token.classify_token("+"));
  assert_equal("operator", PikeAst.Token.classify_token("->"));
  assert_equal("operator", PikeAst.Token.classify_token(".."));
}

void test_classify_delimiters() {
  assert_equal("delimiter", PikeAst.Token.classify_token(";"));
  assert_equal("delimiter", PikeAst.Token.classify_token(","));
  assert_equal("delimiter", PikeAst.Token.classify_token("{"));
  assert_equal("delimiter", PikeAst.Token.classify_token("}"));
  assert_equal("delimiter", PikeAst.Token.classify_token("("));
  assert_equal("delimiter", PikeAst.Token.classify_token(")"));
  assert_equal("delimiter", PikeAst.Token.classify_token("["));
  assert_equal("delimiter", PikeAst.Token.classify_token("]"));
}

void test_classify_whitespace() {
  assert_equal("whitespace", PikeAst.Token.classify_token(" "));
  assert_equal("whitespace", PikeAst.Token.classify_token("  "));
  assert_equal("whitespace", PikeAst.Token.classify_token("\n"));
  assert_equal("whitespace", PikeAst.Token.classify_token("\t"));
}

void test_classify_comments() {
  assert_equal("comment", PikeAst.Token.classify_token("// hello"));
  assert_equal("comment", PikeAst.Token.classify_token("/* block */"));
}

void test_classify_preprocessor() {
  assert_equal("preprocessor", PikeAst.Token.classify_token("#if FLAG"));
  assert_equal("preprocessor", PikeAst.Token.classify_token("#endif"));
  assert_equal("preprocessor", PikeAst.Token.classify_token("#define X 1"));
}

void test_keywords_multiset() {
  assert_true(PikeAst.Token.KEYWORDS["class"]);
  assert_true(PikeAst.Token.KEYWORDS["if"]);
  assert_true(PikeAst.Token.KEYWORDS["return"]);
  assert_false(PikeAst.Token.KEYWORDS["foo"]);
}

void test_token_filename_optional() {
  object t1 = PikeAst.Token.Token("x", 1, 0, "identifier", 0, 1);
  assert_equal(0, t1->filename);

  object t2 = PikeAst.Token.Token("x", 1, 0, "identifier", 0, 1, "foo.pike");
  assert_equal("foo.pike", t2->filename);
}

void test_token_delimiter_helpers() {
  object semi = PikeAst.Token.Token(";", 1, 0, "delimiter", 0, 1);
  assert_true(semi->is_delimiter());

  object comma = PikeAst.Token.Token(",", 1, 0, "delimiter", 0, 1);
  assert_true(comma->is_delimiter());
}
