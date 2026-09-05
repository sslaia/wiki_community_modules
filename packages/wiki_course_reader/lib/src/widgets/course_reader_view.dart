import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/course_models.dart';
import '../services/wiki_course_service.dart';

/// Interactive view for reading course and lesson contents.
class CourseReaderView extends StatefulWidget {
  final CourseConfig config;
  final CourseCacheDelegate? cacheDelegate;
  final bool forceRefresh;
  final void Function(String url)? onLinkTap;
  final void Function(String imageUrl, String? caption)? onImageTap;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final Widget? headerWidget;
  final Widget? footerWidget;
  final Color? primaryColor;
  final Color? accentColor;
  final ScrollController? scrollController;
  final Widget? sliverAppBar;
  final EdgeInsetsGeometry contentPadding;

  const CourseReaderView({
    super.key,
    required this.config,
    this.cacheDelegate,
    this.forceRefresh = false,
    this.onLinkTap,
    this.onImageTap,
    this.loadingBuilder,
    this.errorBuilder,
    this.headerWidget,
    this.footerWidget,
    this.primaryColor,
    this.accentColor,
    this.scrollController,
    this.sliverAppBar,
    this.contentPadding = const EdgeInsets.all(16.0),
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
    final accent = widget.accentColor ?? widget.primaryColor ?? theme.colorScheme.primary;

    return FutureBuilder<CoursePageContent>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (widget.loadingBuilder != null) {
            return widget.loadingBuilder!(context);
          }
          if (widget.sliverAppBar != null) {
            return CustomScrollView(
              controller: widget.scrollController,
              slivers: [
                widget.sliverAppBar!,
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(color: accent),
                    ),
                  ),
                ),
              ],
            );
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: accent),
            ),
          );
        }

        if (snapshot.hasError) {
          if (widget.errorBuilder != null) {
            return widget.errorBuilder!(context, snapshot.error!);
          }
          final errorWidget = Center(
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

          if (widget.sliverAppBar != null) {
            return CustomScrollView(
              controller: widget.scrollController,
              slivers: [
                widget.sliverAppBar!,
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: errorWidget,
                ),
              ],
            );
          }
          return errorWidget;
        }

        final content = snapshot.data!;
        final bodyContent = _buildContentBody(context, content, accent);

        if (widget.sliverAppBar != null) {
          return CustomScrollView(
            controller: widget.scrollController,
            slivers: [
              widget.sliverAppBar!,
              SliverPadding(
                padding: widget.contentPadding,
                sliver: SliverToBoxAdapter(child: bodyContent),
              ),
            ],
          );
        }

        return SingleChildScrollView(
          controller: widget.scrollController,
          padding: widget.contentPadding,
          child: bodyContent,
        );
      },
    );
  }

  Widget _buildContentBody(BuildContext context, CoursePageContent content, Color accent) {
    final theme = Theme.of(context);
    final accentHex = '#${accent.toARGB32().toRadixString(16).substring(2)}';
    final r = (accent.r * 255).round();
    final g = (accent.g * 255).round();
    final b = (accent.b * 255).round();
    final accentBgRgba = 'rgba($r, $g, $b, 0.08)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Offline Banner (only shown if truly loaded from offline cache)
        if (content.isOfflineCache)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.offline_bolt_rounded, size: 20, color: theme.colorScheme.onSecondaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Viewing offline cached edition',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
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
          customStylesBuilder: (element) {
            // 3. Blockquote / Quotation styling matching Village Screen
            if (element.localName == 'blockquote') {
              return {
                'border-left': '4px solid $accentHex',
                'background-color': accentBgRgba,
                'padding': '12px 16px',
                'margin': '14px 0',
                'border-radius': '0 8px 8px 0',
                'font-style': 'italic',
              };
            }
            // 5. Image & caption container styling
            if (element.localName == 'figure' || element.className.contains('thumb')) {
              return {
                'width': '100% !important',
                'max-width': '100%',
                'margin': '16px 0',
                'text-align': 'center',
              };
            }
            if (element.localName == 'figcaption' || element.className.contains('thumbcaption')) {
              return {
                'font-size': '13px',
                'color': '#8E8E93',
                'margin-top': '8px',
                'text-align': 'center',
                'font-style': 'italic',
              };
            }
            return null;
          },
          customWidgetBuilder: (element) {
            // 5. Images with rounded corners and double.infinity width
            if (element.localName == 'img') {
              final rawSrc = element.attributes['src'] ?? '';
              final alt = element.attributes['alt'] ?? '';
              final src = cleanWikimediaImageUrl(rawSrc, defaultWidth: 1000);
              if (src.isEmpty) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    if (widget.onImageTap != null) {
                      widget.onImageTap!(src, alt);
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: src,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (ctx, url) => Container(
                          height: 220,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Center(child: CircularProgressIndicator.adaptive()),
                        ),
                        errorWidget: (ctx, url, err) => Container(
                          height: 140,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            return null;
          },
          textStyle: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 15,
            height: 1.7,
            color: theme.colorScheme.onSurface,
          ),
        ),

        if (widget.footerWidget != null) widget.footerWidget!,
      ],
    );
  }
}
