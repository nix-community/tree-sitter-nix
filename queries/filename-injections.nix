# Filename-based language injection rules for nix indented strings.
#
# Detects the language of an indented string argument based on the file
# extension of a preceding filename argument in curried function calls:
#
#   pkgs.writeText "style.css" ''
#     body { margin: 0; }
#   ''
#
# To add a new language, append an entry to the list below.
# Then run: nix run .#generate-filename-injections
# Or: npm run generate

{ pkgs, lib }:

let
  languages = [
    { ext = "html|htm"; lang = "html"; }
    { ext = "css";      lang = "css"; }
    { ext = "js";       lang = "javascript"; }
    { ext = "ts";       lang = "typescript"; }
    { ext = "json";     lang = "json"; }
    { ext = "yml|yaml"; lang = "yaml"; }
    { ext = "toml";     lang = "toml"; }
    { ext = "py";       lang = "python"; }
    { ext = "lua";      lang = "lua"; }
    { ext = "nix";      lang = "nix"; }
  ];

  rules = pkgs.writeText "filename-injections.scm"
    (lib.concatMapStrings ({ ext, lang }: ''

      ((apply_expression
         function: (apply_expression
           argument: (string_expression (string_fragment) @_filename))
         argument: (indented_string_expression (string_fragment) @injection.content))
       (#match? @_filename "\\.(${ext})$")
       (#set! injection.language "${lang}")
       (#set! injection.combined))
    '') languages);

  # Script that splices the generated rules into queries/injections.scm.
  # Idempotent: replaces between @generated-start/@generated-end markers,
  # or appends if no markers exist.
  generate = pkgs.writeShellScriptBin "generate-filename-injections" ''
    set -euo pipefail
    FILE=queries/injections.scm
    BLOCK=$(${pkgs.coreutils}/bin/mktemp)
    trap 'rm -f "$BLOCK"' EXIT

    {
      echo '; @generated-start filename-injections'
      echo '; Filename-based injection: detect language from file extension in'
      echo '; curried calls like writeText "file.html" content.'
      echo '; Source of truth: queries/filename-injections.nix'
      echo '; Regenerate with: nix run .#generate-filename-injections'
      cat ${rules}
      echo '; @generated-end filename-injections'
    } > "$BLOCK"

    if ${pkgs.gnugrep}/bin/grep -q '@generated-start filename-injections' "$FILE"; then
      ${pkgs.gawk}/bin/awk -v blockfile="$BLOCK" '
        /@generated-start filename-injections/ {
          while ((getline line < blockfile) > 0) print line
          close(blockfile)
          skip = 1
          next
        }
        /@generated-end filename-injections/ { skip = 0; next }
        !skip { print }
      ' "$FILE" > "''${FILE}.tmp"
      mv "''${FILE}.tmp" "$FILE"
    else
      printf '\n' >> "$FILE"
      cat "$BLOCK" >> "$FILE"
    fi
  '';

in {
  inherit languages rules generate;
}
