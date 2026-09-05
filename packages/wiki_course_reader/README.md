# wiki_course_reader

A neutral, decoupled Flutter package for rendering language lessons, courses, and educational pages from any Wikimedia project or custom MediaWiki installation.

## Features

- **Decoupled Architecture**: Embed `CourseReaderView` anywhere or use `CourseReaderScreen`.
- **Global & Script Agnostic**: Supports any Wikimedia language code (`nia`, `jv`, `id`, `tl`, `zh`, `ja`, etc.).
- **Built-in Offline Caching**: Automatically saves viewed lessons to local cache with zero setup.
- **Pluggable Navigation**: Callbacks for audio playback, external links, image taps, and bookmarks.

## Usage

```dart
import 'package:wiki_course_reader/wiki_course_reader.dart';

CourseReaderView(
  config: const CourseConfig(
    langCode: 'nia',
    project: 'wiktionary',
    pageTitle: 'Wikikamus:Sulu',
  ),
  onLinkTap: (url) => print('User tapped $url'),
  onImageTap: (imageUrl, caption) => print('Image: $imageUrl'),
)
```
