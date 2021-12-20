package tfk

// value is the basic type-format-key value holder.
// Since it doesn't know about valid type and format values or key length,
// it supposed to be embedded in concrete types that doe these checks afterwards.
type value struct {
	tipe   uint8
	format uint8
	key    []byte

	broken bool
}

func (v *value) MarshalBinary() (data []byte, err error) {
	var d = []byte{v.tipe, v.format}
	return append(d, v.key...), nil
}

func (v *value) UnmarshalBinary(data []byte) error {
	v.broken = false
	if len(data) < 2 {
		return ErrTooShort
	}

	v.tipe = data[0]
	v.format = data[1]

	if len(data) == 2 {
		return nil
	}

	v.key = make([]byte, len(data)-2)
	copy(v.key, data[2:])

	return nil
}
