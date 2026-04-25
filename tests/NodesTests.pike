//! Nodes module tests — Node construction, children, traversal, source_text, range.

import PUnit;
inherit PUnit.TestCase;

void test_node_creation() {
  object n = PikeAst.Nodes.Node("program");
  assert_equal("program", n->node_type);
  assert_equal(0, sizeof(n->children));
  assert_equal(0, n->parent);
}

void test_node_with_token() {
  object t = PikeAst.Token.Token("class", 1, 0, "keyword", 0, 5);
  object n = PikeAst.Nodes.Node("class", t);
  assert_equal(t, n->token);
}

void test_node_with_attributes() {
  object n = PikeAst.Nodes.Node("method", UNDEFINED,
                                (["name": "foo", "return_type": "int"]));
  assert_equal("foo", n->attributes["name"]);
  assert_equal("int", n->attributes["return_type"]);
}

void test_add_child() {
  object parent = PikeAst.Nodes.Node("program");
  object child = PikeAst.Nodes.Node("class");
  parent->add_child(child);
  assert_equal(1, sizeof(parent->children));
  assert_equal(child, parent->children[0]);
  assert_equal(parent, child->parent);
}

void test_descendants() {
  object root = PikeAst.Nodes.Node("program");
  object c1 = PikeAst.Nodes.Node("class");
  object c2 = PikeAst.Nodes.Node("function");
  object c3 = PikeAst.Nodes.Node("variable");
  root->add_child(c1);
  root->add_child(c2);
  c1->add_child(c3);
  array desc = root->descendants();
  assert_equal(3, sizeof(desc));
  assert_true(search(desc, c1) >= 0);
  assert_true(search(desc, c2) >= 0);
  assert_true(search(desc, c3) >= 0);
}

void test_descendants_of_type() {
  object root = PikeAst.Nodes.Node("program");
  object c1 = PikeAst.Nodes.Node("class");
  object c2 = PikeAst.Nodes.Node("class");
  object v1 = PikeAst.Nodes.Node("variable");
  root->add_child(c1);
  root->add_child(c2);
  root->add_child(v1);
  array classes = root->descendants_of_type("class");
  assert_equal(2, sizeof(classes));
}

void test_find_first() {
  object root = PikeAst.Nodes.Node("program");
  object c1 = PikeAst.Nodes.Node("class");
  object m1 = PikeAst.Nodes.Node("method");
  c1->add_child(m1);
  root->add_child(c1);
  object found = root->find_first("method");
  assert_equal(m1, found);
}

void test_find_first_not_found() {
  object root = PikeAst.Nodes.Node("program");
  object found = root->find_first("class");
  assert_equal(0, found);
}

void test_parent_of_type() {
  object root = PikeAst.Nodes.Node("program");
  object cls = PikeAst.Nodes.Node("class");
  object method = PikeAst.Nodes.Node("method");
  root->add_child(cls);
  cls->add_child(method);
  object found = method->parent_of_type("class");
  assert_equal(cls, found);
  object prog = method->parent_of_type("program");
  assert_equal(root, prog);
}

void test_source_range() {
  object t = PikeAst.Token.Token("foo", 3, 5, "identifier", 10, 13, "test.pike");
  object n = PikeAst.Nodes.Node("identifier", t);
  object r = n->range();
  assert_equal(3, r->start_line);
  assert_equal(5, r->start_col);
  assert_equal("test.pike", r->filename);
}

void test_source_range_explicit() {
  object n = PikeAst.Nodes.Node("block");
  object sr = PikeAst.Nodes.SourceRange(1, 0, 10, 5, "test.pike");
  n->source_range = sr;
  object r = n->range();
  assert_equal(1, r->start_line);
  assert_equal(10, r->end_line);
  assert_equal(5, r->end_col);
}

void test_node_name() {
  // Name from attributes
  object n1 = PikeAst.Nodes.Node("class", UNDEFINED, (["name": "Foo"]));
  assert_equal("Foo", n1->name());

  // Name from token
  object t = PikeAst.Token.Token("Foo", 1, 0, "identifier", 0, 3);
  object n2 = PikeAst.Nodes.Node("class", t);
  assert_equal("Foo", n2->name());
}

void test_node_has_doc() {
  object n = PikeAst.Nodes.Node("class");
  assert_false(n->has_doc());

  // Simulate doc attachment
  n->doc = (["summary": "A class"]);
  assert_true(n->has_doc());
}

void test_node_doc_summary() {
  object n = PikeAst.Nodes.Node("class");
  assert_equal(0, n->doc_summary());
}

void test_node_sprintf() {
  object n = PikeAst.Nodes.Node("class", UNDEFINED, (["name": "Foo"]));
  string s = sprintf("%O", n);
  assert_contains("class", s);
  assert_contains("Foo", s);
}

void test_source_range_sprintf() {
  object sr = PikeAst.Nodes.SourceRange(1, 0, 5, 10, "test.pike");
  string s = sprintf("%O", sr);
  assert_contains("SourceRange", s);
  assert_contains("test.pike", s);
}

void test_concrete_node_types() {
  object prog = PikeAst.Nodes.Program();
  assert_equal("program", prog->node_type);

  object cls = PikeAst.Nodes.ClassDecl("Foo");
  assert_equal("class", cls->node_type);
  assert_equal("Foo", cls->attributes["name"]);

  object method = PikeAst.Nodes.MethodDecl("bar", "int");
  assert_equal("method", method->node_type);
  assert_equal("bar", method->attributes["name"]);
  assert_equal("int", method->attributes["return_type"]);

  object func = PikeAst.Nodes.FunctionDecl("baz", "void");
  assert_equal("function", func->node_type);

  object var = PikeAst.Nodes.VariableDecl("x", "int");
  assert_equal("variable", var->node_type);

  object imp = PikeAst.Nodes.ImportDecl("Stdio");
  assert_equal("import", imp->node_type);
  assert_equal("Stdio", imp->attributes["module_path"]);

  object inh = PikeAst.Nodes.InheritDecl("Base.Class");
  assert_equal("inherit", inh->node_type);

  object block = PikeAst.Nodes.Block();
  assert_equal("block", block->node_type);

  object lit = PikeAst.Nodes.LiteralExpr(42, "int");
  assert_equal("literal", lit->node_type);
  assert_equal(42, lit->attributes["value"]);

  object id = PikeAst.Nodes.Identifier("foo");
  assert_equal("identifier", id->node_type);
  assert_equal("foo", id->attributes["name"]);
}

void test_build_tree_manually() {
  object prog = PikeAst.Nodes.Program();
  object cls = PikeAst.Nodes.ClassDecl("Foo");
  object var = PikeAst.Nodes.VariableDecl("x", "int");
  object method = PikeAst.Nodes.MethodDecl("bar", "string");

  prog->add_child(cls);
  cls->add_child(var);
  cls->add_child(method);

  assert_equal(1, sizeof(prog->children));
  assert_equal(2, sizeof(cls->children));
  assert_equal(3, sizeof(prog->descendants()));
  assert_equal(1, sizeof(prog->descendants_of_type("variable")));
  assert_equal(1, sizeof(prog->descendants_of_type("method")));
  assert_equal("Foo", prog->find_first("class")->attributes["name"]);
}
