enum BookAnnotationKind { highlight, note }

class BookAnnotation {
  const BookAnnotation({
    required this.id,
    required this.bookId,
    required this.kind,
    required this.quote,
    required this.locationLabel,
    required this.colorValue,
    required this.createdAt,
    this.note = '',
    this.sectionTitle,
  });

  final String id;
  final String bookId;
  final BookAnnotationKind kind;
  final String quote;
  final String note;
  final String locationLabel;
  final String? sectionTitle;
  final int colorValue;
  final DateTime createdAt;

  bool get hasNote => note.trim().isNotEmpty;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'bookId': bookId,
      'kind': kind.name,
      'quote': quote,
      'note': note,
      'locationLabel': locationLabel,
      'sectionTitle': sectionTitle,
      'colorValue': colorValue,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BookAnnotation.fromJson(Map<String, Object?> json) {
    return BookAnnotation(
      id: json['id'] as String? ?? '',
      bookId: json['bookId'] as String? ?? '',
      kind: BookAnnotationKind.values.byName(
        json['kind'] as String? ?? BookAnnotationKind.highlight.name,
      ),
      quote: json['quote'] as String? ?? '',
      note: json['note'] as String? ?? '',
      locationLabel: json['locationLabel'] as String? ?? '',
      sectionTitle: json['sectionTitle'] as String?,
      colorValue: json['colorValue'] as int? ?? 0xFFE8D39A,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
