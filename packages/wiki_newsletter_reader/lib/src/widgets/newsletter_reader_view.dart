import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/newsletter_models.dart';
import '../services/wiki_newsletter_service.dart';

/// Interactive view for rendering community newsletter and bulletin content.
class NewsletterReaderView extends StatefulWidget {
  final NewsletterConfig config;
  final NewsletterCacheDelegate? cacheDelegate;
  final bool forceRefresh;
  final void Function(String url)? onLinkTap;
  final void Function(String imageUrl, String? caption)? onImageTap;
  final void Function(NewsletterEdition edition)? onLoaded;
  final Map<String, GlobalKey>? sectionKeys;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final Widget? headerWidget;
  final Widget? footerWidget;
  final Color? primaryColor;
  final Color? accentColor;
  final ScrollController? scrollController;
  final Widget? sliverAppBar;
  final EdgeInsetsGeometry contentPadding;
  final TextStyle? h2Style;
  final TextStyle? h3Style;
  final TextStyle? h4Style;

  const NewsletterReaderView({
    super.key,
    required this.config,
    this.cacheDelegate,
    this.forceRefresh = false,
    this.onLinkTap,
    this.onImageTap,
    this.onLoaded,
    this.sectionKeys,
    this.loadingBuilder,
    this.errorBuilder,
    this.headerWidget,
    this.footerWidget,
    this.primaryColor,
    this.accentColor,
    this.scrollController,
    this.sliverAppBar,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 16, 16, 80),
    this.h2Style,
    this.h3Style,
    this.h4Style,
  });

  @override
  State<NewsletterReaderView> createState() => _NewsletterReaderViewState();
}

class _NewsletterReaderViewState extends State<NewsletterReaderView> {
  late Future<NewsletterEdition> _future;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant NewsletterReaderView oldWidget) {
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
      _future = WikiNewsletterService.fetchNewsletter(
        widget.config,
        forceRefresh: widget.forceRefresh,
        cacheDelegate: widget.cacheDelegate,
      ).then((edition) {
        widget.onLoaded?.call(edition);
        return edition;
      });
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

    return FutureBuilder<NewsletterEdition>(
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
                    'Failed to load newsletter edition',
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

        final edition = snapshot.data!;
        final bodyContent = _buildContentBody(context, edition, accent);

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

  Widget _buildContentBody(BuildContext context, NewsletterEdition edition, Color accent) {
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
        if (edition.isOfflineCache)
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
          edition.htmlContent,
          onTapUrl: (url) {
            _handleUrl(url);
            return true;
          },
          customStylesBuilder: (element) {
            // Hide in-page Table of Contents
            if (element.id == 'toc' || element.classes.contains('toc')) {
              return {'display': 'none'};
            }
            // Hide edit section links underneath subheadings
            if (element.classes.contains('mw-editsection')) {
              return {'display': 'none'};
            }
            // Clean up heading wrappers
            if (element.classes.contains('mw-heading')) {
              return {'margin': '0', 'padding': '0'};
            }
            // Quotation / blockquote styling matching village heritage screen
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
            // Full-width image container styling
            if (element.localName == 'figure' || element.classes.contains('thumb')) {
              return {
                'width': '100% !important',
                'max-width': '100%',
                'margin': '16px 0',
                'text-align': 'center',
              };
            }
            if (element.localName == 'figcaption' || element.classes.contains('thumbcaption')) {
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
            // Hide in-page TOC and edit links completely from widget tree
            if (element.id == 'toc' ||
                element.classes.contains('toc') ||
                element.classes.contains('mw-editsection')) {
              return const SizedBox.shrink();
            }

            // Standardized 500px images with rounded corners matching course module
            if (element.localName == 'img') {
              final rawSrc = element.attributes['src'] ?? '';
              final alt = element.attributes['alt'] ?? '';
              final src = cleanWikimediaImageUrl(rawSrc, defaultWidth: 500);
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
                        httpHeaders: {
                          'User-Agent': widget.config.userAgent,
                        },
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

            // Headings h2 and h3 rendered with app typography & GlobalKey for TOC scroll
            if (element.localName == 'h2' || element.localName == 'h3') {
              final isH2 = element.localName == 'h2';
              final id = element.id.isNotEmpty
                  ? element.id
                  : (element.attributes['id'] ?? element.text.trim());

              // Link with GlobalKey for smooth TOC scrolling
              final key = widget.sectionKeys != null
                  ? (widget.sectionKeys![id] ??= GlobalKey())
                  : null;

              final headingText = element.text.trim();
              final defaultH2 = theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: accent,
                height: 1.3,
              );
              final defaultH3 = theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: accent,
                height: 1.3,
              );

              return Container(
                key: key,
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: isH2 ? 22.0 : 16.0,
                  bottom: isH2 ? 8.0 : 6.0,
                ),
                child: Text(
                  headingText,
                  style: isH2
                      ? (widget.h2Style ?? defaultH2)
                      : (widget.h3Style ?? defaultH3),
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
