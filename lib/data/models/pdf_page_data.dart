class PdfPageData {
  const PdfPageData({
    required this.pageNumber,
    required this.text,
  });

  final int pageNumber;
  final String text;

  String get segmentId => 'pdf-page-$pageNumber';
}
