//! AST node types for Pike source code.
//!
//! Provides the Node base class, SourceRange, and all concrete node types
//! for representing Pike programs as trees.

//! Source location range for a node or token.
class SourceRange {
  //! 1-indexed start line.
  int start_line;
  //! 0-indexed start column.
  int start_col;
  //! 1-indexed end line.
  int end_line;
  //! 0-indexed end column.
  int end_col;
  //! Source filename.
  string|void filename;

  //! Create a SourceRange.
  //!
  //! @param start_line
  //! @param start_col
  //! @param end_line
  //! @param end_col
  //! @param filename
  protected void create(int start_line, int start_col,
                        int end_line, int end_col,
                        void|string filename) {
    this_program::start_line = start_line;
    this_program::start_col = start_col;
    this_program::end_line = end_line;
    this_program::end_col = end_col;
    this_program::filename = filename;
  }

  protected string _sprintf(int how) {
    if (how == 'O')
      return sprintf("SourceRange(%d:%d-%d:%d%s)",
                     start_line, start_col, end_line, end_col,
                     filename ? ", " + filename : "");
  }
}

//! Base class for all AST nodes.
class Node {
  //! Node type string.
  string node_type;

  //! Primary token (name/keyword).
  PikeAst.Token.Token|void token;

  //! Child nodes.
  array(object) children = ({});

  //! Parent node.
  object|void parent;

  //! Attached documentation (set by DocExtractor).
  mixed doc;

  //! Type-specific metadata.
  mapping attributes = ([]);

  //! Source range.
  SourceRange|void source_range;

  //! Create a Node.
  //!
  //! @param node_type
  //!   Type string for this node.
  //! @param token
  //!   Optional primary token.
  //! @param attrs
  //!   Optional attribute mapping.
  protected void create(string node_type,
                        void|PikeAst.Token.Token token,
                        void|mapping attrs) {
    this_program::node_type = node_type;
    if (token)
      this_program::token = token;
    if (attrs)
      this_program::attributes = attrs;
  }

  //! Add a child node and set its parent reference.
  //!
  //! @param child
  //!   The node to add as a child.
  void add_child(object child) {
    child->parent = this_program::this;
    children += ({ child });
  }

  //! Get all descendant nodes depth-first.
  //!
  //! @returns
  //!   Flat array of all descendants.
  array(object) descendants() {
    array(object) result = ({});
    foreach(children; ; object child) {
      result += ({ child });
      result += child->descendants();
    }
    return result;
  }

  //! Get all descendants matching a node type.
  //!
  //! @param type
  //!   Node type string to match.
  //! @returns
  //!   Array of matching nodes.
  array(object) descendants_of_type(string type) {
    array(object) result = ({});
    foreach(children; ; object child) {
      if (child->node_type == type)
        result += ({ child });
      result += child->descendants_of_type(type);
    }
    return result;
  }

  //! Find the first descendant matching a type.
  //!
  //! @param type
  //!   Node type string.
  //! @returns
  //!   First matching node, or 0 if none found.
  object|void find_first(string type) {
    foreach(children; ; object child) {
      if (child->node_type == type)
        return child;
      object|void found = child->find_first(type);
      if (found) return found;
    }
    return UNDEFINED;
  }

  //! Find the nearest ancestor matching a type.
  //!
  //! @param type
  //!   Node type string.
  //! @returns
  //!   First matching ancestor, or 0 if none found.
  object|void parent_of_type(string type) {
    if (parent) {
      if (parent->node_type == type)
        return parent;
      return parent->parent_of_type(type);
    }
    return UNDEFINED;
  }

  //! Get the name of this node (from attributes or token).
  //!
  //! @returns
  //!   Name string, or 0 if unnamed.
  string|void name() {
    if (attributes->name)
      return attributes->name;
    if (token)
      return token->text;
    return UNDEFINED;
  }

  //! Reconstruct source text from token range.
  //!
  //! @returns
  //!   Source text string, or "" if no tokens available.
  string source_text() {
    if (token)
      return token->text;
    return "";
  }

  //! Get the source range for this node.
  //!
  //! @returns
  //!   SourceRange, computing from token if not explicitly set.
  SourceRange|void range() {
    if (source_range)
      return source_range;
    if (token) {
      return SourceRange(token->line, token->column,
                         token->line,
                         token->column + sizeof(token->text),
                         token->filename);
    }
    return UNDEFINED;
  }

  //! Returns 1 if a Doc is attached.
  int(0..1) has_doc() {
    return !!doc;
  }

  //! Returns the doc summary text, or 0.
  string|void doc_summary() {
    if (doc && objectp(doc))
      return doc->summary;
    return UNDEFINED;
  }

  protected string _sprintf(int how) {
    if (how == 'O') {
      string name_str = "";
      if (attributes->name) name_str = " " + attributes->name;
      else if (token) name_str = " " + token->text;
      return sprintf("%s%s", node_type, name_str);
    }
  }
}

// ── Concrete Node Types ──────────────────────────────────────────────

//! Top-level program node.
class Program {
  inherit Node;
  protected void create(void|mapping attrs) {
    ::create("program", UNDEFINED, attrs);
  }
}

//! Class declaration.
class ClassDecl {
  inherit Node;
  protected void create(string name, void|PikeAst.Token.Token token,
                        void|array(string) modifiers) {
    ::create("class", token, (["name": name, "modifiers": modifiers || ({})]));
  }
}

//! Method declaration (inside a class).
class MethodDecl {
  inherit Node;
  protected void create(string name, void|string return_type,
                        void|array(string) modifiers,
                        void|array parameters) {
    ::create("method", UNDEFINED,
             (["name": name,
               "return_type": return_type,
               "modifiers": modifiers || ({}),
               "parameters": parameters || ({})]));
  }
}

