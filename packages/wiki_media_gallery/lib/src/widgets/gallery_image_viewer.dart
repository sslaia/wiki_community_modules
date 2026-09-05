import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/gallery_item.dart';

/// Fullscreen zoomable lightbox image viewer for Gallery items.
class GalleryImageViewer extends StatelessWidget {
  final GalleryItem item;
  final VoidCallback? onClose;
  final void Function(GalleryItem item)? onShare;

  const GalleryImageViewer({
    super.key,
    required this.item,
    this.onClose,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetUrl = item.imageUrl.isNotEmpty ? item.imageUrl : (item.thumbnailUrl ?? '');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Zoomable image
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: targetUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: targetUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(color: Colors.white70),
                      ),
                      errorWidget: (context, url, error) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 54),
                          const SizedBox(height: 12),
                          Text(
                            item.title,
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 54),
            ),
          ),

          // Top action bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: onClose ?? () => Navigator.of(context).pop(),
                  ),
                ),
                if (onShare != null)
                  CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.share_rounded, color: Colors.white),
                      onPressed: () => onShare!(item),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom caption & metadata bar
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (item.description != null && item.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (item.author != null || item.license != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (item.author != null)
                          Expanded(
                            child: Text(
                              'Author: ${item.author}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white54,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (item.license != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.license!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
