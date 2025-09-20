import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class FocusAreasChips extends StatelessWidget {
  final List<String> focusAreas;
  final Function(String)? onTap;
  final bool showAll;

  const FocusAreasChips({
    super.key,
    required this.focusAreas,
    this.onTap,
    this.showAll = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayAreas = showAll ? focusAreas : focusAreas.take(3).toList();
    final remainingCount = focusAreas.length - displayAreas.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppTheme.spacingS,
          runSpacing: AppTheme.spacingS,
          children: [
            ...displayAreas.map((area) => FocusAreaChip(
              label: area,
              onTap: onTap != null ? () => onTap!(area) : null,
            )),
            
            if (remainingCount > 0 && !showAll)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM,
                  vertical: AppTheme.spacingS,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.textLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.textLight.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  '+$remainingCount more',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class FocusAreaChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isCompact;

  const FocusAreaChip({
    super.key,
    required this.label,
    this.onTap,
    this.isSelected = false,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? AppTheme.spacingM : AppTheme.spacingL,
            vertical: isCompact ? AppTheme.spacingXS : AppTheme.spacingS,
          ),
          decoration: BoxDecoration(
            color: isSelected 
                ? AppTheme.primaryTeal 
                : AppTheme.primaryTeal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected 
                  ? AppTheme.primaryTeal 
                  : AppTheme.primaryTeal.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isCompact) ...[
                Icon(
                  _getIconForFocusArea(label),
                  size: 16,
                  color: isSelected ? Colors.white : AppTheme.primaryTeal,
                ),
                const SizedBox(width: AppTheme.spacingXS),
              ],
              
              Text(
                label,
                style: (isCompact ? AppTheme.bodySmall : AppTheme.bodyMedium).copyWith(
                  color: isSelected ? Colors.white : AppTheme.primaryTeal,
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              if (isSelected && !isCompact) ...[
                const SizedBox(width: AppTheme.spacingXS),
                const Icon(
                  Icons.check,
                  size: 16,
                  color: Colors.white,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForFocusArea(String area) {
    switch (area.toLowerCase()) {
      case 'relationship':
        return Icons.favorite;
      case 'family':
        return Icons.family_restroom;
      case 'career':
        return Icons.work;
      case 'health':
        return Icons.health_and_safety;
      case 'self-esteem':
        return Icons.psychology;
      case 'finances':
        return Icons.attach_money;
      case 'creative pursuits':
        return Icons.palette;
      default:
        return Icons.star;
    }
  }
}

class EditableFocusAreasChips extends StatefulWidget {
  final List<String> selectedAreas;
  final List<String> availableAreas;
  final Function(List<String>) onChanged;

  const EditableFocusAreasChips({
    super.key,
    required this.selectedAreas,
    required this.availableAreas,
    required this.onChanged,
  });

  @override
  State<EditableFocusAreasChips> createState() => _EditableFocusAreasChipsState();
}

class _EditableFocusAreasChipsState extends State<EditableFocusAreasChips> {
  late List<String> _selectedAreas;

  @override
  void initState() {
    super.initState();
    _selectedAreas = List.from(widget.selectedAreas);
  }

  void _toggleArea(String area) {
    setState(() {
      if (_selectedAreas.contains(area)) {
        _selectedAreas.remove(area);
      } else {
        _selectedAreas.add(area);
      }
    });
    widget.onChanged(_selectedAreas);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTheme.spacingS,
      runSpacing: AppTheme.spacingS,
      children: widget.availableAreas.map((area) {
        final isSelected = _selectedAreas.contains(area);
        return FocusAreaChip(
          label: area,
          isSelected: isSelected,
          onTap: () => _toggleArea(area),
        );
      }).toList(),
    );
  }
}
