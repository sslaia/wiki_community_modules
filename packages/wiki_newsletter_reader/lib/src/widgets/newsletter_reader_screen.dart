import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/newsletter_models.dart';
import 'newsletter_reader_view.dart';

/// Full screen reader for community newsletters with app bar and sharing actions.
class NewsletterReaderScreen extends StatefulWidget {
  final NewsletterConfig config;
  final NewsletterCacheDelegate? cacheDelegate;
  final String? title;
  final Widget? drawer;
  final Widget? bottomNavigationBar;
  final List<Widget>? customActions;
  final void Function(String url)? onLinkTap;
  final void Function(String imageUrl, String? caption)? onImageTap;

  const NewsletterReaderScreen({
    super.key,
    required this.config,
    this.cacheDelegate,
    this.title,
    this.drawer,
    this.bottomNavigationBar,
    this.customActions,
    this.onLinkTap,
    this.onImageTap,
  });

  @override
  State<NewsletterReaderScreen> createState() => _NewsletterReaderScreenState();
}

class _NewsletterReaderScreenState extends State<NewsletterReaderScreen> {
  bool _forceRefresh = false;

  void _shareNewsletter() {
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
    final displayTitle = widget.title ?? widget.config.pageTitle;

    return Scaffold(
      drawer: widget.drawer,
      bottomNavigationBar: widget.bottomNavigationBar,
      appBar: AppBar(
        title: Text(displayTitle),
        actions: [
          ...?widget.customActions,
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() => _forceRefresh = true);
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) setState(() => _forceRefresh = false);
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: _shareNewsletter,
          ),
        ],
      ),
      body: NewsletterReaderView(
        config: widget.config,
        cacheDelegate: widget.cacheDelegate,
        forceRefresh: _forceRefresh,
        onLinkTap: widget.onLinkTap,
        onImageTap: widget.onImageTap,
      ),
    );
  }
}
