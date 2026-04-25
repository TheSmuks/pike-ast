//! Parser module tests — parse declarations, classes, methods, control flow, expressions.

import PUnit;
inherit PUnit.TestCase;

void test_parse_empty_source() {
  object prog = PikeAst.Parser.parse("");
  assert_equal("program", prog->node_type);
  assert_equal(0, sizeof(prog->children));
}

void test_parse_class_simple() {
  string code = "class Foo {\n"
                "  int x;\n"
                "}\n";
  object prog = PikeAst.Parser.parse(code);
  assert_equal(1, sizeof(prog->children));
  object cls = prog->children[0];
  assert_equal("class", cls->node_type);
  assert_equal("Foo", cls->attributes["name"]);
}

void test_parse_class_with_members() {
  string code = "class Foo {\n"
                "  int x;\n"
                "  string name;\n"
                "  void bar() {}\n"
                "}\n";
  object prog = PikeAst.Parser.parse(code);
  object cls = prog->find_first("class");
  assert_not_equal(0, cls);
  assert_equal("Foo", cls->attributes["name"]);
  // Should have at least 3 children: x, name, bar
  assert_true(sizeof(cls->children) >= 3);
}

void test_parse_class_with_modifiers() {
  string code = "protected class Foo {\n"
                "  int x;\n"
                "}\n";
  object prog = PikeAst.Parser.parse(code);
  object cls = prog->children[0];
  assert_equal("class", cls->node_type);
  assert_true(sizeof(cls->attributes["modifiers"]) >= 1);
  assert_contains("protected", cls->attributes["modifiers"]);
}

void test_parse_nested_class() {
  string code = "class Outer {\n"
                "  class Inner {\n"
                "    int y;\n"
                "  }\n"
                "}\n";
  object prog = PikeAst.Parser.parse(code);
  object outer = prog->find_first("class");
  assert_equal("Outer", outer->attributes["name"]);
  object inner = outer->find_first("class");
  assert_not_equal(0, inner);
  assert_equal("Inner", inner->attributes["name"]);
}

void test_parse_method() {
  string code = "class Foo {\n"
                "  int bar(int x, string y) {\n"
                "    return x;\n"
                "  }\n"
                "}\n";
  object prog = PikeAst.Parser.parse(code);
  object method = prog->find_first("method");
  assert_not_equal(0, method);
  assert_equal("bar", method->attributes["name"]);
  assert_equal("int", method->attributes["return_type"]);
  assert_equal(2, sizeof(method->attributes["parameters"]));
}

void test_parse_function() {
  string code = "int add(int a, int b) {\n"
                "  return a + b;\n"
                "}\n";
  object prog = PikeAst.Parser.parse(code);
  object func = prog->find_first("function");
  assert_not_equal(0, func);
  assert_equal("add", func->attributes["name"]);
  assert_equal("int", func->attributes["return_type"]);
}

void test_parse_variable() {
  string code = "int x;\n";
  object prog = PikeAst.Parser.parse(code);
  object var = prog->find_first("variable");
  assert_not_equal(0, var);
  assert_equal("x", var->attributes["name"]);
  assert_equal("int", var->attributes["type"]);
}

void test_parse_variable_with_init() {
  string code = "int x = 42;\n";
  object prog = PikeAst.Parser.parse(code);
  object var = prog->find_first("variable");
  assert_not_equal(0, var);
  assert_equal("x", var->attributes["name"]);
}

void test_parse_import() {
  string code = "import Stdio;\n";
  object prog = PikeAst.Parser.parse(code);
  object imp = prog->find_first("import");
  assert_not_equal(0, imp);
  assert_equal("Stdio", imp->attributes["module_path"]);
}

void test_parse_import_dotted() {
  string code = "import Parser.Pike;\n";
  object prog = PikeAst.Parser.parse(code);
  object imp = prog->find_first("import");
  assert_not_equal(0, imp);
  assert_equal("Parser.Pike", imp->attributes["module_path"]);
}

void test_parse_inherit() {
  string code = "inherit Base;\n";
  object prog = PikeAst.Parser.parse(code);
  object inh = prog->find_first("inherit");
  assert_not_equal(0, inh);
  assert_equal("Base", inh->attributes["parent_path"]);
}

void test_parse_inherit_dotted() {
  string code = "inherit Stdio.File;\n";
  object prog = PikeAst.Parser.parse(code);
  object inh = prog->find_first("inherit");
  assert_not_equal(0, inh);
  assert_equal("Stdio.File", inh->attributes["parent_path"]);
}

void test_parse_constant() {
  string code = "constant PI = 3.14;\n";
  object prog = PikeAst.Parser.parse(code);
  object c = prog->find_first("constant");
  assert_not_equal(0, c);
  assert_equal("PI", c->attributes["name"]);
}

void test_parse_enum() {
  string code = "enum Color {\n"
                "  RED, GREEN, BLUE\n"
                "}\n";
  object prog = PikeAst.Parser.parse(code);
  object e = prog->find_first("enum");
  assert_not_equal(0, e);
  assert_equal("Color", e->attributes["name"]);
  assert_true(sizeof(e->children) >= 3);
}

