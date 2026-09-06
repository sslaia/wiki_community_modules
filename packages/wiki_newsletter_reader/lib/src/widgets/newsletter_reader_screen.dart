import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/newsletter_models.dart';
import '../services/wiki_newsletter_service.dart';
import 'newsletter_floating_toc.dart';
import 'newsletter_reader_view.dart';

/// Full screen reader for community newsletters and bulletins featuring
/// a SliverAppBar with hero image, expandable floating TOC pill, and app theming.
class NewsletterReaderScreen extends StatefulWidget {
  final NewsletterConfig config;
  final NewsletterCacheDelegate? cacheDelegate;
  final String? title;
  final String? subtitle;
  final Widget? drawer;
  final Widget? bottomNavigationBar;
  final List<Widget>? customActions;
  final void Function(String url)? onLinkTap;
  final void Function(String imageUrl, String? caption)? onImageTap;
  final Color? primaryColor;
  final Color? accentColor;
  final String? heroImageUrl;
  final IconData? fallbackHeroIcon;
  final TextStyle? titleTextStyle;
  final TextStyle? h2Style;
  final TextStyle? h3Style;
  final TextStyle? h4Style;
  final String tocLabel;
  final String closeLabel;

  const NewsletterReaderScreen({
    super.key,
    required this.config,
    this.cacheDelegate,
    this.title,
    this.subtitle,
    this.drawer,
    this.bottomNavigationBar,
    this.customActions,
    this.onLinkTap,
    this.onImageTap,
    this.primaryColor,
    this.accentColor,
    this.heroImageUrl,
    this.fallbackHeroIcon,
    this.titleTextStyle,
    this.h2Style,
    this.h3Style,
    this.h4Style,
    this.tocLabel = 'Table of Contents',
    this.closeLabel = 'Close',
  });

  @override
  State<NewsletterReaderScreen> createState() => _NewsletterReaderScreenState();
}

class _NewsletterReaderScreenState extends State<NewsletterReaderScreen> {
  bool _forceRefresh = false;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};
  NewsletterEdition? _loadedEdition;

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
      final edition = await WikiNewsletterService.fetchNewsletter(
        widget.config,
        forceRefresh: false,
        cacheDelegate: widget.cacheDelegate,
      );
      if (mounted) {
        setState(() {
          _loadedEdition = edition;
        });
      }
    } catch (_) {}
  }

  void _shareNewsletter() {
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
    if (_loadedEdition != null) {
      if (_loadedEdition!.heroImageUrl != null && _loadedEdition!.heroImageUrl!.isNotEmpty) {
        return _loadedEdition!.heroImageUrl;
      }
      return extractHeroImageUrl(
        _loadedEdition!.htmlContent,
        _loadedEdition!.images,
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
          widget.fallbackHeroIcon ?? Icons.newspaper_rounded,
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
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh',
          onPressed: () {
            setState(() => _forceRefresh = true);
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted) {
                setState(() => _forceRefresh = false);
                _loadInitialContent();
              }
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Refreshing newsletter...'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.share_rounded),
          tooltip: 'Share',
          onPressed: _shareNewsletter,
        ),
        ...?widget.customActions,
      ],
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
                httpHeaders: {
                  'User-Agent': widget.config.userAgent,
                },
                fit: BoxFit.cover,
                errorWidget: (context, url, error) =>
                    _buildFallbackHeroBackground(theme, accent),
              )
            else
              _buildFallbackHeroBackground(theme, accent),

            // Gradient overlay for readability and contrast
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.accentColor ?? widget.primaryColor ?? theme.colorScheme.primary;

    return Scaffold(
      drawer: widget.drawer,
      bottomNavigationBar: widget.bottomNavigationBar,
      body: Stack(
        children: [
          NewsletterReaderView(
            config: widget.config,
            cacheDelegate: widget.cacheDelegate,
            forceRefresh: _forceRefresh,
            onLinkTap: widget.onLinkTap,
            onImageTap: widget.onImageTap,
            onLoaded: (edition) {
              if (mounted) {
                setState(() => _loadedEdition = edition);
              }
            },
            sectionKeys: _sectionKeys,
            primaryColor: widget.primaryColor,
            accentColor: widget.accentColor,
            scrollController: _scrollController,
            sliverAppBar: _buildSliverAppBar(context, accent),
            contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            h2Style: widget.h2Style,
            h3Style: widget.h3Style,
            h4Style: widget.h4Style,
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

          // Expandable Floating Table of Contents Pill
          if (_loadedEdition != null && _loadedEdition!.sections.isNotEmpty)
            NewsletterFloatingToc(
              sections: _loadedEdition!.sections,
              accentColor: accent,
              scrollController: _scrollController,
              sectionKeys: _sectionKeys,
              tocLabel: widget.tocLabel,
              closeLabel: widget.closeLabel,
            ),
        ],
      ),
    );
  }
}
