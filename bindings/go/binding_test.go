package tree_sitter_nix_test

import (
	"testing"

	tree_sitter "github.com/tree-sitter/go-tree-sitter"
	tree_sitter_nix "github.com/tree-sitter/tree-sitter-nix/bindings/go"
)

func TestCanLoadGrammar(t *testing.T) {
	language := tree_sitter.NewLanguage(tree_sitter_nix.Language())
	if language == nil {
		t.Errorf("Error loading Nix grammar")
	}
}
