import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class PhotoStorage {
  static final _picker = ImagePicker();

  /// Lets the user take or choose a photo and returns a path that stays
  /// valid after the app restarts (on web: a session-only blob URL).
  static Future<String?> pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 75,
    );
    if (file == null) return null;
    if (kIsWeb) return file.path;

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/report_photos');
    if (!await dir.exists()) await dir.create(recursive: true);
    final dot = file.name.lastIndexOf('.');
    final ext = dot == -1 ? '.jpg' : file.name.substring(dot);
    final target = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}$ext';
    await file.saveTo(target);
    return target;
  }
}
