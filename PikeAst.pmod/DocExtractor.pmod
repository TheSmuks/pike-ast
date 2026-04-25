//! Extract //! doc comments and parse @-tag markup into structured Doc objects.
//!
//! Parses Pike's AutoDoc-style @expr{//!@} documentation comments into
//! structured @expr{Doc@} objects that attach to AST nodes.
//! Supports the full Pike AutoDoc tag taxonomy.

inherit .Nodes;

//! A single parsed documentation block.
class Doc {
  //! First paragraph (plain text summary).
  string summary;

  //! Full description (may contain markup).
  string description;

  //! @expr{@param@} entries.
  array(mapping) params = ({});

  //! @expr{@returns@} text.
  string|void returns;

  //! @expr{@throws@} entries.
  array(string) throws = ({});

  //! @expr{@note@} entries.
  array(string) notes = ({});

  //! @expr{@bugs@} entries.
  array(string) bugs = ({});

  //! @expr{@example@} entries.
  array(string) examples = ({});

  //! @expr{@seealso@} entries.
  array(string) seealso = ({});

  //! @expr{@deprecated@} text.
  string|void deprecated;

  //! @expr{@section@} containers.
  array(mapping) sections = ({});

  //! @expr{@code@}/@expr{@endcode@} blocks.
  array(mapping) code_blocks = ({});

  //! Unknown/custom tags.
  mapping(string:string) custom = ([]);

  //! Source location of the doc comment.
  SourceRange|void range;

  protected string _sprintf(int how) {
    if (how == 'O')
      return sprintf("Doc(%O%s)", summary,
                     sizeof(params) ? ", " + sizeof(params) + " params" : "");
  }
}

//! Extract doc comments from source and associate with AST nodes.
//!
//! Parses @expr{//!@} comments preceding declarations, following
//! Pike's standard doc-association rules:
//! - Doc before declaration (no blank line between)
//! - Blank line breaks association
//!
//! @param source
//!   Pike source code string.
//! @param filename
//!   Optional filename.
//! @returns
//!   Program node with Doc objects attached.
object parse_with_docs(string source, void|string filename) {
  // First parse the AST
  object prog = PikeAst.Parser.parse(source, filename);

  // Then extract and associate docs
  _extract_and_attach(source, prog, filename);

  return prog;
}

//! Parse a single //! doc comment string into a Doc object.
//!
//! Does NOT handle association -- just the markup parsing.
//!
//! @param lines
//!   Array of //! comment lines (with //! prefix intact).
//! @param range
//!   Optional source range for the comment.
Doc parse_doc_comment(array(string) lines, void|SourceRange range) {
  if (!lines || !sizeof(lines))
    return Doc();

  // Strip //! prefix from each line
  array(string) clean = map(lines, lambda(string line) {
    return has_prefix(line, "//!") ? line[3..] : line;
  });

  Doc doc = Doc();
  if (range) doc->range = range;

  // Parse the lines into sections
  _parse_doc_lines(clean, doc);

  return doc;
}

//! Strip doc comments from source (for code analysis without doc noise).
//!
//! @param source
//!   Pike source code string.
//! @returns
//!   Source with //! comment blocks removed.
string strip_doc_comments(string source) {
  array(string) lines = source / "\n";
  array(string) result = ({});
  int in_doc = 0;

  foreach(lines; ; string line) {
    string trimmed = String.trim_all_whites(line);
    if (has_prefix(trimmed, "//!")) {
      in_doc = 1;
      continue; // skip doc line
    }
    if (in_doc && trimmed == "") {
      // Blank line after doc block -- skip it too
      continue;
    }
    in_doc = 0;
    result += ({ line });
  }

  return result * "\n";
}

// ── Internal Doc Parsing ─────────────────────────────────────────────

// Extract //! blocks and attach to the nearest following declaration
private void _extract_and_attach(string source, object prog, void|string filename) {
  array(string) lines = source / "\n";
  array(mapping) doc_blocks = _find_doc_blocks(lines, filename);

  // Associate each doc block with the nearest AST node
  foreach(doc_blocks; ; mapping db) {
    object node = _find_node_at_line(prog, db->end_line + 1);
    if (node) {
      Doc doc = parse_doc_comment(db->lines,
        SourceRange(db->start_line, 0, db->end_line, 0, filename));
      node->doc = doc;
    }
  }
}

// Find all //! doc blocks in source lines
private array(mapping) _find_doc_blocks(array(string) lines, void|string filename) {
  array(mapping) blocks = ({});
  int i = 0;

  while (i < sizeof(lines)) {
    string trimmed = String.trim_all_whites(lines[i]);
    if (has_prefix(trimmed, "//!")) {
      int start = i;
      array(string) doc_lines = ({});
      // Collect consecutive //! lines
      while (i < sizeof(lines)) {
        trimmed = String.trim_all_whites(lines[i]);
        if (has_prefix(trimmed, "//!")) {
          doc_lines += ({ trimmed });
          i++;
        } else {
          break;
        }
      }
      blocks += ({ ([
        "start_line": start + 1,  // 1-indexed
        "end_line": i,             // line after last //! (1-indexed)
        "lines": doc_lines
      ]) });
    } else {
      i++;
    }
  }

  return blocks;
}

