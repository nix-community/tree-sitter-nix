#include <tree_sitter/parser.h>

enum TokenType {
  STRING_FRAGMENT,
  INDENTED_STRING_FRAGMENT,
  PATH_START,
  PATH_FRAGMENT,
  DOLLAR_ESCAPE,
  INDENTED_DOLLAR_ESCAPE,
  INJECTION_COMMENT_PREFIX,
  INJECTION_LANGUAGE,
  INJECTION_COMMENT_SUFFIX,
};

static void advance(TSLexer *lexer) { lexer->advance(lexer, false); }

static void skip(TSLexer *lexer) { lexer->advance(lexer, true); }

static bool scan_dollar_escape(TSLexer *lexer) {
  lexer->result_symbol = DOLLAR_ESCAPE;
  advance(lexer);
  lexer->mark_end(lexer);
  if (lexer->lookahead == '$') {
    return true;
  } else {
    return false;
  }
}

static bool scan_indented_dollar_escape(TSLexer *lexer) {
  lexer->result_symbol = INDENTED_DOLLAR_ESCAPE;
  advance(lexer);
  lexer->mark_end(lexer);
  if (lexer->lookahead == '$') {
    return true;
  } else {
    if (lexer->lookahead == '\\') {
      advance(lexer);
      if (lexer->lookahead == '$') {
        lexer->mark_end(lexer);
        return true;
      }
    }
    return false;
  }
}

// Here we only parse literal fragment inside a string.
// Delimiter, interpolation and escape sequence are handled by the parser and we
// simply stop at them.
//
// The implementation is inspired by tree-sitter-javascript:
// https://github.com/tree-sitter/tree-sitter-javascript/blob/fdeb68ac8d2bd5a78b943528bb68ceda3aade2eb/src/scanner.c#L19
static bool scan_string_fragment(TSLexer *lexer) {
  lexer->result_symbol = STRING_FRAGMENT;
  for (bool has_content = false;; has_content = true) {
    lexer->mark_end(lexer);
    switch (lexer->lookahead) {
    case '"':
    case '\\':
      return has_content;
    case '$':
      advance(lexer);
      if (lexer->lookahead == '{') {
        return has_content;
      } else if (lexer->lookahead != '"' && lexer->lookahead != '\\') {
        // Any char following '$' other than '"', '\\' and '{' (which was
        // handled above) should be consumed as additional string content. This
        // means `$${` doesn't start an interpolation, but `$$${` does.
        advance(lexer);
      }
      break;
    // Simply give up on EOF or '\0'.
    case '\0':
      return false;
    default:
      advance(lexer);
    }
  }
}

// See comments of scan_string_fragment.
static bool scan_indented_string_fragment(TSLexer *lexer) {
  lexer->result_symbol = INDENTED_STRING_FRAGMENT;
  for (bool has_content = false;; has_content = true) {
    lexer->mark_end(lexer);
    switch (lexer->lookahead) {
    case '$':
      advance(lexer);
      if (lexer->lookahead == '{') {
        return has_content;
      } else if (lexer->lookahead != '\'') {
        // Any char following '$' other than '\'' and '{' (which was handled
        // above) should be consumed as additional string content. This means
        // `$${` doesn't start an interpolation, but `$$${` does.
        advance(lexer);
      }
      break;
    case '\'':
      advance(lexer);
      if (lexer->lookahead == '\'') {
        // Two single quotes always stop current string fragment.
        // It can be either an end delimiter '', or escape sequences ''', ''$,
        // ''\<any>
        return has_content;
      }
      break;
    // Simply give up on EOF or '\0'.
    case '\0':
      return false;
    default:
      advance(lexer);
    }
  }
}

static bool is_path_char(int32_t c) {
  return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') ||
         (c >= 'A' && c <= 'Z') || c == '-' || c == '+' || c == '_' ||
         c == '.' || c == '/';
}

static bool scan_path_start(TSLexer *lexer) {
  lexer->result_symbol = PATH_START;

  bool have_sep = false;
  bool have_after_sep = false;
  int32_t c = lexer->lookahead;

  // unlike string_fragments which which are preceded by initial token (i.e.
  // '"') and thus will have all leading external whitespace consumed, we have
  // no such luxury with the path_start token.
  //
  // so we must skip over any leading whitespace here.
  while (c == ' ' || c == '\n' || c == '\r' || c == '\t') {
    skip(lexer);
    c = lexer->lookahead;
  }

  while (true) {
    lexer->mark_end(lexer);
    c = lexer->lookahead;

    if (c == '/') {
      have_sep = true;
    } else if (is_path_char(c)) {
      if (have_sep) {
        have_after_sep = true;
      }
    } else if (c == '$') {
      // starting a interpolation,
      // so we have a valid token as long as we've seen a separator.
      // example: a/${x}
      return have_sep;
    } else {
      // we have a valid token if we've consumed anything after a separator.
      // example: a/b
      return have_after_sep;
    }

    advance(lexer);
  }
}

static bool scan_path_fragment(TSLexer *lexer) {
  lexer->result_symbol = PATH_FRAGMENT;

  for (bool has_content = false;; has_content = true) {
    lexer->mark_end(lexer);
    if (!is_path_char(lexer->lookahead)) {
      return has_content;
    }
    advance(lexer);
  }
}

