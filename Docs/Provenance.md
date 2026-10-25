# Provenance and model assets

## Current contents

Only project-owned scaffolding and documentation are present. No Maia source,
checkpoint, ONNX export, ONNX Runtime binary, or Android app code is vendored.
The root LICENSE is the standard GNU Affero General Public License version 3
text retrieved from the official GNU site for project-owned AGPL-3.0-only code.

## References for the first experiment

- Maia-3: https://github.com/CSSLab/maia3
- Released models: https://huggingface.co/UofTCSSLab
- ONNX Runtime: https://github.com/microsoft/onnxruntime
- Mobile Maia reference: https://github.com/Dash1971/maia-chess-android

These are discovery references, not pinned dependencies or imported sources.
Before introducing any component, record its exact source commit/release,
license text/notices, checkpoint revision and filename, byte count and SHA-256,
exporter/toolchain versions, exported model hash/schema, and reproduction steps.
Keep upstream code changes explicit and separate from wrapper-owned code.

Model files are provisioned locally and ignored by Git. Future consumers may
bundle a verified model or manage one in app-owned storage. Model acquisition
and runtime loading should be separate; do not silently fetch models at runtime.
