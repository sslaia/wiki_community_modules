import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/course_models.dart';
import 'course_reader_view.dart';

/// Full-featured screen for reading wiki courses with app bar and navigation actions.
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
  });

  @override
  State<CourseReaderScreen> createState() => _CourseReaderScreenState();
}

class _CourseReaderScreenState extends State<CourseReaderScreen> {
  bool _forceRefresh = false;

  void _shareCourse() {
    final title = widget.title ?? widget.config.pageTitle;
    final uri = Uri.tryParse(widget.config.pageUrl);
    if (uri != null) {
      SharePlus.instance.share(
        ShareParams(uri: uri, title: title),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayTitle = widget.title ?? widget.config.pageTitle;

    return Scaffold(
      drawer: widget.drawer,
      bottomNavigationBar: widget.bottomNavigationBar,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(displayTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
          ],
        ),
        actions: [
          ...?widget.customActions,
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {
                _forceRefresh = true;
              });
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) setState(() => _forceRefresh = false);
              });
            },
          ),
          if (widget.onBookmarkToggle != null)
            IconButton(
              icon: Icon(
                widget.isBookmarked == true ? Icons.bookmark : Icons.bookmark_border,
                color: widget.isBookmarked == true ? theme.colorScheme.primary : null,
              ),
              tooltip: 'Bookmark',
              onPressed: () => widget.onBookmarkToggle!(!(widget.isBookmarked ?? false)),
            ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: _shareCourse,
          ),
        ],
      ),
      body: CourseReaderView(
        config: widget.config,
        cacheDelegate: widget.cacheDelegate,
        forceRefresh: _forceRefresh,
        onLinkTap: widget.onLinkTap,
        onImageTap: widget.onImageTap,
      ),
    );
  }
}
