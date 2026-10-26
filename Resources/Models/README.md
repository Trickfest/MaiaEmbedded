# Local model resources

`maia3-79m.json` identifies the exact source, checkpoint, conversion and runtime.
`Scripts/download-model.sh` downloads the 316 MB ONNX file into this directory
and verifies its byte count and SHA-256. Weights remain ignored by Git.

No download occurs during inference. The experiment app bundles this local file;
run the helper before its Xcode build. Source/checkpoint provenance and reference
reproduction are in [Provenance](../../Docs/Provenance.md).
