import 'package:flutter/material.dart';
import '../models/gallery_item.dart';
import 'media_gallery_carousel.dart';

/// Fullscreen Scaffold wrapper for host apps wanting a plug-and-play Media Gallery screen.
class MediaGalleryScreen extends StatelessWidget {
  final String title;
  final List<GalleryItem> items;
  final String? initialCategory;
  final Map<String, String>? categoryLabels;
  final String? allLabel;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? drawer;
  final void Function(GalleryItem item)? onItemTapped;
  final void Function(GalleryItem item)? onShareItem;
  final Color? primaryColor;
  final Color? accentColor;

  const MediaGalleryScreen({
    super.key,
    required this.title,
    required this.items,
    this.initialCategory,
    this.categoryLabels,
    this.allLabel,
    this.leading,
    this.actions,
    this.drawer,
    this.onItemTapped,
    this.onShareItem,
    this.primaryColor,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: drawer,
      appBar: AppBar(
        leading: leading,
        title: Text(title),
        actions: actions,
      ),
      body: MediaGalleryCarousel(
        items: items,
        initialCategory: initialCategory,
        categoryLabels: categoryLabels,
        allLabel: allLabel,
        onItemTapped: onItemTapped,
        onShareItem: onShareItem,
        primaryColor: primaryColor,
        accentColor: accentColor,
      ),
    );
  }
}
