//! Visitor pattern for AST traversal and transformation.
//!
//! Provides Visitor and Transformer base classes for walking
//! and modifying AST trees.

//! Base visitor class for AST traversal.
//!
//! Override @expr{enter@} and/or @expr{leave@} to implement
//! custom tree walks.
//!
//! @example
//! class Counter {
//!   inherit PikeAst.Visitor.Visitor;
//!   int count = 0;
//!   int enter(object n) { count++; return 1; }
//! }
class Visitor {
  //! Called when entering a node during traversal.
  //!
  //! @param n
  //!   The node being visited.
  //! @returns
  //!   Return 1 to continue into children, 0 to skip children.
  int(0..1) enter(object n) {
    return 1;
  }

  //! Called when leaving a node (post-order).
  //!
  //! @param n
  //!   The node being visited.
  void leave(object n) {
  }

  //! Run the visitor on a node tree.
  //!
  //! @param root
  //!   Root node to start traversal from.
  void visit(object root) {
    if (enter(root)) {
      foreach(root->children; ; object child) {
        visit(child);
      }
    }
    leave(root);
  }
}

//! Base transformer class for AST modification.
//!
//! Override @expr{transform@} to replace nodes during traversal.
//! Returns a (possibly new) root node.
//!
//! @example
//! class RenameMethod {
//!   inherit PikeAst.Visitor.Transformer;
//!   string old_name;
//!   string new_name;
//!   object transform(object n) {
//!     if (n->node_type == "method" && n->attributes->name == old_name) {
//!       n->attributes["name"] = new_name;
//!     }
//!     return n;
//!   }
//! }
class Transformer {
  //! Transform a node.
  //!
  //! @param n
  //!   The node to transform.
  //! @returns
  //!   The replacement node (or the original if unchanged).
  object transform(object n) {
    return n;
  }

  //! Run the transformer on a node tree.
  //!
  //! @param root
  //!   Root node to transform.
  //! @returns
  //!   The (possibly new) root.
  object run(object root) {
    root = transform(root);
    // Transform children
    array new_children = ({});
    foreach(root->children; ; object child) {
      new_children += ({ run(child) });
    }
    root->children = new_children;
    return root;
  }
}
