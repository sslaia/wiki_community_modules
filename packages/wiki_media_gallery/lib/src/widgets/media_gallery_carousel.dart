import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/gallery_item.dart';
import 'gallery_image_viewer.dart';

enum GalleryDisplayMode { carousel, grid }

/// Interactive media exhibition widget displaying cultural images in vertical carousel or grid format.
class MediaGalleryCarousel extends StatefulWidget {
  final List<GalleryItem> items;
  final String? initialCategory;
  final Map<String, String>? categoryLabels;
  final String? allLabel;
  final void Function(GalleryItem item)? onItemTapped;
  final void Function(GalleryItem item)? onShareItem;
  final Color? primaryColor;
  final Color? accentColor;
  final bool showCategoryFilter;
  final bool allowModeToggle;

  const MediaGalleryCarousel({
    super.key,
    required this.items,
    this.initialCategory,
    this.categoryLabels,
    this.allLabel,
    this.onItemTapped,
    this.onShareItem,
    this.primaryColor,
    this.accentColor,
    this.showCategoryFilter = true,
    this.allowModeToggle = true,
  });

  @override
  State<MediaGalleryCarousel> createState() => _MediaGalleryCarouselState();
}

class _MediaGalleryCarouselState extends State<MediaGalleryCarousel> {
  late CarouselController _carouselController;
  late String? _selectedCategory;
  GalleryDisplayMode _displayMode = GalleryDisplayMode.carousel;

  @override
  void initState() {
    super.initState();
    _carouselController = CarouselController();
    _selectedCategory = widget.initialCategory;
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  List<String> get _categories {
    final set = <String>{};
    for (final item in widget.items) {
      if (item.category.isNotEmpty) {
        set.add(item.category);
      }
    }
    return set.toList();
  }

  List<GalleryItem> get _filteredItems {
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      return widget.items;
    }
    return widget.items
        .where((item) => item.category.toLowerCase() == _selectedCategory!.toLowerCase())
        .toList();
  }

  String _getCategoryLabel(String categoryKey) {
    if (widget.categoryLabels != null && widget.categoryLabels!.containsKey(categoryKey)) {
      return widget.categoryLabels![categoryKey]!;
    }
    return categoryKey[0].toUpperCase() + categoryKey.substring(1);
  }

  void _openLightbox(GalleryItem item) {
    if (widget.onItemTapped != null) {
      widget.onItemTapped!(item);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GalleryImageViewer(
          item: item,
          onShare: widget.onShareItem,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = widget.primaryColor ?? theme.colorScheme.primary;
    final accent = widget.accentColor ?? theme.colorScheme.secondary;
    final items = _filteredItems;
    final categories = _categories;

    return Column(
      children: [
        // Category chips & View Mode switcher
        if (widget.showCategoryFilter || widget.allowModeToggle)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.95),
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // "All" chip
                        Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: FilterChip(
                            selected: _selectedCategory == null,
                            label: Text(
                              widget.allLabel ?? 'All',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _selectedCategory == null
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _selectedCategory == null
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                            selectedColor: primary,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            checkmarkColor: theme.colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            onSelected: (_) {
                              setState(() {
                                _selectedCategory = null;
                              });
                            },
                          ),
                        ),
                        // Dynamic category chips
                        ...categories.map((cat) {
                          final isSelected = _selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: FilterChip(
                              selected: isSelected,
                              label: Text(
                                _getCategoryLabel(cat),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                              selectedColor: primary,
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              checkmarkColor: theme.colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              onSelected: (_) {
                                setState(() {
                                  _selectedCategory = isSelected ? null : cat;
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                if (widget.allowModeToggle) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _displayMode == GalleryDisplayMode.carousel
                          ? Icons.grid_view_rounded
                          : Icons.view_carousel_rounded,
                      color: primary,
                    ),
                    tooltip: _displayMode == GalleryDisplayMode.carousel
                        ? 'Grid View'
                        : 'Carousel View',
                    onPressed: () {
                      setState(() {
                        _displayMode = _displayMode == GalleryDisplayMode.carousel
                            ? GalleryDisplayMode.grid
                            : GalleryDisplayMode.carousel;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),

        // Main Content Area
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library_outlined,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text(
                        'No media items available',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : _displayMode == GalleryDisplayMode.carousel
                  ? _buildVerticalCarousel(context, items, primary, accent)
                  : _buildGridView(context, items, primary, accent),
        ),
      ],
    );
  }

  Widget _buildVerticalCarousel(
    BuildContext context,
    List<GalleryItem> items,
    Color primary,
    Color accent,
  ) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double itemExtent = (constraints.maxHeight * 0.85).clamp(280.0, 750.0);
        final double shrinkExtent = (constraints.maxHeight * 0.22).clamp(120.0, 200.0);

        return CarouselView.builder(
          controller: _carouselController,
          scrollDirection: Axis.vertical,
          itemExtent: itemExtent,
          shrinkExtent: shrinkExtent,
          itemCount: items.length,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 3,
          onTap: (index) => _openLightbox(items[index]),
          itemBuilder: (context, index) {
            final item = items[index];
            final imageUrl = item.thumbnailUrl ?? item.imageUrl;

            return Stack(
              fit: StackFit.expand,
              children: [
                // Background Image
                if (imageUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    httpHeaders: const {'User-Agent': 'NiasHeritage/1.0 (https://github.com/sslaia/niasheritage)'},
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.black12,
                      child: Center(
                        child: CircularProgressIndicator(color: primary),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                      ),
                    ),
                  )
                else
                  Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: Icon(Icons.image_not_supported_rounded, size: 48, color: Colors.grey),
                    ),
                  ),

                // Gradient Scrim for readable captions
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.4, 0.7, 1.0],
                      colors: [
                        Colors.black38,
                        Colors.transparent,
                        Colors.black54,
                        Colors.black87,
                      ],
                    ),
                  ),
                ),

                // Top Indicator badge (index / total)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: Text(
                      '${index + 1} / ${items.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Bottom Caption & Cultural Metadata
                Positioned(
                  bottom: 20,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Category Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _getCategoryLabel(item.category).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Title
                      Text(
                        item.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: const [
                            Shadow(
                              blurRadius: 4,
                              color: Colors.black,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Description
                      if (item.description != null && item.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          item.description!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                            height: 1.3,
                            shadows: const [
                              Shadow(
                                blurRadius: 4,
                                color: Colors.black,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Tap to view fullscreen',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (widget.onShareItem != null)
                            IconButton(
                              icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                              onPressed: () => widget.onShareItem!(item),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildGridView(
    BuildContext context,
    List<GalleryItem> items,
    Color primary,
    Color accent,
  ) {
    final theme = Theme.of(context);

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final imageUrl = item.thumbnailUrl ?? item.imageUrl;

        return Card(
          clipBehavior: Clip.antiAlias,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              width: 0.8,
            ),
          ),
          child: InkWell(
            onTap: () => _openLightbox(item),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          httpHeaders: const {'User-Agent': 'NiasHeritage/1.0 (https://github.com/sslaia/niasheritage)'},
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Center(
                              child: CircularProgressIndicator(color: primary, strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: Icon(Icons.broken_image_rounded, size: 32, color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: Icon(Icons.image_not_supported_rounded, size: 32, color: Colors.grey),
                          ),
                        ),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getCategoryLabel(item.category),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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
