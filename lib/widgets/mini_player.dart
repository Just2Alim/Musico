import 'package:flutter/material.dart';

class MiniPlayer extends StatelessWidget {
  final String trackName;
  final String artistName;
  final String? coverImageUrl;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;
  final VoidCallback? onNext;
  final VoidCallback? onLike;
  final bool isLiked;

  const MiniPlayer({
    Key? key,
    required this.trackName,
    required this.artistName,
    this.coverImageUrl,
    required this.isPlaying,
    required this.isLoading,
    required this.onTap,
    required this.onPlayPause,
    this.onNext,
    this.onLike,
    this.isLiked = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 65,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Cover image
            Container(
              width: 50,
              height: 50,
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                image: coverImageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(coverImageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: Colors.grey[800],
              ),
              child: coverImageUrl == null
                  ? const Icon(Icons.music_note, color: Colors.white)
                  : null,
            ),
            
            // Track info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trackName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      artistName,
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
            ),
            
            // Like button
            if (onLike != null)
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.green : Colors.white,
                  size: 20,
                ),
                onPressed: onLike,
              ),
            
            // Play/pause button
            IconButton(
              icon: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: Colors.white,
                      size: 32,
                    ),
              onPressed: isLoading ? null : onPlayPause,
            ),
            
            // Next button
            if (onNext != null)
              IconButton(
                icon: const Icon(
                  Icons.skip_next,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: onNext,
              ),
          ],
        ),
      ),
    );
  }
}