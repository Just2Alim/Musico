import 'package:flutter/material.dart';
import '../themes/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TrackListItem extends StatelessWidget {
  final int id;
  final String title;
  final String artist;
  final String? coverUrl;
  final VoidCallback onTap;

  const TrackListItem({
    Key? key,
    required this.id,
    required this.title,
    required this.artist,
    this.coverUrl,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            Container(
              height: 120,
              width: 120,
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
              child: coverUrl == null
                  ? Center(
                      child: Icon(
                        Icons.music_note,
                        size: 40,
                        color: AppTheme.mutedText,
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: coverUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            const Center(child: CircularProgressIndicator()),
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.music_note),
                      ),
                    ),
            ),
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
            Text(
              artist,
              style: TextStyle(color: AppTheme.mutedText, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
