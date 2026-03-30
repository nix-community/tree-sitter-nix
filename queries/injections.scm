; mark arbitary languages with a comment
((((comment) @injection.language) .
  (indented_string_expression (string_fragment) @injection.content))
  (#set! injection.combined))

((binding
   attrpath: (attrpath (identifier) @_path)
   expression: (indented_string_expression
     (string_fragment) @injection.content))
 (#match? @_path "(^\\w*Phase|(pre|post)\\w*|(.*\\.)?\\w*([sS]cript|[hH]ook)|(.*\\.)?startup)$")
 (#set! injection.language "bash")
 (#set! injection.combined))

((apply_expression
   function: (apply_expression function: (_) @_func)
   argument: (indented_string_expression (string_fragment) @injection.content))
 (#match? @_func "(^|\\.)writeShellScript(Bin)?$")
 (#set! injection.language "bash")
 (#set! injection.combined))

(apply_expression
  (apply_expression
    function: (apply_expression
      function: ((_) @_func)))
    argument: (indented_string_expression (string_fragment) @injection.content)
  (#match? @_func "(^|\\.)runCommand(((No)?(CC))?(Local)?)?$")
  (#set! injection.language "bash")
  (#set! injection.combined))

(apply_expression
  function: ((_) @_func)
  argument: (_ (_)* (_ (_)* (binding
    attrpath: (attrpath (identifier) @_path)
     expression: (indented_string_expression
       (string_fragment) @injection.content))))
  (#match? @_func "(^|\\.)writeShellApplication$")
  (#match? @_path "^text$")
  (#set! injection.language "bash")
  (#set! injection.combined))

; @generated-start filename-injections
; Filename-based injection: detect language from file extension in
; curried calls like writeText "file.html" content.
; Source of truth: queries/filename-injections.nix
; Regenerate with: nix run .#generate-filename-injections

((apply_expression
   function: (apply_expression
     argument: (string_expression (string_fragment) @_filename))
   argument: (indented_string_expression (string_fragment) @injection.content))
 (#match? @_filename "\\.(html|htm)$")
 (#set! injection.language "html")
 (#set! injection.combined))

((apply_expression
   function: (apply_expression
     argument: (string_expression (string_fragment) @_filename))
   argument: (indented_string_expression (string_fragment) @injection.content))
 (#match? @_filename "\\.(css)$")
 (#set! injection.language "css")
 (#set! injection.combined))

((apply_expression
   function: (apply_expression
     argument: (string_expression (string_fragment) @_filename))
   argument: (indented_string_expression (string_fragment) @injection.content))
 (#match? @_filename "\\.(js)$")
 (#set! injection.language "javascript")
 (#set! injection.combined))

((apply_expression
   function: (apply_expression
     argument: (string_expression (string_fragment) @_filename))
   argument: (indented_string_expression (string_fragment) @injection.content))
 (#match? @_filename "\\.(ts)$")
 (#set! injection.language "typescript")
 (#set! injection.combined))

((apply_expression
   function: (apply_expression
     argument: (string_expression (string_fragment) @_filename))
   argument: (indented_string_expression (string_fragment) @injection.content))
 (#match? @_filename "\\.(json)$")
 (#set! injection.language "json")
 (#set! injection.combined))

((apply_expression
   function: (apply_expression
     argument: (string_expression (string_fragment) @_filename))
   argument: (indented_string_expression (string_fragment) @injection.content))
 (#match? @_filename "\\.(yml|yaml)$")
 (#set! injection.language "yaml")
 (#set! injection.combined))

((apply_expression
   function: (apply_expression
     argument: (string_expression (string_fragment) @_filename))
   argument: (indented_string_expression (string_fragment) @injection.content))
 (#match? @_filename "\\.(toml)$")
 (#set! injection.language "toml")
 (#set! injection.combined))

((apply_expression
   function: (apply_expression
     argument: (string_expression (string_fragment) @_filename))
   argument: (indented_string_expression (string_fragment) @injection.content))
 (#match? @_filename "\\.(py)$")
 (#set! injection.language "python")
 (#set! injection.combined))

((apply_expression
   function: (apply_expression
     argument: (string_expression (string_fragment) @_filename))
   argument: (indented_string_expression (string_fragment) @injection.content))
 (#match? @_filename "\\.(lua)$")
 (#set! injection.language "lua")
 (#set! injection.combined))

((apply_expression
   function: (apply_expression
     argument: (string_expression (string_fragment) @_filename))
   argument: (indented_string_expression (string_fragment) @injection.content))
 (#match? @_filename "\\.(nix)$")
 (#set! injection.language "nix")
 (#set! injection.combined))
; @generated-end filename-injections
