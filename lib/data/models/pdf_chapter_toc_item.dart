class PdfChapterTocItem {
  const PdfChapterTocItem({
    required this.title,
    required this.startPage,
    required this.endPage,
  });

  final String title;
  final int startPage;
  final int endPage;

  bool get isSinglePage => startPage == endPage;
}
