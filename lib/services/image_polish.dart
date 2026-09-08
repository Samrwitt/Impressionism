import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Light cleanup for on-screen display. Classification still uses the original bytes.
Uint8List polishForDisplay(Uint8List bytes) {
  var image = img.decodeImage(bytes);
  if (image == null) return bytes;

  image = img.bakeOrientation(image);

  const maxSide = 1280;
  if (image.width > maxSide || image.height > maxSide) {
    image = img.copyResize(
      image,
      width: image.width >= image.height ? maxSide : null,
      height: image.height > image.width ? maxSide : null,
      interpolation: img.Interpolation.linear,
    );
  }

  // Mild contrast only — skip heavy color math for speed.
  image = img.adjustColor(image, contrast: 1.08);

  return Uint8List.fromList(img.encodeJpg(image, quality: 82));
}
