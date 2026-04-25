//! AST query engine for finding nodes by type, name, pattern, and location.
//!
//! Provides efficient querying of AST trees for LSP tooling,
//! code analysis, and pattern matching.

//! Query engine for AST trees.
class Query {
  //! Root node of the AST to query.
  object root;

  //! Create a Query engine.
  //!
  //! @param root
  //!   The root AST node (typically a Program).
  protected void create(object root) {
    this_program::root = root;
  }

  //! Find all nodes matching a type.
  //!
  //! @param type
  //!   Node type string (e.g. "class", "method", "variable").
  //! @returns
  //!   Array of matching nodes.
  array(object) by_type(string type) {
    if (root->node_type == type)
      return ({ root }) + root->descendants_of_type(type);
    return root->descendants_of_type(type);
  }

  //! Find all nodes matching a name.
  //!
  //! @param name
  //!   Name to match (from attributes->name or token->text).
  //! @returns
  //!   Array of matching nodes.
  array(object) by_name(string name) {
    return _collect_by_name(root, name, ({}));
  }

  //! Find nodes at a specific source location.
  //!
  //! @param line
  //!   1-indexed line number.
  //! @param column
  //!   Optional 0-indexed column.
  //! @returns
  //!   Array of nodes at that location.
  array(object) at_location(int line, void|int column) {
    return _collect_at_location(root, line, column, ({}));
  }

  //! Find the innermost node at a location (for LSP hover/definition).
  //!
  //! @param line
  //!   1-indexed line number.
  //! @param column
  //!   Optional 0-indexed column.
  //! @returns
  //!   Innermost matching node, or 0.
  object|void innermost_at(int line, void|int column) {
    array(object) nodes = at_location(line, column);
    if (!sizeof(nodes)) return UNDEFINED;
    // Return the last (most specific/deepest) node
    return nodes[-1];
  }

  //! Find all calls to a named function/method.
  //!
  //! @param name
  //!   Function/method name.
  //! @returns
  //!   Array of CallExpr nodes.
  array(object) calls_to(string name) {
    array(object) result = ({});
    array(object) calls = by_type("call");
    foreach(calls; ; object call) {
      if (call->attributes->callee == name)
        result += ({ call });
    }
    return result;
  }

  //! Find all references to an identifier.
  //!
  //! @param name
  //!   Identifier name.
  //! @returns
  //!   Array of nodes referencing this name.
  array(object) references_to(string name) {
    array(object) result = ({});
    // Collect from identifiers, imports, inherits, etc.
    array(object) all = root->descendants();
    foreach(all; ; object node) {
      string|void n = node->name();
      if (n == name)
        result += ({ node });
    }
    return result;
  }

  //! Find all imports of a module.
  //!
  //! @param module_path
  //!   Module path (e.g. "Stdio", "Parser.Pike").
  //! @returns
  //!   Array of ImportDecl nodes.
  array(object) imports_of(string module_path) {
    array(object) result = ({});
    array(object) imports = by_type("import");
    foreach(imports; ; object imp) {
      if (imp->attributes->module_path == module_path)
        result += ({ imp });
    }
    return result;
  }

  //! Find all classes that inherit from a given class.
  //!
  //! @param class_name
  //!   Parent class name.
  //! @returns
  //!   Array of InheritDecl nodes.
  array(object) inherits_from(string class_name) {
    array(object) result = ({});
    array(object) inherits = by_type("inherit");
    foreach(inherits; ; object inh) {
      if (inh->attributes->parent_path == class_name ||
          has_suffix(inh->attributes->parent_path, "." + class_name))
        result += ({ inh });
    }
    return result;
  }

  //! Collect all unique identifiers in the tree.
  //!
  //! @returns
  //!   Multiset of identifier names.
  multiset all_identifiers() {
    multiset ids = (<>);
    array(object) all = root->descendants();
    foreach(all; ; object node) {
      string|void n = node->name();
      if (n) ids[n] = 1;
    }
    return ids;
  }

