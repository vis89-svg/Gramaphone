import 'package:flutter/material.dart';

class Artwork extends StatelessWidget {
  final String url;
  final double size;
  final double borderRadius;

  const Artwork(this.url, {super.key, this.size = 40, this.borderRadius = 6});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF181E27),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Icon(Icons.music_note, color: const Color(0xFF727D8A), size: size * 0.5),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: const Color(0xFF181E27),
          child: Icon(Icons.music_note, color: const Color(0xFF727D8A), size: size * 0.5),
        ),
      ),
    );
  }
}