static bool is_language_char(int32_t c) {
  return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
         (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '+';
}

// Scan the prefix of a line injection comment: "# "
// or block injection comment: "/* "
// Peeks ahead to verify this is a single-word comment before returning true.
static bool scan_injection_comment_prefix(TSLexer *lexer) {
  lexer->result_symbol = INJECTION_COMMENT_PREFIX;

  if (lexer->lookahead == '#') {
    advance(lexer);
    // Must have at least one space after #
    if (lexer->lookahead != ' ' && lexer->lookahead != '\t') {
      return false;
    }
    // Consume spaces/tabs after #
    while (lexer->lookahead == ' ' || lexer->lookahead == '\t') {
      advance(lexer);
    }
    // Mark end here — the prefix is "# " (with trailing whitespace)
    lexer->mark_end(lexer);

    // Peek ahead: must start with a letter
    if (!((lexer->lookahead >= 'a' && lexer->lookahead <= 'z') ||
          (lexer->lookahead >= 'A' && lexer->lookahead <= 'Z'))) {
      return false;
    }
    // Read the word
    while (is_language_char(lexer->lookahead)) {
      advance(lexer);
    }
    // After the word, must be only whitespace until EOL or EOF
    while (lexer->lookahead == ' ' || lexer->lookahead == '\t') {
      advance(lexer);
    }
    if (lexer->lookahead != '\n' && lexer->lookahead != '\r' &&
        lexer->lookahead != '\0') {
      return false;
    }
    return true;
  }

  if (lexer->lookahead == '/') {
    advance(lexer);
    if (lexer->lookahead != '*') {
      return false;
    }
    advance(lexer);
    // Consume optional whitespace after /*
    while (lexer->lookahead == ' ' || lexer->lookahead == '\t') {
      advance(lexer);
    }
    // Mark end here — the prefix is "/* " (with trailing whitespace)
    lexer->mark_end(lexer);

    // Peek ahead: must start with a letter
    if (!((lexer->lookahead >= 'a' && lexer->lookahead <= 'z') ||
          (lexer->lookahead >= 'A' && lexer->lookahead <= 'Z'))) {
      return false;
    }
    // Read the word
    while (is_language_char(lexer->lookahead)) {
      advance(lexer);
    }
    // After the word, optional whitespace then must be */
    while (lexer->lookahead == ' ' || lexer->lookahead == '\t') {
      advance(lexer);
    }
    if (lexer->lookahead != '*') {
      return false;
    }
    advance(lexer);
    if (lexer->lookahead != '/') {
      return false;
    }
    return true;
  }

  return false;
}

// Scan the language word (e.g., "bash", "python").
// Called after the prefix has been consumed.
static bool scan_injection_language(TSLexer *lexer) {
  lexer->result_symbol = INJECTION_LANGUAGE;

  if (!((lexer->lookahead >= 'a' && lexer->lookahead <= 'z') ||
        (lexer->lookahead >= 'A' && lexer->lookahead <= 'Z'))) {
    return false;
  }

  while (is_language_char(lexer->lookahead)) {
    advance(lexer);
  }
  lexer->mark_end(lexer);
  return true;
}

// Scan the suffix of an injection comment.
// For block comments: consumes trailing whitespace + "*/"
// For line comments: returns a zero-width token
static bool scan_injection_comment_suffix(TSLexer *lexer) {
  lexer->result_symbol = INJECTION_COMMENT_SUFFIX;
  lexer->mark_end(lexer); // zero-width fallback position

  // Try to consume whitespace + */
  while (lexer->lookahead == ' ' || lexer->lookahead == '\t') {
    advance(lexer);
  }
  if (lexer->lookahead == '*') {
    advance(lexer);
    if (lexer->lookahead == '/') {
      advance(lexer);
      lexer->mark_end(lexer);
      return true;
    }
    // No '/' after '*' — cursor resets to initial mark_end (zero-width)
  }
  // Line comment case: return zero-width token
  return true;
}

void *tree_sitter_nix_external_scanner_create() { return NULL; }

bool tree_sitter_nix_external_scanner_scan(void *payload, TSLexer *lexer,
                                           const bool *valid_symbols) {
  // This never happens in valid grammar. Only during error recovery, everything
  // becomes valid. See: https://github.com/tree-sitter/tree-sitter/issues/1259
  //
  // We should not consume any content as string fragment during error recovery,
  // or we'll break more valid grammar below. The test 'attrset typing field
  // following string' covers this.
  if (valid_symbols[STRING_FRAGMENT] &&
      valid_symbols[INDENTED_STRING_FRAGMENT] && valid_symbols[PATH_START] &&
      valid_symbols[PATH_FRAGMENT] && valid_symbols[DOLLAR_ESCAPE] &&
      valid_symbols[INDENTED_DOLLAR_ESCAPE] &&
      valid_symbols[INJECTION_COMMENT_PREFIX] &&
      valid_symbols[INJECTION_LANGUAGE] &&
      valid_symbols[INJECTION_COMMENT_SUFFIX]) {
    return false;
  }

  // Handle injection language (only valid immediately after prefix)
  if (valid_symbols[INJECTION_LANGUAGE] && !valid_symbols[STRING_FRAGMENT]) {
    return scan_injection_language(lexer);
  }

  // Handle injection comment suffix (only valid after language in block
  // comment)
  if (valid_symbols[INJECTION_COMMENT_SUFFIX] &&
      !valid_symbols[STRING_FRAGMENT]) {
    return scan_injection_comment_suffix(lexer);
  }

  // String fragments — always handle first when inside a string.
  if (valid_symbols[STRING_FRAGMENT]) {
    if (lexer->lookahead == '\\') {
      return scan_dollar_escape(lexer);
    }
    return scan_string_fragment(lexer);
  } else if (valid_symbols[INDENTED_STRING_FRAGMENT]) {
    if (lexer->lookahead == '\'') {
      lexer->mark_end(lexer);
      advance(lexer);
      if (lexer->lookahead == '\'') {
        return scan_indented_dollar_escape(lexer);
      }
    }
    return scan_indented_string_fragment(lexer);
  }

  // Path fragments must be immediate (no whitespace before). Check before
  // skipping whitespace.
  if (valid_symbols[PATH_FRAGMENT] && is_path_char(lexer->lookahead)) {
    // path_fragments should be scanned as immediate tokens, with no preceding
    // extras. so we assert that the very first token is a path character, and
    // otherwise we fall through to the case below. example:
    //   a/b${c} d/e${f}
    //          ^--- note that scanning for the path_fragment will start here.
    //               this *should* be parsed as a function application.
    //               so we want to fall through to the path_start case below,
    //               which will skip the whitespace and correctly scan the
    //               following path_start.
    //
    // also, we want this above path_start, because wherever there's ambiguity
    // we want to parse another fragment instead of starting a new path.
    // example:
    //   a/b${c}d/e${f}
    // if we swap the precedence, we'd effectively parse the above as the
    // following function application:
    //   (a/b${c}) (d/e${f})
    return scan_path_fragment(lexer);
  }

  // Skip whitespace for remaining dispatch (path_start, injection comments).
  while (lexer->lookahead == ' ' || lexer->lookahead == '\n' ||
         lexer->lookahead == '\r' || lexer->lookahead == '\t') {
    skip(lexer);
  }

  // '#' can only start a comment, never a path. Try injection first;
  // if it fails tree-sitter resets the lexer and the internal `comment`
  // token matches instead.
  if (lexer->lookahead == '#') {
    if (valid_symbols[INJECTION_COMMENT_PREFIX]) {
      return scan_injection_comment_prefix(lexer);
    }
    return false;
  }

  // '/' could be: /* block comment, /path, or / division operator.
  // Peek one character ahead to disambiguate.
  if (lexer->lookahead == '/') {
    advance(lexer);
    if (lexer->lookahead == '*') {
      // Block comment: /* ... */. Never a path.
      // Try block injection; if it fails the internal `comment` token matches.
      if (valid_symbols[INJECTION_COMMENT_PREFIX]) {
        advance(lexer); // consume '*'
        while (lexer->lookahead == ' ' || lexer->lookahead == '\t') {
          advance(lexer);
        }
        lexer->mark_end(lexer); // prefix ends after "/* "

        // Peek ahead: must be a single word then */
        if (!((lexer->lookahead >= 'a' && lexer->lookahead <= 'z') ||
              (lexer->lookahead >= 'A' && lexer->lookahead <= 'Z'))) {
          return false;
        }
        while (is_language_char(lexer->lookahead)) {
          advance(lexer);
        }
        while (lexer->lookahead == ' ' || lexer->lookahead == '\t') {
          advance(lexer);
        }
        if (lexer->lookahead != '*') {
          return false;
        }
        advance(lexer);
        if (lexer->lookahead != '/') {
          return false;
        }
        lexer->result_symbol = INJECTION_COMMENT_PREFIX;
        return true;
      }
      return false;
    }

    // Not /* — could be /path or / operator. We already consumed '/'.
    // Continue with inline path scanning (have_sep = true).
    if (valid_symbols[PATH_START]) {
      lexer->result_symbol = PATH_START;
      bool have_after_sep = false;
      while (true) {
        lexer->mark_end(lexer);
        int32_t c = lexer->lookahead;
        if (c == '/') {
          // additional separator
        } else if (is_path_char(c)) {
          have_after_sep = true;
        } else if (c == '$') {
          return true; // have separator (consumed above)
        } else {
          return have_after_sep;
        }
        advance(lexer);
      }
    }
    return false;
  }

  // All other first characters — try path_start (whitespace already skipped).
  if (valid_symbols[PATH_START]) {
    return scan_path_start(lexer);
  }

  return false;
}

unsigned tree_sitter_nix_external_scanner_serialize(void *payload,
                                                    char *buffer) {
  return 0;
}

void tree_sitter_nix_external_scanner_deserialize(void *payload,
                                                  const char *buffer,
                                                  unsigned length) {}

void tree_sitter_nix_external_scanner_destroy(void *payload) {}
