class_name SyncPolicy
extends RefCounted
## Decides how a save slot is synced. Never loses a career: the newest valid
## save wins (more seasons, then later save, then higher revision), and the
## other copy is kept as a backup on both sides (local SaveSlots backup file,
## server backup_envelope column).

const UPLOAD := "upload"
const DOWNLOAD := "download"
const NOTHING := "nothing"


## `local`/`remote` are null when missing or invalid (callers validate first).
static func decide(local: SaveEnvelope, remote: SaveEnvelope) -> String:
	if local == null and remote == null:
		return NOTHING
	if remote == null:
		return UPLOAD
	if local == null:
		return DOWNLOAD
	if local.checksum == remote.checksum:
		return NOTHING
	return DOWNLOAD if SaveSlots.is_newer(remote, local) else UPLOAD
