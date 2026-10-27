# Updating Maia

Keep model/source/runtime updates separate and reviewable, like the other
embedded packages' upstream updates. No automatic upstream refresh occurs.

1. Record the intended CSSLab source, original checkpoint, export and runtime
   revisions. Read their current primary-source license/format changes.
2. Update the model manifest under `Resources/Models`, provisioning URL/hash/size,
   runtime dependency pin and retained third-party notices together. Preserve
   reproducible export/reference tooling identities and avoid committing weights.
3. Compare encoding, history orientation/padding, vocabulary, tensor shapes,
   value-head order and sampling conventions to the pinned upstream. Do not
   silently accept a new model because it has the same filename.
4. Regenerate independent PyTorch/ONNX reference fixtures with
   `Scripts/prepare-reference.sh`; update its pins/tools deliberately. This script
   reproduces the checked-in fixtures for the current baseline, not byte-identical
   ONNX exports from a different PyTorch version.
5. Run `Scripts/validate.sh`, repeat consumer tests and benchmark changed precision,
   execution provider, thread count or runtime behavior. Repeat physical
   iPhone/iPad correctness, memory/performance and lifecycle acceptance for material
   inference/ownership changes.
6. Update README, API/architecture/testing/provenance docs, DocC and CHANGELOG under
   Unreleased. Compare public API changes against the most recent compatible
   release and bump the semantic version appropriately.
7. Remove obsolete ignored model files only after establishing the replacement.
   Check source archive/notices and clean checkout setup before an authorized release.

Keep source-only releases reproducible with pinned assets and retained notices.
GitHub-hosted checks remain optional/manual-only.
