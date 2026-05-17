import 'package:chibook/data/models/book_annotation.dart';
import 'package:chibook/services/book_annotation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

Future<void> showBookAnnotationComposer({
  required BuildContext context,
  required WidgetRef ref,
  required String bookId,
  required String quote,
  required String locationLabel,
  String? sectionTitle,
  BookAnnotationKind initialKind = BookAnnotationKind.highlight,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFFF6F8FF),
    builder: (context) => _BookAnnotationSheet(
      bookId: bookId,
      quote: quote,
      locationLabel: locationLabel,
      sectionTitle: sectionTitle,
      initialKind: initialKind,
    ),
  );
}

class _BookAnnotationSheet extends ConsumerStatefulWidget {
  const _BookAnnotationSheet({
    required this.bookId,
    required this.quote,
    required this.locationLabel,
    required this.initialKind,
    this.sectionTitle,
  });

  final String bookId;
  final String quote;
  final String locationLabel;
  final String? sectionTitle;
  final BookAnnotationKind initialKind;

  @override
  ConsumerState<_BookAnnotationSheet> createState() =>
      _BookAnnotationSheetState();
}

class _BookAnnotationSheetState extends ConsumerState<_BookAnnotationSheet> {
  late final TextEditingController _noteController;
  late BookAnnotationKind _kind;
  int _colorValue = 0xFFF3E2AB;

  static const _accentColors = [
    0xFFF3E2AB,
    0xFFDDEBC5,
    0xFFC8E8F5,
    0xFFDAD6FF,
    0xFFFFDCC8,
  ];

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    _kind = widget.initialKind;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottomInset),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            '加入划线与笔记',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.sectionTitle == null
                ? widget.locationLabel
                : '${widget.sectionTitle} · ${widget.locationLabel}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2EAFF)),
            ),
            child: Text(
              widget.quote.trim(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: BookAnnotationKind.values.map((kind) {
              return ChoiceChip(
                label: Text(kind == BookAnnotationKind.highlight ? '划线' : '笔记'),
                selected: _kind == kind,
                onSelected: (_) {
                  setState(() => _kind = kind);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '想法备注（可选）',
              hintText: '比如：这一段适合做成总结、值得回看、和哪章能互相印证。',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '标记颜色',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _accentColors.map((value) {
              final selected = _colorValue == value;
              return GestureDetector(
                onTap: () => setState(() => _colorValue = value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(value),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF4A68E6)
                          : const Color(0xFFD7E2FF),
                      width: selected ? 2.4 : 1.2,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Color(0xFF24367A),
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.bookmark_add_outlined),
            label: Text(
              _kind == BookAnnotationKind.highlight ? '保存划线' : '保存笔记',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final annotation = BookAnnotation(
      id: const Uuid().v4(),
      bookId: widget.bookId,
      kind: _kind,
      quote: widget.quote.trim(),
      note: _noteController.text.trim(),
      locationLabel: widget.locationLabel,
      sectionTitle: widget.sectionTitle?.trim().isEmpty ?? true
          ? null
          : widget.sectionTitle?.trim(),
      colorValue: _colorValue,
      createdAt: DateTime.now(),
    );
    await ref.read(bookAnnotationServiceProvider).saveAnnotation(annotation);
    ref.invalidate(bookAnnotationsProvider(widget.bookId));
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _kind == BookAnnotationKind.highlight ? '已加入划线' : '已加入笔记',
        ),
      ),
    );
  }
}