  //! Find nodes matching a structural pattern.
  //!
  //! Pattern syntax:
  //! - @expr{call($FUNC, $$$ARGS)@} — match calls to any function
  //! - @expr{inherit $MODULE@} — match inherit declarations
  //! - @expr{class $NAME@} — match class declarations
  //! - @expr{$TYPE $NAME@} — match declarations by type and name
  //!
  //! @param pattern
  //!   Pattern string.
  //! @returns
  //!   Array of matching nodes.
  array(object) match(string pattern) {
    array(object) result = ({});

    // Simple pattern matching
    // "call NAME" -> find calls to NAME
    if (has_prefix(pattern, "call ")) {
      string name = String.trim_all_whites(pattern[5..]);
      if (name == "$FUNC" || name == "*")
        return by_type("call");
      return calls_to(name);
    }

    // "inherit NAME" -> find inherit from NAME
    if (has_prefix(pattern, "inherit ")) {
      string name = String.trim_all_whites(pattern[8..]);
      if (name == "$MODULE" || name == "*")
        return by_type("inherit");
      return inherits_from(name);
    }

    // "class NAME" -> find class by name
    if (has_prefix(pattern, "class ")) {
      string name = String.trim_all_whites(pattern[6..]);
      if (name == "$NAME" || name == "*")
        return by_type("class");
      array(object) classes = by_type("class");
      foreach(classes; ; object cls) {
        if (cls->attributes->name == name)
          result += ({ cls });
      }
      return result;
    }

    // "method NAME" -> find method by name
    if (has_prefix(pattern, "method ")) {
      string name = String.trim_all_whites(pattern[7..]);
      array(object) methods = by_type("method");
      foreach(methods; ; object m) {
        if (name == "$NAME" || name == "*" ||
            m->attributes->name == name)
          result += ({ m });
      }
      return result;
    }

    // "import NAME" -> find import by path
    if (has_prefix(pattern, "import ")) {
      string name = String.trim_all_whites(pattern[7..]);
      if (name == "$MODULE" || name == "*")
        return by_type("import");
      return imports_of(name);
    }

    // "variable NAME" -> find variable by name
    if (has_prefix(pattern, "variable ")) {
      string name = String.trim_all_whites(pattern[9..]);
      array(object) vars = by_type("variable");
      foreach(vars; ; object v) {
        if (name == "$NAME" || name == "*" ||
            v->attributes->name == name)
          result += ({ v });
      }
      return result;
    }

    // Fallback: treat as node type
    return by_type(pattern);
  }
}

// ── Internal Helpers ──────────────────────────────────────────────────

private array(object) _collect_by_name(object node, string name, array(object) result) {
  string|void n = node->name();
  if (n == name) result += ({ node });

  foreach(node->children; ; object child) {
    result = _collect_by_name(child, name, result);
  }
  return result;
}

private array(object) _collect_at_location(object node, int line,
                                              void|int column,
                                              array(object) result) {
  // Check if this node's range contains the location
  object|void r = node->range();
  if (r) {
    if (r->start_line <= line && r->end_line >= line) {
      // If column specified, check more precisely
      if (!column || (r->start_line == line && r->start_col <= column) ||
          (r->end_line == line && r->end_col >= column) ||
          (r->start_line < line && r->end_line > line)) {
        result += ({ node });
      }
    }
  } else if (node->token) {
    // Fallback: check token line
    if (node->token->line == line) {
      result += ({ node });
    }
  }

  // Recurse into children
  foreach(node->children; ; object child) {
    result = _collect_at_location(child, line, column, result);
  }
  return result;
}

//! Convenience: parse and query in one step.
//!
//! @param source
//!   Pike source code string.
//! @param filename
//!   Optional filename.
//! @returns
//!   Query object.
Query query(string source, void|string filename) {
  object prog = PikeAst.Parser.parse(source, filename);
  return Query(prog);
}
