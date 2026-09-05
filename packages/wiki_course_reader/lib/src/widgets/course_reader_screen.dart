import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/course_models.dart';
import '../services/wiki_course_service.dart';
import 'course_reader_view.dart';

/// Full-featured screen for reading wiki courses with SliverAppBar,
/// hero image, and a floating action bar.
class CourseReaderScreen extends StatefulWidget {
  final CourseConfig config;
  final CourseCacheDelegate? cacheDelegate;
  final String? title;
  final String? subtitle;
  final Widget? drawer;
  final Widget? bottomNavigationBar;
  final List<Widget>? customActions;
  final bool? isBookmarked;
  final ValueChanged<bool>? onBookmarkToggle;
  final void Function(String url)? onLinkTap;
  final void Function(String imageUrl, String? caption)? onImageTap;
  final Color? primaryColor;
  final Color? accentColor;
  final String? heroImageUrl;
  final IconData? fallbackHeroIcon;
  final TextStyle? titleTextStyle;

  const CourseReaderScreen({
    super.key,
    required this.config,
    this.cacheDelegate,
    this.title,
    this.subtitle,
    this.drawer,
    this.bottomNavigationBar,
    this.customActions,
    this.isBookmarked,
    this.onBookmarkToggle,
    this.onLinkTap,
    this.onImageTap,
    this.primaryColor,
    this.accentColor,
    this.heroImageUrl,
    this.fallbackHeroIcon,
    this.titleTextStyle,
  });

  @override
  State<CourseReaderScreen> createState() => _CourseReaderScreenState();
}

class _CourseReaderScreenState extends State<CourseReaderScreen> {
  bool _forceRefresh = false;
  final ScrollController _scrollController = ScrollController();
  CoursePageContent? _loadedContent;

  @override
  void initState() {
    super.initState();
    _loadInitialContent();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialContent() async {
    try {
      final content = await WikiCourseService.fetchCourse(
        widget.config,
        forceRefresh: false,
        cacheDelegate: widget.cacheDelegate,
      );
      if (mounted) {
        setState(() {
          _loadedContent = content;
        });
      }
    } catch (_) {}
  }

  void _shareCourse() {
    final title = widget.title ?? widget.config.pageTitle;
    final uri = Uri.tryParse(widget.config.pageUrl);
    if (uri != null) {
      SharePlus.instance.share(
        ShareParams(uri: uri, title: title),
      );
    }
  }

  String? _resolveHeroImageUrl() {
    if (widget.heroImageUrl != null && widget.heroImageUrl!.isNotEmpty) {
      return widget.heroImageUrl;
    }
    if (_loadedContent != null) {
      return extractHeroImageUrl(
        _loadedContent!.htmlContent,
        _loadedContent!.images,
        domain: widget.config.domain,
      );
    }
    return null;
  }

  Widget _buildFallbackHeroBackground(ThemeData theme, Color accent) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.9),
            theme.colorScheme.surfaceContainerHighest,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          widget.fallbackHeroIcon ?? Icons.school_rounded,
          size: 72,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, Color accent) {
    final theme = Theme.of(context);
    final displayTitle = widget.title ?? widget.config.pageTitle;
    final heroImage = _resolveHeroImageUrl();

    return SliverAppBar(
      expandedHeight: 240.0,
      pinned: true,
      stretch: true,
      backgroundColor: accent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
      actions: widget.customActions,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
        title: Text(
          displayTitle,
          style: widget.titleTextStyle ??
              theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: const [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 4.0,
                    color: Colors.black87,
                  ),
                ],
              ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (heroImage != null && heroImage.isNotEmpty)
              CachedNetworkImage(
                imageUrl: heroImage,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) =>
                    _buildFallbackHeroBackground(theme, accent),
              )
            else
              _buildFallbackHeroBackground(theme, accent),

            // Gradient overlay for contrast
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black26,
                    Colors.black87,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionBar(BuildContext context, Color accent) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: accent.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Refresh Button
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  setState(() {
                    _forceRefresh = true;
                  });
                  Future.delayed(const Duration(milliseconds: 600), () {
                    if (mounted) {
                      setState(() => _forceRefresh = false);
                      _loadInitialContent();
                    }
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Refreshing course content...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, size: 20, color: accent),
                      const SizedBox(width: 6),
                      Text(
                        'Refresh',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                height: 20,
                width: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                margin: const EdgeInsets.symmetric(horizontal: 4),
              ),
              if (widget.onBookmarkToggle != null) ...[
                IconButton(
                  icon: Icon(
                    widget.isBookmarked == true
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 20,
                    color: accent,
                  ),
                  tooltip: 'Bookmark',
                  onPressed: () =>
                      widget.onBookmarkToggle!(!(widget.isBookmarked ?? false)),
                ),
                Container(
                  height: 20,
                  width: 1,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ],
              // Share Button
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _shareCourse,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.share_rounded, size: 20, color: accent),
                      const SizedBox(width: 6),
                      Text(
                        'Share',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.accentColor ?? widget.primaryColor ?? theme.colorScheme.primary;

    return Scaffold(
      drawer: widget.drawer,
      bottomNavigationBar: widget.bottomNavigationBar,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFloatingActionBar(context, accent),
      body: CourseReaderView(
        config: widget.config,
        cacheDelegate: widget.cacheDelegate,
        forceRefresh: _forceRefresh,
        onLinkTap: widget.onLinkTap,
        onImageTap: widget.onImageTap,
        primaryColor: widget.primaryColor,
        accentColor: widget.accentColor,
        scrollController: _scrollController,
        sliverAppBar: _buildSliverAppBar(context, accent),
        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        headerWidget: widget.subtitle != null
            ? Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  widget.subtitle!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
