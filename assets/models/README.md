# On-Device Model Assets Guide

Place your converted TensorFlow Lite model in this directory:

- **Model path**: `assets/models/wikiart_model.tflite`
- **Labels path**: `assets/models/labels.txt`

## Converting PyTorch / Hugging Face model (`prithivMLmods/WikiArt-Style`) to TFLite:
1. Export model to ONNX using `optimum-cli` or `torch.onnx.export`
2. Convert ONNX to TensorFlow saved model using `onnx2tf` or `onnx-tensorflow`
3. Convert TensorFlow saved model to TFLite using `tf.lite.TFLiteConverter.from_saved_model()`
4. Place `wikiart_model.tflite` here!
