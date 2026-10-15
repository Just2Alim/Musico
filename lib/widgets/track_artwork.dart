import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Uses supplied licensed artwork or a distinct Musico cover for rows without it.
class TrackArtwork extends StatelessWidget {
  const TrackArtwork({
    super.key,
    required this.title,
    required this.artist,
    this.imageUrl,
    this.borderRadius = 12,
    this.showLabel = true,
  });

  final String title;
  final String artist;
  final String? imageUrl;
  final double borderRadius;
  final bool showLabel;

  static const _palettes = <List<Color>>[
    [Color(0xFF184E5A), Color(0xFF101B2C)],
    [Color(0xFF5A3028), Color(0xFF24162A)],
    [Color(0xFF5C4B22), Color(0xFF1C302C)],
    [Color(0xFF394C71), Color(0xFF251A40)],
    [Color(0xFF6B3A56), Color(0xFF271C35)],
    [Color(0xFF315D45), Color(0xFF132A35)],
    [Color(0xFF5A3D26), Color(0xFF251D2F)],
  ];

  int get _paletteIndex =>
      title.codeUnits.fold<int>(0, (total, unit) => total + unit) %
      _palettes.length;

  bool get _hasSecureImage {
    final uri = imageUrl == null ? null : Uri.tryParse(imageUrl!);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: _hasSecureImage
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => _fallback(),
              errorWidget: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() {
    final colors = _palettes[_paletteIndex];
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide.isFinite
            ? constraints.biggest.shortestSide
            : 160.0;
        return SizedBox.expand(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  right: -side * 0.18,
                  top: -side * 0.24,
                  child: Container(
                    width: side * 0.82,
                    height: side * 0.82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.17),
                        width: side * 0.045,
                      ),
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.16),
                          Colors.white.withValues(alpha: 0.015),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: side * 0.11,
                  top: side * 0.12,
                  child: Icon(
                    Icons.graphic_eq_rounded,
                    size: side * 0.23,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                if (showLabel)
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(side * 0.1),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.52),
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: (side * 0.105).clamp(11.0, 20.0),
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                          if (side >= 105) ...[
                            const SizedBox(height: 4),
                            Text(
                              artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.76),
                                fontSize: (side * 0.065).clamp(10.0, 13.0),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
