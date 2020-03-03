// SPDX-License-Identifier: MIT

package graph

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/pkg/errors"
	"go.cryptoscope.co/ssb"
	"gonum.org/v1/gonum/graph"
	"gonum.org/v1/gonum/graph/encoding"
	"gonum.org/v1/gonum/graph/encoding/dot"
	"gonum.org/v1/gonum/graph/simple"
)

func (g *Graph) NodeCount() int {
	g.Mutex.Lock()
	defer g.Mutex.Unlock()
	return len(g.lookup)
}

func (g *Graph) RenderSVG(w io.Writer) error {
	g.Mutex.Lock()
	defer g.Mutex.Unlock()
	dotbytes, err := dot.Marshal(g, "trust", "", "")
	if err != nil {
		return errors.Wrap(err, "dot marshal failed")
	}
	dotR := bytes.NewReader(dotbytes)

	dotCmd := exec.Command("dot", "-Tsvg")
	dotCmd.Stdout = w
	dotCmd.Stdin = dotR
	// dotCmd.Stdin = io.TeeReader(dotR, dotFile)
	return errors.Wrap(dotCmd.Run(), "RenderSVG: dot command failed")
}

func (g *Graph) RenderSVGToFile(path string) error {
	os.Remove(path)
	os.MkdirAll(filepath.Dir(path), 0700)

	svgFile, err := os.Create(path)
	if err != nil {
		return errors.Wrap(err, "svg file create failed")
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
	feed *ssb.StorageRef
	name string
}

func (n contactNode) String() string {
	if n.name != "" {
		return n.name
	}
	return n.feed.ShortRef()
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
