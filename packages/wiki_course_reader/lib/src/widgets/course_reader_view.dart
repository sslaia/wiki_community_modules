import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/course_models.dart';
import '../services/wiki_course_service.dart';

/// Embeddable body widget for reading a wiki language course or lesson.
class CourseReaderView extends StatefulWidget {
  final CourseConfig config;
  final CourseCacheDelegate? cacheDelegate;
  final bool forceRefresh;
  final void Function(String url)? onLinkTap;
  final void Function(String imageUrl, String? caption)? onImageTap;
  final Widget? headerWidget;
  final Widget? footerWidget;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  const CourseReaderView({
    super.key,
    required this.config,
    this.cacheDelegate,
    this.forceRefresh = false,
    this.onLinkTap,
    this.onImageTap,
    this.headerWidget,
    this.footerWidget,
    this.loadingBuilder,
    this.errorBuilder,
  });

  @override
  State<CourseReaderView> createState() => _CourseReaderViewState();
}

class _CourseReaderViewState extends State<CourseReaderView> {
  late Future<CoursePageContent> _future;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant CourseReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.pageTitle != widget.config.pageTitle ||
        oldWidget.config.langCode != widget.config.langCode ||
        oldWidget.config.domain != widget.config.domain ||
        oldWidget.forceRefresh != widget.forceRefresh) {
      _loadData();
    }
  }

  void _loadData() {
    setState(() {
      _future = WikiCourseService.fetchCourse(
        widget.config,
        forceRefresh: widget.forceRefresh,
        cacheDelegate: widget.cacheDelegate,
      );
    });
  }

  Future<void> _handleUrl(String url) async {
    if (widget.onLinkTap != null) {
      widget.onLinkTap!(url);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<CoursePageContent>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (widget.loadingBuilder != null) {
            return widget.loadingBuilder!(context);
          }
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          if (widget.errorBuilder != null) {
            return widget.errorBuilder!(context, snapshot.error!);
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load course content',
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: _loadData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final content = snapshot.data!;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (content.isOfflineCache)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.offline_bolt_outlined, size: 18, color: theme.colorScheme.onSecondaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Viewing offline cached edition',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.headerWidget != null) widget.headerWidget!,
              HtmlWidget(
                content.htmlContent,
                onTapUrl: (url) {
                  _handleUrl(url);
                  return true;
                },
                onTapImage: (imageMetadata) {
                  final url = imageMetadata.sources.firstOrNull?.url;
                  if (url != null) {
                    if (widget.onImageTap != null) {
                      widget.onImageTap!(url, imageMetadata.alt);
                    }
                  }
                },
                textStyle: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
              if (widget.footerWidget != null) widget.footerWidget!,
            ],
          ),
        );
      },
    );
  }
}


/// Decoupled component conforming to Modular Modules Specification Section 2.4.
class CourseLessonView extends StatelessWidget {
  final String lessonId;
  final String lessonTitle;
  final CourseRepository repository;
  final void Function(String imageUrl, String? caption)? onImageTap;
  final void Function(String audioUrl)? onPlayAudio;
  final void Function(String url)? onLinkTap;
  final Widget? headerWidget;
  final Widget? footerWidget;

  const CourseLessonView({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    required this.repository,
    this.onImageTap,
    this.onPlayAudio,
    this.onLinkTap,
    this.headerWidget,
    this.footerWidget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<String>(
      future: repository.fetchLessonContent(lessonId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load lesson',
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        }

        final content = snapshot.data ?? '';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (headerWidget != null) headerWidget!,
              HtmlWidget(
                content,
                onTapUrl: (url) {
                  if (url.endsWith('.wav') ||
                      url.endsWith('.ogg') ||
                      url.endsWith('.mp3')) {
                    if (onPlayAudio != null) {
                      onPlayAudio!(url);
                      return true;
                    }
                  }
                  if (onLinkTap != null) {
                    onLinkTap!(url);
                    return true;
                  }
                  return false;
                },
                onTapImage: (imageMetadata) {
                  final url = imageMetadata.sources.firstOrNull?.url;
                  if (url != null && onImageTap != null) {
                    onImageTap!(url, imageMetadata.alt);
                  }
                },
                textStyle: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
              if (footerWidget != null) footerWidget!,
            ],
          ),
        );
      },
    );
  }
}
