import 'package:chibook/app/liquid_ui.dart';
import 'package:flutter/material.dart';

class AppShellDestination {
  const AppShellDestination({
    required this.label,
    required this.icon,
    this.emphasized = false,
  });

  final String label;
  final IconData icon;
  final bool emphasized;
}

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
    this.footer,
  });

  final List<AppShellDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      child: SizedBox(
        width: 132,
        child: LiquidGlassCard(
          key: const Key('app-shell-sidebar'),
          radius: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            children: [
              for (var index = 0; index < destinations.length; index++) ...[
                _SidebarItem(
                  destination: destinations[index],
                  selected: currentIndex == index,
                  onTap: () => onSelect(index),
                ),
                if (index != destinations.length - 1) const SizedBox(height: 8),
              ],
              if (footer != null) ...[
                const Spacer(),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const selectedColor = Color(0xFF5D7CFF);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFFE9F0FF), Color(0xD8FFFFFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: selected || destination.emphasized
                      ? const LinearGradient(
                          colors: [Color(0xFF84C9FF), Color(0xFF5D7CFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: selected || destination.emphasized
                      ? null
                      : Colors.white.withValues(alpha: 0.42),
                ),
                child: Icon(
                  destination.icon,
                  color: selected || destination.emphasized
                      ? Colors.white
                      : const Color(0xFF38507A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                destination.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? selectedColor : const Color(0xFF38507A),
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
