class ReadingProgress {
  const ReadingProgress({
    required this.bookId,
    required this.location,
    required this.percentage,
    required this.updatedAt,
  });

  final String bookId;
  final String location;
  final double percentage;
  final DateTime updatedAt;
}
