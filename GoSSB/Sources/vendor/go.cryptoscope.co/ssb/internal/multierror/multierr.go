// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

package multierror

import (
	"fmt"
	"strings"
)

// List contains a list of errors
type List struct{ Errs []error }

func (el List) Error() string {
	var str strings.Builder

	if n := len(el.Errs); n > 0 {
		fmt.Fprintf(&str, "multiple errors(%d): ", n)
	}
	for i, err := range el.Errs {
		fmt.Fprintf(&str, "(%d): ", i)
		str.WriteString(err.Error() + " - ")
	}

	return str.String()
}
