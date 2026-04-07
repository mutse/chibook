class PdfChapterData {
  const PdfChapterData({
    required this.title,
    required this.startPage,
    required this.endPage,
    required this.text,
  });

  final String title;
  final int startPage;
  final int endPage;
  final String text;

  String get segmentId => 'pdf-chapter-$startPage-$endPage';

  bool get isSinglePage => startPage == endPage;
}
