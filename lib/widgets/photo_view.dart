import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Shows a report photo from a local file (mobile) or blob URL (web).
class PhotoView extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final double radius;

  const PhotoView({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext context, Object error, StackTrace? stack) {
      return Container(
        width: width,
        height: height,
        color: AppColors.surfaceMuted,
        alignment: Alignment.center,
        child: const Icon(
          Icons.broken_image_outlined,
          color: AppColors.textMuted,
        ),
      );
    }

    final image = kIsWeb
        ? Image.network(
            path,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: fallback,
          )
        : Image.file(
            File(path),
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: fallback,
          );

    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
  }
}
