import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../models/radar.dart';
import '../providers/filter_provider.dart';
import '../utils/formatters.dart';

/// Horizontally scrollable filter chips for type, city and status.
///
/// Chips write straight into [FilterProvider], so a filter picked here also
/// narrows the map and the corridor list.
class FilterBar extends StatelessWidget {
  const FilterBar({super.key, required this.cities});

  final List<String> cities;

  @override
  Widget build(BuildContext context) {
    final FilterProvider filters = context.watch<FilterProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ChipRow(
          children: <Widget>[
            _FilterChip(
              label: 'Svi tipovi',
              selected: filters.type == null,
              onSelected: () => filters.setType(null),
            ),
            for (final RadarType type in RadarType.values)
              _FilterChip(
                label: type.shortLabel,
                color: type.color,
                selected: filters.type == type,
                onSelected: () => filters.setType(type),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _ChipRow(
          children: <Widget>[
            _FilterChip(
              label: 'Svi gradovi',
              selected: filters.city == null,
              onSelected: () => filters.setCity(null),
            ),
            for (final String city in cities)
              _FilterChip(
                label: Formatters.city(city),
                selected: filters.city == city,
                onSelected: () => filters.setCity(city),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _ChipRow(
          children: <Widget>[
            _FilterChip(
              label: 'Svi statusi',
              selected: filters.status == null,
              onSelected: () => filters.setStatus(null),
            ),
            for (final RadarStatus status in RadarStatus.values)
              _FilterChip(
                label: status.label,
                color: status == RadarStatus.completed
                    ? AppColors.lightSuccess
                    : AppColors.warning,
                selected: filters.status == status,
                onSelected: () => filters.setStatus(status),
              ),
            if (filters.hasActiveFilters)
              _FilterChip(
                label: 'Poništi',
                icon: Icons.close,
                selected: false,
                onSelected: filters.clear,
              ),
          ],
        ),
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (BuildContext context, int index) => children[index],
      ),
    );
  }
}

/// A chip that scales down briefly when pressed, for tactile feedback.
class _FilterChip extends StatefulWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color? color;
  final IconData? icon;

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = widget.color ?? theme.colorScheme.primary;
    final Color background = widget.selected
        ? accent
        : theme.colorScheme.surfaceContainerHighest;
    final Color foreground =
        widget.selected ? Colors.white : theme.colorScheme.onSurface;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onSelected,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 110),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadii.chip),
            border: Border.all(
              color: widget.selected ? accent : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (widget.icon != null) ...<Widget>[
                Icon(widget.icon, size: 15, color: foreground),
                const SizedBox(width: AppSpacing.xs + 2),
              ],
              Text(
                widget.label,
                style: theme.textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
