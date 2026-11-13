# Cutout model

The app bundles `isnet-general-use.onnx` from the [rembg model release](https://github.com/danielgatis/rembg/releases/download/v0.0.0/isnet-general-use.onnx). The original IS-Net / DIS research and source are at [xuebinqin/DIS](https://github.com/xuebinqin/DIS). Inference uses Microsoft's [ONNX Runtime Swift package](https://github.com/microsoft/onnxruntime-swift-package-manager), version 1.24.2.

The model runs locally in the app after the user confirms a scan selection. Live camera object detection uses Apple Vision. The app falls back to Vision if the bundled model fails.

The 179 MB model is kept out of Git because GitHub rejects files over 100 MB. To use IS-Net after cloning the repository, run these commands from the repository root before building in Xcode:

```sh
mkdir -p Sticker/Sticker/Models
curl -fL --retry 3 https://github.com/danielgatis/rembg/releases/download/v0.0.0/isnet-general-use.onnx -o Sticker/Sticker/Models/isnet-general-use.onnx
shasum -a 256 Sticker/Sticker/Models/isnet-general-use.onnx
```

The expected SHA-256 is `60920e99c45464f2ba57bee2ad08c919a52bbf852739e96947fbb4358c0d964a`. If the file is absent, the app can still use its Apple Vision fallback.

Review the upstream model weight terms before distributing the app; rembg notes that model weights may have terms distinct from its own MIT license.
