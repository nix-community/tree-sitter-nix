package main

import (
	"context"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/charmbracelet/log"
	nix "github.com/nix-community/tree-sitter-nix/bindings/go"
	"github.com/olekukonko/tablewriter"
	ts "github.com/smacker/go-tree-sitter"
)

type FlakeInput struct {
	URL    string
	Extras map[string]string
}

func findFlakeInputs(node *ts.Node, source []byte) map[string]FlakeInput {
	inputs := make(map[string]FlakeInput)
	log.Debug("Starting extractFlakeInputs")

	inputsNode := findInputsNode(node, source)
	if inputsNode == nil {
		log.Warn("No inputs node found")
		return inputs
	}

	log.Debug("Found inputs node", "type", inputsNode.Type())
	processInputs(inputsNode, source, inputs)
	return inputs
}

func findInputsNode(node *ts.Node, source []byte) *ts.Node {
	log.Debug("Starting findInputsNode", "node_type", node.Type())

	var findInputs func(*ts.Node) *ts.Node
	findInputs = func(n *ts.Node) *ts.Node {
		log.Debug("Examining node", "type", n.Type(), "content", n.Content(source))

		if n.Type() == "binding" {
			attrPath := n.ChildByFieldName("attrpath")
			if attrPath != nil && attrPath.Content(source) == "inputs" {
				log.Info("Found inputs node")
				return n.ChildByFieldName("expression")
			}
		}

		for i := 0; i < int(n.NamedChildCount()); i++ {
			child := n.NamedChild(i)
			if result := findInputs(child); result != nil {
				return result
			}
		}

		return nil
	}

	return findInputs(node)
}

func processInputs(node *ts.Node, source []byte, inputs map[string]FlakeInput) {
	log.Debug("Processing inputs", "node_type", node.Type())

	if node.Type() != "attrset_expression" {
		log.Warn("Expected attrset_expression for inputs", "actual_type", node.Type())
		return
	}

	for i := 0; i < int(node.NamedChildCount()); i++ {
		child := node.NamedChild(i)
		log.Debug("Examining child of attrset_expression", "type", child.Type())

		if child.Type() == "binding_set" {
			processBindingSet(child, source, inputs)
		}
	}
}

func processBindingSet(node *ts.Node, source []byte, inputs map[string]FlakeInput) {
	log.Debug("Processing binding set", "node_type", node.Type())

	for i := 0; i < int(node.NamedChildCount()); i++ {
		child := node.NamedChild(i)
		if child.Type() == "binding" {
			processBinding(child, source, inputs)
		}
	}
}

func processBinding(node *ts.Node, source []byte, inputs map[string]FlakeInput) {
	attrPath := node.ChildByFieldName("attrpath")
	expression := node.ChildByFieldName("expression")

	if attrPath == nil || expression == nil {
		log.Warn("Invalid binding node", "attrpath", attrPath != nil, "expression", expression != nil)
		return
	}

	name := attrPath.Content(source)
	log.Debug("Processing binding", "name", name, "expression_type", expression.Type())

	input := FlakeInput{Extras: make(map[string]string)}

	if expression.Type() == "string_expression" {
		input.URL = trimQuotes(expression.Content(source))
		log.Debug("Found URL", "name", name, "url", input.URL)
	} else if expression.Type() == "attrset_expression" {
		processInputAttrs(expression, source, &input)
	}

	inputs[name] = input
	log.Info("Added input", "name", name, "input", input)
}

func processInputAttrs(node *ts.Node, source []byte, input *FlakeInput) {
	log.Debug("Processing input attributes", "node_type", node.Type())

	for i := 0; i < int(node.NamedChildCount()); i++ {
		child := node.NamedChild(i)
		if child.Type() == "binding_set" {
			for j := 0; j < int(child.NamedChildCount()); j++ {
				binding := child.NamedChild(j)
				if binding.Type() == "binding" {
					key := binding.ChildByFieldName("attrpath")
					value := binding.ChildByFieldName("expression")
					if key == nil || value == nil {
						log.Warn("Invalid attribute binding", "key", key != nil, "value", value != nil)
						continue
					}

					keyStr := key.Content(source)
					log.Debug("Processing attribute", "key", keyStr, "value_type", value.Type())

					if keyStr == "url" {
						input.URL = trimQuotes(value.Content(source))
						log.Debug("Found URL in attributes", "url", input.URL)
					} else {
						valueStr := trimQuotes(value.Content(source))
						if value.Type() == "attrset_expression" {
							// Handle nested attribute set
							processNestedAttrs(value, source, input, keyStr)
						} else {
							input.Extras[keyStr] = valueStr
						}
						log.Debug("Added attribute", "key", keyStr, "value", valueStr)
					}
				}
			}
		}
	}
}

func processNestedAttrs(node *ts.Node, source []byte, input *FlakeInput, prefix string) {
	for i := 0; i < int(node.NamedChildCount()); i++ {
		child := node.NamedChild(i)
		if child.Type() == "binding_set" {
			for j := 0; j < int(child.NamedChildCount()); j++ {
				binding := child.NamedChild(j)
				if binding.Type() == "binding" {
					key := binding.ChildByFieldName("attrpath")
					value := binding.ChildByFieldName("expression")
					if key == nil || value == nil {
						continue
					}

					keyStr := key.Content(source)
					valueStr := trimQuotes(value.Content(source))
					fullKey := prefix + "." + keyStr
					input.Extras[fullKey] = valueStr
				}
			}
		}
	}
}

func trimQuotes(s string) string {
	return strings.Trim(s, "\"")
}

func formatFollowsInput(extras map[string]string) string {
	var followsInfo []string

	for key, value := range extras {
		parts := strings.Split(key, ".")
		if len(parts) > 1 && parts[len(parts)-1] == "follows" {
			followsInfo = append(followsInfo, fmt.Sprintf("%s -> %s", parts[len(parts)-2], value))
		}
	}

	return strings.Join(followsInfo, ", ")
}

func main() {
	// Set up logging
	log.SetLevel(log.InfoLevel)
	log.SetReportCaller(false)
	log.SetReportTimestamp(true)

	if len(os.Args) < 2 {
		log.Fatal("Please provide a flake.nix file path as an argument.")
	}

	code, err := os.ReadFile(os.Args[1])
	if err != nil {
		log.Fatal("Error reading file", "error", err)
	}

	parser := ts.NewParser()
	defer parser.Close()
	parser.SetLanguage(ts.NewLanguage(nix.Language()))

	// Create a context with a timeout
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	tree, err := parser.ParseCtx(ctx, nil, code)
	if err != nil {
		log.Fatal("Error parsing file", "error", err)
	}
	defer tree.Close()

	inputs := findFlakeInputs(tree.RootNode(), code)
	log.Info("inputs found", "count", len(inputs))

	// Create and configure the table
	table := tablewriter.NewWriter(os.Stdout)
	table.SetHeader([]string{"Input", "URL", "Extras"})
	table.SetBorders(tablewriter.Border{Left: true, Top: false, Right: true, Bottom: false})
	table.SetCenterSeparator("|")
	table.SetAutoWrapText(false)

	// Add data to the table
	for name, input := range inputs {
		follows := formatFollowsInput(input.Extras)
		table.Append([]string{name, input.URL, follows})
		log.Info("input details", "name", name, "url", input.URL, "follows", follows)
	}

	table.Render()
}
