package main

import (
	"context"
	"testing"

	nix "github.com/nix-community/tree-sitter-nix/bindings/go"
	ts "github.com/smacker/go-tree-sitter"
	"github.com/stretchr/testify/assert"
)

func TestFindFlakeInputs(t *testing.T) {
	tests := []struct {
		name     string
		code     string
		expected map[string]FlakeInput
	}{
		{
			name: "Valid flake structure without inputs",
			code: `
{
  description = "A test flake";
}`,
			expected: map[string]FlakeInput{},
		},
		{
			name: "Valid flake structure with inputs",
			code: `
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}`,
			expected: map[string]FlakeInput{
				"nixpkgs": {
					URL: "github:nixos/nixpkgs/nixos-unstable",
				},
				"home-manager": {
					URL: "github:nix-community/home-manager",
					Extras: map[string]string{
						"inputs.nixpkgs.follows": "nixpkgs",
					},
				},
			},
		},
		{
			name:     "Empty flake",
			code:     "{}",
			expected: map[string]FlakeInput{},
		},
		{
			name: "Inputs not at top level",
			code: `
{
  someAttr = {
    inputs = {};
  };
}`,
			expected: map[string]FlakeInput{},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			root := parseNixCode(tc.code)
			result := findFlakeInputs(root, []byte(tc.code))
			assert.Equal(t, len(tc.expected), len(result), "Number of inputs doesn't match expected")
			for name, expectedInput := range tc.expected {
				actualInput, exists := result[name]
				assert.True(t, exists, "Expected input %s not found", name)
				if exists {
					assert.Equal(t, expectedInput.URL, actualInput.URL, "URL for input %s doesn't match", name)
					assert.Equal(t, expectedInput.Extras, actualInput.Extras, "Extras for input %s don't match", name)
				}
			}
		})
	}
}

func parseNixCode(content string) *ts.Node {
	parser := ts.NewParser()
	parser.SetLanguage(ts.NewLanguage(nix.Language()))
	tree, err := parser.ParseCtx(context.TODO(), nil, []byte(content))
	if err != nil {
	}
	return tree.RootNode()
}
