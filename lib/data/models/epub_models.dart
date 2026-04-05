class EpubChapterData {
  const EpubChapterData({
    required this.index,
    required this.title,
    required this.htmlContent,
    required this.plainText,
    this.depth = 0,
  });

  final int index;
  final String title;
  final String htmlContent;
  final String plainText;
  final int depth;
}

class EpubBookData {
  const EpubBookData({
    required this.title,
    required this.author,
    required this.chapters,
  });

  final String title;
  final String author;
  final List<EpubChapterData> chapters;
}