// Find the nearest AST node at or after a given line (recursive)
private object|void _find_node_at_line(object node, int line) {
  foreach(node->children; ; object child) {
    int child_line = 0;
    if (child->token) child_line = child->token->line;
    else if (child->source_range) child_line = child->source_range->start_line;

    // Exact match
    if (child_line == line) return child;

    // If this child started before the target line, search inside it
    if (child_line > 0 && child_line < line) {
      object inner = _find_node_at_line(child, line);
      if (inner) return inner;
    }
  }

  return UNDEFINED;
}

// Parse cleaned doc lines into Doc object
private void _parse_doc_lines(array(string) lines, Doc doc) {
  string current_tag = "";
  string current_text = "";
  string current_param_name = "";
  array(string) current_lines = ({});

  // Collect all content
  string all_text = lines * "\n";

  // First: extract summary (first paragraph before any @tag)
  string summary = "";
  int tag_start = search(all_text, "@");
  if (tag_start >= 0) {
    summary = String.trim_all_whites(all_text[..tag_start - 1]);
  } else {
    summary = String.trim_all_whites(all_text);
  }
  doc->summary = summary;
  doc->description = summary;

  // Parse @tags
  // Split into tag sections
  array(mapping) tags = _parse_tags(lines);

  foreach(tags; ; mapping tag) {
    string name = tag->name;
    string text = String.trim_all_whites(tag->text);

    switch(name) {
      case "param":
        _parse_param_tag(text, doc);
        break;
      case "returns":
      case "return":
        doc->returns = text;
        break;
      case "throws":
      case "throw":
        doc->throws += ({ text });
        break;
      case "note":
        doc->notes += ({ text });
        break;
      case "bugs":
      case "bug":
        doc->bugs += ({ text });
        break;
      case "example":
        doc->examples += ({ text });
        break;
      case "seealso":
      case "see":
        doc->seealso += ({ text });
        break;
      case "deprecated":
        doc->deprecated = text;
        break;
      case "code":
        doc->code_blocks += ({ (["language": "pike", "code": text]) });
        break;
      case "section":
        doc->sections += ({ (["title": text, "content": ""]) });
        break;
      default:
        if (text != "")
          doc->custom[name] = text;
        break;
    }
  }
}

// Parse @param tag: @param name Description text
private void _parse_param_tag(string text, Doc doc) {
  string name = "";
  string desc = "";

  // Format: @param name description
  // or: @param type name description
  int space = search(text, " ");
  if (space >= 0) {
    name = text[..space - 1];
    desc = String.trim_all_whites(text[space + 1..]);

  } else {
    name = text;
  }

  doc->params += ({ (["name": name, "description": desc]) });
}

// Parse lines into @tag sections
private array(mapping) _parse_tags(array(string) lines) {
  array(mapping) tags = ({});
  string current_tag = "";
  string current_text = "";
  int in_code = 0;

  foreach(lines; ; string line) {
    string trimmed = String.trim_all_whites(line);

    if (!trimmed) continue;

    // Handle @code/@endcode blocks
    if (has_prefix(trimmed, "@code")) {
      if (current_tag != "" && current_text != "") {
        tags += ({ (["name": current_tag, "text": current_text]) });
      }
      in_code = 1;
      current_tag = "code";
      current_text = "";
      continue;
    }
    if (has_prefix(trimmed, "@endcode")) {
      in_code = 0;
      tags += ({ (["name": "code", "text": current_text]) });
      current_tag = "";
      current_text = "";
      continue;
    }
    if (in_code) {
      current_text += line + "\n";
      continue;
    }

    // Check for @tag at start of line
    if (sizeof(trimmed) > 1 && trimmed[0] == '@' &&
        (trimmed[1] >= 'a' && trimmed[1] <= 'z')) {
      // Save previous tag
      if (current_tag != "" && current_text != "") {
        tags += ({ (["name": current_tag, "text": current_text]) });
      }

      // Parse new tag
      string tag_name, tag_rest;
      if (sscanf(trimmed, "@%[a-z_]%s", tag_name, tag_rest) >= 1) {
        current_tag = tag_name;
        current_text = String.trim_all_whites(tag_rest);
      }
    } else if (current_tag != "") {
      // Continuation of previous tag
      current_text += " " + trimmed;
    }
  }

  // Save last tag
  if (current_tag != "" && current_text != "") {
    tags += ({ (["name": current_tag, "text": current_text]) });
  }

  return tags;
}
