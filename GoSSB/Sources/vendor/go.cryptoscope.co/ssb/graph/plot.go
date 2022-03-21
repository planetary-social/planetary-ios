// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package graph

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"

	refs "go.mindeco.de/ssb-refs"
	"gonum.org/v1/gonum/graph"
	"gonum.org/v1/gonum/graph/encoding"
	"gonum.org/v1/gonum/graph/encoding/dot"
	"gonum.org/v1/gonum/graph/simple"
)

func (g *Graph) NodeCount() int {
	g.Mutex.Lock()
	defer g.Mutex.Unlock()
	return g.WeightedDirectedGraph.Nodes().Len()
}

func (g *Graph) RenderSVG(w io.Writer) error {
	g.Mutex.Lock()
	defer g.Mutex.Unlock()
	dotbytes, err := dot.Marshal(g, "trust", "", "")
	if err != nil {
		return fmt.Errorf("dot marshal failed: %w", err)
	}
	dotR := bytes.NewReader(dotbytes)

	dotFile, err := os.OpenFile("dot-dump.xml", os.O_RDWR|os.O_CREATE|os.O_TRUNC, 0700)
	if err != nil {
		return fmt.Errorf("dot dump open failed: %w", err)
	}
	defer dotFile.Close()

	dotCmd := exec.Command("dot", "-Tsvg")
	dotCmd.Stdout = w
	dotCmd.Stdin = dotR
	dotCmd.Stdin = io.TeeReader(dotR, dotFile)

	if err := dotCmd.Run(); err != nil {
		return fmt.Errorf("RenderSVG: dot command failed: %w", err)
	}
	return nil
}

func (g *Graph) RenderSVGToFile(path string) error {
	os.Remove(path)
	os.MkdirAll(filepath.Dir(path), 0700)

	svgFile, err := os.Create(path)
	if err != nil {
		return fmt.Errorf("svg file create failed: %w", err)
	}
	defer svgFile.Close()
	return g.RenderSVG(svgFile)
}

// https://www.graphviz.org/doc/info/attrs.html
var (
	_ encoding.Attributer = (*contactNode)(nil)
	_ encoding.Attributer = (*contactEdge)(nil)
)

func (g *Graph) Attributes() []encoding.Attribute {
	return []encoding.Attribute{
		{Key: "rankdir", Value: "LR"},
	}
}

type contactNode struct {
	graph.Node
	feed refs.FeedRef
	name string
}

func (n contactNode) String() string {
	if n.name != "" {
		return n.name
	}
	return n.feed.ShortSigil()
}

func (n contactNode) Attributes() []encoding.Attribute {
	name := fmt.Sprintf("%q", n.String())
	if n.name != "" {
		name = n.name
	}
	return []encoding.Attribute{
		{Key: "label", Value: name},
	}
}

type contactEdge struct {
	simple.WeightedEdge
	isBlock bool
}

func (n contactEdge) Attributes() []encoding.Attribute {
	c := "black"
	if n.W > 1 {
		c = "firebrick1"
	}
	return []encoding.Attribute{
		{Key: "color", Value: c},
		// {Key: "label", Value: fmt.Sprintf(`"%f"`, n.W)},
	}
}

type metafeedEdge struct {
	simple.WeightedEdge
}

func (n metafeedEdge) Attributes() []encoding.Attribute {
	c := "green"
	return []encoding.Attribute{
		{Key: "color", Value: c},
		// {Key: "label", Value: fmt.Sprintf(`"%f"`, n.W)},
	}
}
