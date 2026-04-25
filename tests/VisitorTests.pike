//! Visitor module tests.

import PUnit;
inherit PUnit.TestCase;

// Counter visitor
class CountVisitor {
  inherit PikeAst.Visitor.Visitor;
  int count = 0;
  int enter(object n) { count++; return 1; }
}

// Selective visitor (skip class children)
class SkipClassVisitor {
  inherit PikeAst.Visitor.Visitor;
  int count = 0;
  int enter(object n) { count++; return n->node_type != "class"; }
}

// Enter/leave tracker
class TrackVisitor {
  inherit PikeAst.Visitor.Visitor;
  array(string) entered = ({});
  array(string) left = ({});
  int enter(object n) { entered += ({ n->node_type }); return 1; }
  void leave(object n) { left += ({ n->node_type }); }
}

// Identifier collector
class IdCollector {
  inherit PikeAst.Visitor.Visitor;
  multiset(string) ids = (<>);
  int enter(object n) {
    string|void name = n->name();
    if (name) ids[name] = 1;
    return 1;
  }
}

// Doc collector
class DocCollector {
  inherit PikeAst.Visitor.Visitor;
  int doc_count = 0;
  int enter(object n) {
    if (n->has_doc()) doc_count++;
    return 1;
  }
}

// Count transformer
class CountTransformer {
  inherit PikeAst.Visitor.Transformer;
  int count = 0;
  object transform(object n) { count++; return n; }
}

// Rename transformer
class RenameTransformer {
  inherit PikeAst.Visitor.Transformer;
  string old_name;
  string new_name;
  object transform(object n) {
    if (n->node_type == "class" && n->attributes->name == old_name) {
      n->attributes["name"] = new_name;
    }
    return n;
  }
}

protected object prog;

void setup() {
  string code = "class Foo {\n"
                "  int x;\n"
                "  string name;\n"
                "  int bar(int a) { return a; }\n"
                "  void baz() {}\n"
                "}\n"
                "\n"
                "class Bar {\n"
                "  float y;\n"
                "}\n";
  prog = PikeAst.Parser.parse(code);
}

void test_visitor_visits_all_nodes() {
  object v = CountVisitor();
  v->visit(prog);
  assert_true(v->count >= 8);
}

void test_visitor_selective_skip() {
  object v = SkipClassVisitor();
  v->visit(prog);
  // Should visit program + 2 classes but NOT their children
  assert_equal(3, v->count);
}

void test_visitor_enter_and_leave() {
  object v = TrackVisitor();
  v->visit(prog);
  assert_equal(sizeof(v->entered), sizeof(v->left));
  assert_equal("program", v->entered[0]);
  assert_true(sizeof(v->left) > 0);
}

void test_transformer_identity() {
  object t = PikeAst.Visitor.Transformer();
  object result = t->run(prog);
  assert_equal("program", result->node_type);
  assert_true(sizeof(result->children) >= 2);
}

void test_transformer_modify_attributes() {
  object t = RenameTransformer();
  t->old_name = "Foo";
  t->new_name = "RenamedFoo";
  object result = t->run(prog);
  array classes = result->descendants_of_type("class");
  int found = 0;
  foreach(classes; ; object cls) {
    if (cls->attributes->name == "RenamedFoo") found = 1;
  }
  assert_true(found);
}

void test_transformer_count_nodes() {
  object t = CountTransformer();
  t->run(prog);
  assert_true(t->count >= 8);
}

void test_visitor_collect_identifiers() {
  object v = IdCollector();
  v->visit(prog);
  assert_true(v->ids["Foo"]);
  assert_true(v->ids["Bar"]);
  assert_true(v->ids["x"]);
  assert_true(v->ids["bar"]);
}

void test_visitor_collect_documented_nodes() {
  string code = "//! A class.\n"
                "class Foo {\n"
                "  //! A variable.\n"
                "  int x;\n"
                "  //! A method.\n"
                "  void bar() {}\n"
                "}\n";
  object doc_prog = PikeAst.DocExtractor.parse_with_docs(code);

  object v = DocCollector();
  v->visit(doc_prog);
  assert_true(v->doc_count >= 2);
}
