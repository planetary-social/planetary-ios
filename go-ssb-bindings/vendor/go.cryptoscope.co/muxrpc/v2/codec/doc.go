// SPDX-License-Identifier: MIT

/*
Package codec implements readers and writers for https://github.com/dominictarr/packet-stream-codec

Packet structure:

	(
		[flags (1byte), length (4 bytes, UInt32BE), req (4 bytes, Int32BE)] # Header
		[body (length bytes)]
	) *
	[zeros (9 bytes)]

Flags:

	[ignored (4 bits), stream (1 bit), end/err (1 bit), type (2 bits)]
	type = {0 => Buffer, 1 => String, 2 => JSON} # PacketType
*/
package codec
