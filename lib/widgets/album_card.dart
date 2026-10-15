import 'package:flutter/material.dart';
import '../themes/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AlbumCard extends StatelessWidget {
  final int id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final VoidCallback onTap;

  const AlbumCard({
    Key? key,
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cover = AspectRatio(aspectRatio: 1, child: _buildCover());
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (constraints.hasBoundedHeight)
                  Flexible(child: cover)
                else
                  cover,
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(color: AppTheme.mutedText, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCover() => Container(
    width: 160,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: AppTheme.elevatedSurface,
      boxShadow: [
        BoxShadow(
          color: AppTheme.canvas.withValues(alpha: 0.3),
          offset: const Offset(0, 3),
          blurRadius: 8,
        ),
      ],
    ),
    child: imageUrl == null
        ? Center(child: Icon(Icons.album, size: 60, color: AppTheme.mutedText))
        : ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (_, __, ___) => const Icon(Icons.album),
            ),
          ),
  );
}
