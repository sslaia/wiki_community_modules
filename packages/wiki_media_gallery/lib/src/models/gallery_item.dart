/// Model representing an individual media exhibition item.
class GalleryItem {
  final String id;
  final String title;
  final String imageUrl;
  final String? thumbnailUrl;
  final String category;
  final String? description;
  final String? author;
  final String? license;
  final Map<String, dynamic>? metadata;

  const GalleryItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.thumbnailUrl,
    required this.category,
    this.description,
    this.author,
    this.license,
    this.metadata,
  });

  static String _cleanFileName(dynamic fileName) {
    if (fileName == null) return '';
    var s = fileName.toString().trim();
    if (s.startsWith('File:')) s = s.substring(5);
    try {
      s = Uri.decodeFull(s);
    } catch (_) {}
    return Uri.encodeComponent(s);
  }

  factory GalleryItem.fromJson(Map<String, dynamic> json) {
    final fileName = json['fileName'];
    final defaultUrl = fileName != null
        ? 'https://commons.wikimedia.org/wiki/Special:FilePath/${_cleanFileName(fileName)}'
        : '';
    final defaultThumb = fileName != null
        ? 'https://commons.wikimedia.org/wiki/Special:FilePath/${_cleanFileName(fileName)}?width=500'
        : null;

    return GalleryItem(
      id: json['id']?.toString() ?? json['fileName']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? defaultUrl,
      thumbnailUrl: json['thumbnailUrl']?.toString() ?? defaultThumb,
      category: json['category']?.toString() ?? 'General',
      description: json['description']?.toString(),
      author: json['author']?.toString(),
      license: json['license']?.toString(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'imageUrl': imageUrl,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        'category': category,
        if (description != null) 'description': description,
        if (author != null) 'author': author,
        if (license != null) 'license': license,
        if (metadata != null) 'metadata': metadata,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GalleryItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
