class_name Variety
extends RefCounted
## Deterministic "variety" numbers for staging moments (free-kick position,
## where an opponent shoots). The same inputs always give the same value, so
## a moment is identical on every replay; outcomes still depend only on input.

const MASK_32 := 0xFFFFFFFF


## A value in [0, 1) derived from the given integers by a 32-bit integer hash.
static func unit(a: int, b: int, salt: int) -> float:
	var h := _mix(a * 73856093 ^ b * 19349663 ^ salt * 83492791)
	return float(h) / float(MASK_32 + 1)


## Integer finalizer (from MurmurHash3's fmix32), kept within 32 bits so the
## result is identical on every platform.
static func _mix(value: int) -> int:
	var h := value & MASK_32
	h ^= h >> 16
	h = (h * 0x85EBCA6B) & MASK_32
	h ^= h >> 13
	h = (h * 0xC2B2AE35) & MASK_32
	h ^= h >> 16
	return h