void test_parse_typedef() {
  string code = "typedef int MyInt;\n";
  object prog = PikeAst.Parser.parse(code);
  object td = prog->find_first("typedef");
  assert_not_equal(0, td);
  assert_equal("MyInt", td->attributes["name"]);
  assert_equal("int", td->attributes["base_type"]);
}

void test_parse_multiple_declarations() {
  string code = "import Stdio;\n"
                "inherit Base;\n"
                "int x = 1;\n"
                "string name;\n"
                "class Foo {\n"
                "  int y;\n"
                "}\n";
  object prog = PikeAst.Parser.parse(code);
  assert_true(sizeof(prog->children) >= 4);
  assert_not_equal(0, prog->find_first("import"));
  assert_not_equal(0, prog->find_first("inherit"));
  assert_not_equal(0, prog->find_first("variable"));
  assert_not_equal(0, prog->find_first("class"));
}

void test_parse_preserves_positions() {
  string code = "class Foo {\n"
                "  int x;\n"
                "}\n";
  object prog = PikeAst.Parser.parse(code, "test.pike");
  assert_not_equal(0, prog->source_range);
  assert_equal("test.pike", prog->source_range->filename);
}

void test_parse_file() {
  string tmp = Stdio.append_path(getcwd(),
    "test_parse_" + gethrtime() + ".pike");
  Stdio.write_file(tmp, "class Foo { int x; }\n");
  object prog = PikeAst.Parser.parse_file(tmp);
  assert_equal("program", prog->node_type);
  assert_not_equal(0, prog->find_first("class"));
  rm(tmp);
}

void test_parse_method_with_modifiers() {
  string code = "class Foo {\n"
                "  protected int bar() { return 1; }\n"
                "  private string name;\n"
                "}\n";
  object prog = PikeAst.Parser.parse(code);
  object method = prog->find_first("method");
  assert_not_equal(0, method);
  assert_true(sizeof(method->attributes["modifiers"]) >= 1);
}

void test_parse_variable_with_array_init() {
  string code = "array(int) nums = ({1, 2, 3});\n";
  object prog = PikeAst.Parser.parse(code);
  object var = prog->find_first("variable");
  assert_not_equal(0, var);
  assert_equal("nums", var->attributes["name"]);
}

void test_parse_comments_and_whitespace_ignored() {
  string code = "// This is a comment\n"
                "/* block comment */\n"
                "int x = 1;\n";
  object prog = PikeAst.Parser.parse(code);
  object var = prog->find_first("variable");
  assert_not_equal(0, var);
  assert_equal("x", var->attributes["name"]);
}

void test_parse_preprocessor_ignored() {
  string code = "#define FLAG 1\n"
                "#if FLAG\n"
                "int x;\n"
                "#endif\n";
  object prog = PikeAst.Parser.parse(code);
  object var = prog->find_first("variable");
  assert_not_equal(0, var);
}

void test_parse_empty_class() {
  string code = "class Empty {}\n";
  object prog = PikeAst.Parser.parse(code);
  object cls = prog->find_first("class");
  assert_not_equal(0, cls);
  assert_equal("Empty", cls->attributes["name"]);
  assert_equal(0, sizeof(cls->children));
}

void test_parse_function_no_params() {
  string code = "void hello() {\n"
                "  write(\"hi\");\n"
                "}\n";
  object prog = PikeAst.Parser.parse(code);
  object func = prog->find_first("function");
  assert_not_equal(0, func);
  assert_equal("hello", func->attributes["name"]);
  assert_equal("void", func->attributes["return_type"]);
  assert_equal(0, sizeof(func->attributes["parameters"]));
}

void test_parse_multiple_variables() {
  string code = "int a;\n"
                "string b;\n"
                "float c;\n";
  object prog = PikeAst.Parser.parse(code);
  array vars = prog->descendants_of_type("variable");
  assert_equal(3, sizeof(vars));
}

void test_parse_string_type_variable() {
  string code = "string name = \"hello\";\n";
  object prog = PikeAst.Parser.parse(code);
  object var = prog->find_first("variable");
  assert_not_equal(0, var);
  assert_equal("string", var->attributes["type"]);
}

void test_parse_complex_source() {
  string code = "import Stdio;\n"
                "inherit Base.Module;\n"
                "\n"
                "constant VERSION = \"1.0\";\n"
                "\n"
                "class Handler {\n"
                "  protected int count = 0;\n"
                "  string name;\n"
                "\n"
                "  int increment(int delta) {\n"
                "    count += delta;\n"
                "    return count;\n"
                "  }\n"
                "\n"
                "  void reset() {\n"
                "    count = 0;\n"
                "  }\n"
                "}\n"
                "\n"
                "void main() {\n"
                "  object h = Handler();\n"
                "  h->increment(1);\n"
                "}\n";
  object prog = PikeAst.Parser.parse(code);
  assert_true(sizeof(prog->children) >= 4);
  assert_not_equal(0, prog->find_first("import"));
  assert_not_equal(0, prog->find_first("inherit"));
  assert_not_equal(0, prog->find_first("constant"));
  assert_not_equal(0, prog->find_first("class"));
  assert_not_equal(0, prog->find_first("function"));

  // Verify class members
  object cls = prog->find_first("class");
  assert_equal("Handler", cls->attributes["name"]);
  array methods = cls->descendants_of_type("method");
  assert_true(sizeof(methods) >= 2);
}
