# Third-party notices

## Maia-3

Project: https://github.com/CSSLab/maia3

Copyright: University of Toronto CSSLab contributors.

The Swift encoding, history padding, Black orientation and move-vocabulary
mapping are adaptations of the pinned upstream `maia3/dataset.py` and
`maia3/utils.py`. Upstream source and the 79M checkpoint use GNU Affero General
Public License version 3. Preserve [the upstream license](ThirdParty/Maia3/LICENSE).
Project-owned Swift adaptations are AGPL-3.0-only.

## Mobile Maia ONNX export

Project: https://github.com/Dash1971/maia-chess-android

The separately downloaded model is the pinned Maia-3 79M ONNX conversion from
Mobile Maia, retaining Maia's AGPL terms. No Flutter UI or Android bridge code
is incorporated. Conversion/source/checkpoint identities and reproduction
references are in [Provenance](Docs/Provenance.md).

## ONNX Runtime

Project: https://github.com/microsoft/onnxruntime

Apple integration: https://github.com/microsoft/onnxruntime-swift-package-manager

Copyright (c) Microsoft Corporation. Licensed under MIT; retain
[the package license](ThirdParty/ONNXRuntime/LICENSE). The official SwiftPM
package fetches and verifies its runtime binary archive. Runtime artifacts
remain under ignored build directories, not vendored in this repository.

## ChessCore / SwiftChessTools

Project: https://github.com/Trickfest/SwiftChessTools

The local sibling dependency supplies chess rules and validated replay. Preserve
its MIT LICENSE and NOTICE.md, including its upstream attribution, in any source
or binary distribution as applicable. It remains a separate repository.

Model weights and runtime binaries are not committed. Full application
publication/distribution compliance is separate from this private experiment.
