import 'package:flutter/material.dart';

class PdfSelectionToolbar extends StatelessWidget {
  const PdfSelectionToolbar({
    super.key,
    required this.selectedText,
    required this.onReadAloud,
    required this.onClear,
  });

  final String selectedText;
  final VoidCallback onReadAloud;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF18211D),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '已选文本',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              selectedText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFEAF1ED),
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onReadAloud,
                    icon: const Icon(Icons.volume_up_outlined),
                    label: const Text('朗读选区'),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: onClear,
                  child: const Text('清除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
