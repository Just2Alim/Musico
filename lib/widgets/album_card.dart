import 'package:flutter/material.dart';

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album cover
            Container(
              height: 160,
              width: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(imageUrl!),
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
              child: imageUrl == null
                  ? Center(
                      child: Icon(
                        Icons.album,
                        size: 60,
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
            if (subtitle != null)
              Text(
                subtitle!,
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