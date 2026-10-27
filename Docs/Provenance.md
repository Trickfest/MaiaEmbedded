# Provenance and model assets

## Experiment inputs

The exact source/checkpoint/export identities, byte counts and SHA-256 values
are recorded in [the model manifest](../Resources/Models/maia3-79m.json).

- **CSSLab Maia-3 source:** revision `1e13597c42d4858b7cfd7cfdae01e297263364b2`
  of https://github.com/CSSLab/maia3. Its tokenizer, history padding, move
  vocabulary and Black mirroring define the adapted Swift encoding. Preserve
  [its AGPL license](../ThirdParty/Maia3/LICENSE).
- **Original 79M checkpoint:** revision `a107d6ceb7b298cb04ae1da4edffe2939858b894`
  of https://huggingface.co/UofTCSSLab/Maia3-79M, file `maia3-79m.pt`,
  315,651,851 bytes. AGPL-3.0 upstream checkpoint.
- **ONNX conversion:** `assets/models/maia3-79m.onnx` from Mobile Maia revision
  `5f6743eed5491d2e8413fe0dfd1f8ef612d0aa84`. This FP32 export was made with
  PyTorch 2.2.2, opset 17, IR 8, and contains 316,034,244 bytes. The conversion
  retains Maia's license. See that revision's MODEL_PROVENANCE.md and
  `tool/export_maia3_onnx.py` for original export reproduction. We download the
  pinned export rather than asserting our newer reference toolchain recreates
  byte-identical ONNX files.
- **Apple runtime:** Microsoft's official onnxruntime-swift-package-manager
  1.24.2, source commit `b7fb7f7dea8a2469e6335d95a61b8f36d0dc83b2`. SwiftPM
  verifies its declared binary archive checksum. The upstream manifest also
  resolves an extensions archive; the experiment links only the core runtime
  product, not the extensions product. [MIT license](../ThirdParty/ONNXRuntime/LICENSE).
- **ChessCore:** the public SwiftChessTools package, minimum version 1.4.0,
  under its MIT license. No sources are copied or changed. Record its resolved
  commit with validation evidence. The original experiment used the equivalent
  sibling checkout at the recorded commit; that history remains in its reports.

## Independent output verification

`Tools/generate_reference.py` imports the pinned upstream code and loads the
original checkpoint through upstream's weights-only PyTorch loading. It emits
20 deterministic position/rating/history cases with input byte hashes, legal
move sets, terminal flags, raw legal move/value logits and probabilities.
It also compares every ONNX output head against the original PyTorch model.
The reference environment is Python 3.13, PyTorch 2.9.1, numpy 2.2.6, Python
ONNX Runtime 1.24.2 and python-chess 1.999; all installed versions are locked in
`Tools/requirements-reference.txt`. It runs on the Mac only, never inside an app.
The generated JSON records tool versions and measured cross-runtime error.
This verifies the conversion's inference outputs; it is not a training-quality
or playing-strength study.

## Asset management

Downloaded models/checkpoints live in ignored local paths. Model provisioning
uses temporary files followed by byte-count/SHA-256 verification and atomic
replacement. The runtime verifies the model again before opening it. No model
is fetched during inference. The example app bundles the verified local export;
its build therefore requires `Scripts/download-model.sh` first. Never commit
weights, signing credentials, personal team IDs or device identifiers.

This is independent work, not an official Maia/CSSLab or Mobile Maia release.
