# LanShare 1GB File Transfer Spec

## Summary
Add generic file sending as a new message type using a two-step flow:

1. Browser uploads the file over HTTP to the server
2. After upload completes, the browser sends a WebSocket `file` message containing only file metadata

This keeps large payloads out of WebSocket history, supports up to `1GB` per file, and matches the current room-based architecture. Files are stored under a server-side upload directory, configurable via app config, defaulting to `var/uploads/`.

## Implementation Changes
### File storage and indexing
- Add a `LanShare.FileStore` process under the application supervisor.
- `FileStore` manages:
  - upload root resolution from config, default `var/uploads`
  - directory creation on boot
  - opaque file ID generation
  - in-memory metadata index for files created during the current process lifetime
  - lookup by file ID
  - cleanup of partial uploads on failure
- Store files on disk as opaque IDs, not original filenames.
- Keep original filename only in metadata and chat display.
- Ignore pre-existing files in `var/uploads` on startup in v1; only files indexed in the current process are downloadable.

### HTTP interfaces
- Extend parser/body limits to support `1GB` uploads.
- Add `POST /upload/file`
  - accepts `multipart/form-data` with fields `file` and `room`
  - validates room code and max size
  - rejects early when disk space is insufficient
  - persists the uploaded temp file into `var/uploads/<room>/<id>`
  - returns JSON:
    - `id`
    - `filename`
    - `size`
    - `content_type`
    - `room_code`
    - `download_url`
- Add `GET /files/:id?room=AB12`
  - verifies the requested room matches the stored file room
  - streams the file as an attachment
  - returns `404` for unknown/missing files and `400/403` for invalid room access
- Do not expose raw filesystem paths in API responses.

### WebSocket and message model
- Add a new message type `file`.
- Broadcast only after HTTP upload completes successfully.
- File message payload includes:
  - `type`
  - `id`
  - `filename`
  - `size`
  - `content_type`
  - `download_url`
  - `sender`
  - `timestamp`
  - `room_code`
- `MessageStore` keeps file messages in the same `recent 100 messages` history budget as text and image messages.
- File messages persist only as metadata in memory; no binary content is stored in message history.

### Frontend UX
- Add a dedicated file picker/send flow separate from current image sending.
- Keep image sending on the current inline path for v1.
- On file send:
  - user selects file
  - client uploads via `fetch('/upload/file')`
  - on success, client sends WebSocket `file` message
- During upload:
  - show local uploading state
  - block duplicate sends for the same selected file
- If upload is interrupted or the browser backgrounds and the upload fails:
  - mark the send as failed
  - allow retry from scratch
- Render file messages as cards showing:
  - filename
  - size
  - sender
  - time
  - explicit download button
- Do not make the entire card clickable.
- If a historical file message points to a missing file after restart, keep the message visible and surface the error only when the user tries to download.

## Public Interfaces
- `POST /upload/file`
  - request: multipart `file`, `room`
  - response: file metadata JSON
- `GET /files/:id?room=AB12`
  - response: attachment stream
- WebSocket `file` message
  - emitted only after successful upload
  - no checksum in UI or API in v1

## Test Plan
- Upload route accepts valid file + room and returns metadata.
- Upload route rejects:
  - missing file
  - invalid room
  - oversized file
  - insufficient disk space
- Partial uploads are cleaned up on failure/interruption.
- Download route:
  - succeeds for matching room
  - rejects wrong room
  - returns missing-file errors correctly
- File messages:
  - broadcast only after upload success
  - appear in history for late joiners
  - consume the normal 100-message history budget
- Frontend acceptance:
  - uploading state renders correctly
  - duplicate click/select is blocked while upload is in flight
  - failed uploads can retry
  - download button works
  - existing text/image behavior does not regress

## Assumptions
- Single-file limit is `1GB`; there is no v1 global quota.
- Access model is room-scoped, not session-authenticated.
- Filenames are preserved exactly for display/download, but sanitized for safety and never used as on-disk storage keys.
- Upload directory is configurable, with `var/uploads` as the default.
- No resumable uploads, chunking, preview, hashing UI, or startup index rebuild in v1.
