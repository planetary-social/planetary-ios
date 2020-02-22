package secrethandshake

import (
	"errors"
	"unsafe" // ☢ ☣
)

// the idea here is that the memory backed by bool
// will be on byte and no other values than 0x00 and 0x01
func castBoolToInt(bptr *bool) int {
	uptr := unsafe.Pointer(bptr)
	bytePtr := (*byte)(uptr)

	return int(*bytePtr)
}

func testMemoryLayoutAssumption() error {
	var boolTrue, boolFalse bool
	boolTrue = true

	okTrue := castBoolToInt(&boolTrue)
	if okTrue != 1 {
		return errors.New("expected bool to int cast failed on true")
	}

	okFalse := castBoolToInt(&boolFalse)
	if okFalse != 0 {
		return errors.New("expected bool to int cast failed on false")
	}
	return nil
}
