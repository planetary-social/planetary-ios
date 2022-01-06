// SPDX-License-Identifier: MIT

package legacy

import (
	"bytes"
	"fmt"
	"io"
	"regexp"
	"unicode/utf8"

	"github.com/pkg/errors"
	"golang.org/x/text/encoding/unicode"
	"golang.org/x/text/transform"
)

var signatureRegexp = regexp.MustCompile(",\n  \"signature\": \"([A-Za-z0-9/+=.]+)\"")

func unicodeEscapeSome(s string) string {
	var b bytes.Buffer
	for i, r := range s {
		// https://spec.scuttlebutt.nz/feed/datamodel.html#signing-encoding-strings
		// the rest is already handled by %q in encode.go
		if r == 0x000008 {
			// (backspace) \b
			b.Write([]byte{0x5C, 0x62})
		} else if r == 0x00000C {
			// (form feed) \f
			b.Write([]byte{0x5C, 0x66})
		} else if r < 0x20 {
			// TODO: width for multibyte chars
			runeValue, _ := utf8.DecodeRuneInString(s[i:])
			fmt.Fprintf(&b, "\\u%04x", runeValue)
		} else {
			fmt.Fprintf(&b, "%c", r)
		}
	}
	return b.String()
}

// InternalV8Binary does some funky v8 magic
// new Buffer(in, "binary") returns soemthing like (u16 && 0xff)
func InternalV8Binary(in []byte) ([]byte, error) {
	var u16 bytes.Buffer
	enc := unicode.UTF16(unicode.LittleEndian, unicode.IgnoreBOM).NewEncoder()
	trans := transform.NewWriter(&u16, enc)
	if _, err := io.Copy(trans, bytes.NewReader(in)); err != nil {
		return nil, errors.Wrap(err, "internalV8bin: failed to transform input to u16")
	}
	// now drop every 2nd byte
	u16b := u16.Bytes()
	if len(u16b)%2 != 0 {
		return nil, errors.Errorf("internalV8bin: assumed even number of bytes in u16")
	}
	j := 0
	z := make([]byte, len(u16b)/2)
	for k := 0; k < len(u16b); k += 2 {
		z[j] = u16b[k]
		j++
	}
	return z, nil
}