//! Standalone function declaration.
class FunctionDecl {
  inherit Node;
  protected void create(string name, void|string return_type,
                        void|array parameters) {
    ::create("function", UNDEFINED,
             (["name": name,
               "return_type": return_type,
               "parameters": parameters || ({})]));
  }
}

//! Variable declaration.
class VariableDecl {
  inherit Node;
  protected void create(string name, void|string var_type,
                        void|array(string) modifiers) {
    ::create("variable", UNDEFINED,
             (["name": name,
               "type": var_type,
               "modifiers": modifiers || ({})]));
  }
}

//! Import declaration.
class ImportDecl {
  inherit Node;
  protected void create(string module_path, void|array(string) specifics) {
    ::create("import", UNDEFINED,
             (["module_path": module_path,
               "specifics": specifics || ({})]));
  }
}

//! Inherit declaration.
class InheritDecl {
  inherit Node;
  protected void create(string parent_path, void|string name) {
    ::create("inherit", UNDEFINED,
             (["parent_path": parent_path, "name": name]));
  }
}

//! Constant declaration.
class ConstantDecl {
  inherit Node;
  protected void create(string name, void|mixed value) {
    ::create("constant", UNDEFINED,
             (["name": name, "value": value]));
  }
}

//! Enum declaration.
class EnumDecl {
  inherit Node;
  protected void create(string name) {
    ::create("enum", UNDEFINED, (["name": name]));
  }
}

//! Typedef declaration.
class TypedefDecl {
  inherit Node;
  protected void create(string name, void|string base_type) {
    ::create("typedef", UNDEFINED,
             (["name": name, "base_type": base_type]));
  }
}

//! Block of statements.
class Block {
  inherit Node;
  protected void create() {
    ::create("block");
  }
}

//! If statement.
class IfStmt {
  inherit Node;
  protected void create(void|object condition, void|object then_branch,
                        void|object else_branch) {
    ::create("if", UNDEFINED,
             (["condition": condition,
               "then_branch": then_branch,
               "else_branch": else_branch]));
  }
}

//! For statement.
class ForStmt {
  inherit Node;
  protected void create(void|object init, void|object condition,
                        void|object update, void|object body) {
    ::create("for", UNDEFINED,
             (["init": init, "condition": condition,
               "update": update, "body": body]));
  }
}

//! ForEach statement.
class ForEachStmt {
  inherit Node;
  protected void create(void|mixed variables, void|object iterable,
                        void|object body) {
    ::create("foreach", UNDEFINED,
             (["variables": variables, "iterable": iterable, "body": body]));
  }
}

//! While statement.
class WhileStmt {
  inherit Node;
  protected void create(void|object condition, void|object body) {
    ::create("while", UNDEFINED,
             (["condition": condition, "body": body]));
  }
}

//! Do-while statement.
class DoWhileStmt {
  inherit Node;
  protected void create(void|object body, void|object condition) {
    ::create("do_while", UNDEFINED,
             (["body": body, "condition": condition]));
  }
}

//! Switch statement.
class SwitchStmt {
  inherit Node;
  protected void create(void|object expression) {
    ::create("switch", UNDEFINED, (["expression": expression]));
  }
}

//! Return statement.
class ReturnStmt {
  inherit Node;
  protected void create(void|object value) {
    ::create("return", UNDEFINED, (["value": value]));
  }
}

//! Throw statement.
class ThrowStmt {
  inherit Node;
  protected void create(void|object value) {
    ::create("throw", UNDEFINED, (["value": value]));
  }
}

//! Catch block.
class CatchBlock {
  inherit Node;
  protected void create(void|string variable, void|object body) {
    ::create("catch", UNDEFINED,
             (["variable": variable, "body": body]));
  }
}

//! Generic expression node.
class Expression {
  inherit Node;
  protected void create(void|PikeAst.Token.Token token,
                        void|mapping attrs) {
    ::create("expression", token, attrs);
  }
}

//! Function call expression.
class CallExpr {
  inherit Node;
  protected void create(string|void callee) {
    ::create("call", UNDEFINED, (["callee": callee]));
  }
}

//! Member access expression.
class MemberExpr {
  inherit Node;
  protected void create(void|string member, void|string operator) {
    ::create("member", UNDEFINED,
             (["member": member, "operator": operator || "->"]));
  }
}

//! Index expression.
class IndexExpr {
  inherit Node;
  protected void create() {
    ::create("index");
  }
}

//! Binary expression.
class BinaryExpr {
  inherit Node;
  protected void create(void|string operator) {
    ::create("binary", UNDEFINED, (["operator": operator]));
  }
}

//! Unary expression.
class UnaryExpr {
  inherit Node;
  protected void create(void|string operator, void|int(0..1) prefix) {
    ::create("unary", UNDEFINED,
             (["operator": operator, "prefix": prefix]));
  }
}

//! Literal expression.
class LiteralExpr {
  inherit Node;
  protected void create(mixed value, void|string literal_type) {
    ::create("literal", UNDEFINED,
             (["value": value, "literal_type": literal_type || "int"]));
  }
}

//! Identifier reference.
class Identifier {
  inherit Node;
  protected void create(string name, void|PikeAst.Token.Token token) {
    ::create("identifier", token, (["name": name]));
  }
}

//! Lambda expression.
class LambdaExpr {
  inherit Node;
  protected void create() {
    ::create("lambda");
  }
}

//! Inline annotation.
class Annotation {
  inherit Node;
  protected void create(string text) {
    ::create("annotation", UNDEFINED, (["text": text]));
  }
}
