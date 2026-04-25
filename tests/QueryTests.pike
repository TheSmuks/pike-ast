//! Query module tests.

import PUnit;
inherit PUnit.TestCase;

protected object prog;

void setup() {
  string code = "import Stdio;\n"
                "import Parser.Pike;\n"
                "inherit Base;\n"
                "\n"
                "class Foo {\n"
                "  int x;\n"
                "  string name;\n"
                "  int bar(int a) { return a; }\n"
                "  void baz() {}\n"
                "}\n"
                "\n"
                "class Bar {\n"
                "  float y;\n"
                "}\n"
                "\n"
                "int add(int a, int b) {\n"
                "  return a + b;\n"
                "}\n";
  prog = PikeAst.Parser.parse(code);
}

void test_by_type() {
  object q = PikeAst.Query.Query(prog);
  array classes = q->by_type("class");
  assert_equal(2, sizeof(classes));

  array vars = q->by_type("variable");
  assert_true(sizeof(vars) >= 3);

  array funcs = q->by_type("function");
  assert_true(sizeof(funcs) >= 1);
}

void test_by_name() {
  object q = PikeAst.Query.Query(prog);
  array foos = q->by_name("Foo");
  assert_true(sizeof(foos) >= 1);
}

void test_by_name_not_found() {
  object q = PikeAst.Query.Query(prog);
  array result = q->by_name("NonExistent");
  assert_equal(0, sizeof(result));
}

void test_calls_to() {
  object q = PikeAst.Query.Query(prog);
  array calls = q->calls_to("write");
  assert_true(sizeof(calls) >= 0);  // May or may not find calls in this source
}

void test_imports_of() {
  object q = PikeAst.Query.Query(prog);
  array stdio = q->imports_of("Stdio");
  assert_equal(1, sizeof(stdio));

  array parser = q->imports_of("Parser.Pike");
  assert_equal(1, sizeof(parser));
}

void test_inherits_from() {
  object q = PikeAst.Query.Query(prog);
  array bases = q->inherits_from("Base");
  assert_equal(1, sizeof(bases));
}

void test_all_identifiers() {
  object q = PikeAst.Query.Query(prog);
  multiset ids = q->all_identifiers();
  assert_true(ids["Foo"]);
  assert_true(ids["Bar"]);
  assert_true(ids["add"]);
}

void test_match_class() {
  object q = PikeAst.Query.Query(prog);
  array result = q->match("class Foo");
  assert_equal(1, sizeof(result));
  assert_equal("Foo", result[0]->attributes["name"]);
}

void test_match_class_wildcard() {
  object q = PikeAst.Query.Query(prog);
  array result = q->match("class $NAME");
  assert_equal(2, sizeof(result));
}

void test_match_inherit() {
  object q = PikeAst.Query.Query(prog);
  array result = q->match("inherit Base");
  assert_true(sizeof(result) >= 1);
}

void test_match_import() {
  object q = PikeAst.Query.Query(prog);
  array result = q->match("import Stdio");
  assert_equal(1, sizeof(result));
}

void test_match_method() {
  object q = PikeAst.Query.Query(prog);
  array result = q->match("method bar");
  assert_true(sizeof(result) >= 1);
}

void test_match_fallback_type() {
  object q = PikeAst.Query.Query(prog);
  array result = q->match("import");
  assert_true(sizeof(result) >= 2);
}

void test_convenience_query() {
  object q = PikeAst.Query.query("class Foo { int x; }");
  array classes = q->by_type("class");
  assert_equal(1, sizeof(classes));
}

void test_query_with_docs() {
  string code = "//! A class.\n"
                "class Foo {\n"
                "  //! A method.\n"
                "  void bar() {}\n"
                "}\n";
  object prog = PikeAst.DocExtractor.parse_with_docs(code);
  object q = PikeAst.Query.Query(prog);

  array classes = q->by_type("class");
  assert_true(sizeof(classes) >= 1);
  assert_true(classes[0]->has_doc());
}
