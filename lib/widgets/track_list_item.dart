import 'package:flutter/material.dart';

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
                image: coverUrl != null
                    ? DecorationImage(
                        image: NetworkImage(coverUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: Colors.grey[800],
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
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
                        color: Colors.grey[600],
                      ),
                    )
                  : null,
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
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}