# wiki_newsletter_reader

A neutral, decoupled Flutter package for reading community bulletins, newsletters, and magazines from Wikimedia or custom wikis.

## Features

- **Decoupled Architecture**: Embed `NewsletterReaderView` anywhere or use `NewsletterReaderScreen`.
- **Global & Script Agnostic**: Supports any Wikimedia language code (`nia`, `jv`, `id`, `tl`, `zh`, `ja`, etc.).
- **Automatic Hero Cover**: Extracts the publication's cover photo or takes an explicit image URL.
- **Built-in Offline Caching**: Automatically stores downloaded editions for offline reading.
- **Pull-to-Refresh & Sharing**: Built-in pull-to-refresh and social sharing.

## Usage

```dart
import 'package:wiki_newsletter_reader/wiki_newsletter_reader.dart';

NewsletterReaderView(
  config: const NewsletterConfig(
    langCode: 'nia',
    project: 'wikipedia',
    pageTitle: 'Wikipedia:Turia',
  ),
  onLinkTap: (url) => print('Tapped link: $url'),
)
```
