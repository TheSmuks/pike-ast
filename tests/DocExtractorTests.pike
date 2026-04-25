//! DocExtractor module tests.

import PUnit;
inherit PUnit.TestCase;

void test_parse_doc_summary() {
  array lines = ({ "//! A simple summary." });
  object doc = PikeAst.DocExtractor.parse_doc_comment(lines);
  assert_equal("A simple summary.", doc->summary);
}

void test_parse_doc_multiline_summary() {
  array lines = ({
    "//! First line of summary.",
    "//! Second line of summary.",
  });
  object doc = PikeAst.DocExtractor.parse_doc_comment(lines);
  assert_contains("First line", doc->summary);
  assert_contains("Second line", doc->summary);
}

void test_parse_doc_param() {
  array lines = ({
    "//! A function.",
    "//! @param x The x parameter.",
    "//! @param y The y parameter.",
  });
  object doc = PikeAst.DocExtractor.parse_doc_comment(lines);
  assert_equal("A function.", doc->summary);
  assert_equal(2, sizeof(doc->params));
  assert_equal("x", doc->params[0]->name);
  assert_contains("x parameter", doc->params[0]->description);
  assert_equal("y", doc->params[1]->name);
}

void test_parse_doc_returns() {
  array lines = ({
    "//! A function.",
    "//! @returns The result.",
  });
  object doc = PikeAst.DocExtractor.parse_doc_comment(lines);
  assert_equal("The result.", doc->returns);
}

void test_parse_doc_throws() {
  array lines = ({
    "//! A function.",
    "//! @throws Error when something goes wrong.",
  });
  object doc = PikeAst.DocExtractor.parse_doc_comment(lines);
  assert_equal(1, sizeof(doc->throws));
  assert_contains("Error", doc->throws[0]);
}

void test_parse_doc_note() {
  array lines = ({
    "//! A function.",
    "//! @note This is important.",
  });
  object doc = PikeAst.DocExtractor.parse_doc_comment(lines);
  assert_equal(1, sizeof(doc->notes));
  assert_contains("important", doc->notes[0]);
}

void test_parse_doc_seealso() {
  array lines = ({
    "//! A function.",
    "//! @seealso other_function",
  });
  object doc = PikeAst.DocExtractor.parse_doc_comment(lines);
  assert_equal(1, sizeof(doc->seealso));
  assert_contains("other_function", doc->seealso[0]);
}

void test_parse_doc_deprecated() {
  array lines = ({
    "//! A function.",
    "//! @deprecated Use new_function instead.",
  });
  object doc = PikeAst.DocExtractor.parse_doc_comment(lines);
  assert_not_equal(0, doc->deprecated);
  assert_contains("new_function", doc->deprecated);
}

void test_parse_doc_example() {
  array lines = ({
    "//! A function.",
    "//! @example foo->bar();",
  });
  object doc = PikeAst.DocExtractor.parse_doc_comment(lines);
  assert_equal(1, sizeof(doc->examples));
}

void test_parse_doc_code_block() {
  array lines = ({
    "//! A function.",
    "//! @code",
    "//!   int x = 1;",
    "//!   write(\"%d\\n\", x);",
    "//! @endcode",
  });
  object doc = PikeAst.DocExtractor.parse_doc_comment(lines);
  assert_equal(1, sizeof(doc->code_blocks));
  assert_contains("int x = 1", doc->code_blocks[0]->code);
}

void test_parse_doc_bugs() {
  array lines = ({
    "//! A function.",
    "//! @bugs Doesn't handle edge cases.",
  });
  object doc = PikeAst.DocExtractor.parse_doc_comment(lines);
  assert_equal(1, sizeof(doc->bugs));
}

void test_parse_doc_multiple_tags() {
  array lines = ({
    "//! Does something useful.",
    "//! @param input The input data",
    "//! @returns The processed result",
    "//! @throws Error on invalid input",
    "//! @note Thread-safe",
    "//! @seealso process_advanced",
  });
  object doc = PikeAst.DocExtractor.parse_doc_comment(lines);
  assert_contains("useful", doc->summary);
  assert_equal(1, sizeof(doc->params));
  assert_not_equal(0, doc->returns);
  assert_equal(1, sizeof(doc->throws));
  assert_equal(1, sizeof(doc->notes));
  assert_equal(1, sizeof(doc->seealso));
}

void test_parse_with_docs_basic() {
  string code = "//! A simple class.\n"
                "class Foo {\n"
                "  int x;\n"
                "}\n";
  object prog = PikeAst.DocExtractor.parse_with_docs(code);
  object cls = prog->find_first("class");
  assert_not_equal(0, cls);
  assert_true(cls->has_doc());
  assert_contains("simple class", cls->doc->summary);
}

void test_parse_with_docs_method() {
  string code = "class Foo {\n"
                "  //! Adds two numbers.\n"
                "  //! @param a First number\n"
                "  //! @param b Second number\n"
                "  //! @returns The sum\n"
                "  int add(int a, int b) {\n"
                "    return a + b;\n"
                "  }\n"
                "}\n";
  object prog = PikeAst.DocExtractor.parse_with_docs(code);
  object method = prog->find_first("method");
  assert_not_equal(0, method);
  assert_true(method->has_doc());
  assert_equal(2, sizeof(method->doc->params));
  assert_not_equal(0, method->doc->returns);
}

void test_parse_with_docs_multiple() {
  string code = "//! A documented class.\n"
                "class Foo {\n"
                "  //! A documented variable.\n"
                "  int x;\n"
                "  //! A documented method.\n"
                "  void bar() {}\n"
                "}\n";
  object prog = PikeAst.DocExtractor.parse_with_docs(code);
  object cls = prog->find_first("class");
  assert_true(cls->has_doc());
}

void test_strip_doc_comments() {
  string code = "//! A comment\n"
                "int x = 1;\n"
                "//! Another comment\n"
                "string y;\n";
  string stripped = PikeAst.DocExtractor.strip_doc_comments(code);
  assert_equal(-1, search(stripped, "//!"));
  assert_true(search(stripped, "int x") >= 0);
}

void test_doc_sprintf() {
  array lines = ({ "//! Summary.", "//! @param x desc" });
  object doc = PikeAst.DocExtractor.parse_doc_comment(lines);
  string s = sprintf("%O", doc);
  assert_contains("Doc", s);
  assert_contains("Summary", s);
}

void test_doc_empty_lines() {
  object doc = PikeAst.DocExtractor.parse_doc_comment(({}));
  assert_equal(0, doc->summary);
}

void test_doc_range() {
  array lines = ({ "//! Summary." });
  object sr = PikeAst.Nodes.SourceRange(1, 0, 1, 13, "test.pike");
  object doc = PikeAst.DocExtractor.parse_doc_comment(lines, sr);
  assert_not_equal(0, doc->range);
  assert_equal("test.pike", doc->range->filename);
}

void test_parse_doc_section() {
  array lines = ({
    "//! A function.",
    "//! @section Advanced Usage",
  });
  object doc = PikeAst.DocExtractor.parse_doc_comment(lines);
  assert_equal(1, sizeof(doc->sections));
  assert_contains("Advanced", doc->sections[0]->title);
}

void test_parse_doc_return_alias() {
  // @return should work same as @returns
  array lines = ({
    "//! A function.",
    "//! @return The value.",
  });
  object doc = PikeAst.DocExtractor.parse_doc_comment(lines);
  assert_not_equal(0, doc->returns);
  assert_contains("value", doc->returns);
}
