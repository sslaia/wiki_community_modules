import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/newsletter_models.dart';
import '../services/wiki_newsletter_service.dart';

/// Embeddable body widget for reading a community newsletter or bulletin.
class NewsletterReaderView extends StatefulWidget {
  final NewsletterConfig config;
  final NewsletterCacheDelegate? cacheDelegate;
  final bool forceRefresh;
  final void Function(String url)? onLinkTap;
  final void Function(String imageUrl, String? caption)? onImageTap;
  final Widget? headerWidget;
  final Widget? footerWidget;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  const NewsletterReaderView({
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

    return FutureBuilder<NewsletterEdition>(
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
                  Icon(Icons.newspaper_outlined, size: 48, color: theme.colorScheme.error),
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
        }

        final edition = snapshot.data!;

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _future = WikiNewsletterService.fetchNewsletter(
                widget.config,
                forceRefresh: true,
                cacheDelegate: widget.cacheDelegate,
              );
            });
            await _future;
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (edition.heroImageUrl != null && edition.heroImageUrl!.isNotEmpty)
                  _buildHeroCover(context, edition),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (edition.isOfflineCache)
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
                                  'Offline edition',
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
                        edition.htmlContent,
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroCover(BuildContext context, NewsletterEdition edition) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 220,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            edition.heroImageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: theme.colorScheme.surfaceContainerHighest),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.75),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Text(
              edition.pageTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                shadows: const [
                  Shadow(blurRadius: 6, color: Colors.black, offset: Offset(1, 1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
