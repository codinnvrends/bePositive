import 'package:flutter/material.dart';
import '../models/notification_settings.dart';
import '../utils/app_theme.dart';

class FrequencySelector extends StatefulWidget {
  final bool useFrequencyMode;
  final int frequencyValue;
  final String frequencyUnit;
  final Function(bool useFrequencyMode, int value, String unit) onChanged;

  const FrequencySelector({
    super.key,
    required this.useFrequencyMode,
    required this.frequencyValue,
    required this.frequencyUnit,
    required this.onChanged,
  });

  @override
  State<FrequencySelector> createState() => _FrequencySelectorState();
}

class _FrequencySelectorState extends State<FrequencySelector> {
  late bool _useFrequencyMode;
  late int _frequencyValue;
  late String _frequencyUnit;

  @override
  void initState() {
    super.initState();
    _useFrequencyMode = widget.useFrequencyMode;
    _frequencyValue = widget.frequencyValue;
    _frequencyUnit = widget.frequencyUnit;
  }

  @override
  void didUpdateWidget(FrequencySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.useFrequencyMode != widget.useFrequencyMode ||
        oldWidget.frequencyValue != widget.frequencyValue ||
        oldWidget.frequencyUnit != widget.frequencyUnit) {
      setState(() {
        _useFrequencyMode = widget.useFrequencyMode;
        _frequencyValue = widget.frequencyValue;
        _frequencyUnit = widget.frequencyUnit;
      });
    }
  }

  void _updateSettings() {
    widget.onChanged(_useFrequencyMode, _frequencyValue, _frequencyUnit);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notification Frequency',
            style: AppTheme.headingSmall,
          ),
          
          const SizedBox(height: AppTheme.spacingM),
          
          // Mode selector
          Row(
            children: [
              Expanded(
                child: _buildModeCard(
                  title: 'Time Window',
                  description: 'Multiple notifications within a daily time window',
                  isSelected: !_useFrequencyMode,
                  onTap: () {
                    setState(() {
                      _useFrequencyMode = false;
                    });
                    _updateSettings();
                  },
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: _buildModeCard(
                  title: 'Fixed Frequency',
                  description: 'Notifications at regular intervals',
                  isSelected: _useFrequencyMode,
                  onTap: () {
                    setState(() {
                      _useFrequencyMode = true;
                    });
                    _updateSettings();
                  },
                ),
              ),
            ],
          ),
          
          if (_useFrequencyMode) ...[
            const SizedBox(height: AppTheme.spacingL),
            _buildFrequencyControls(),
          ],
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryTeal.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppTheme.primaryTeal : AppTheme.textLight.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isSelected ? AppTheme.primaryTeal : AppTheme.textLight,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Text(
                    title,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? AppTheme.primaryTeal : AppTheme.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingXS),
            Text(
              description,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencyControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Frequency Settings',
          style: AppTheme.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        
        const SizedBox(height: AppTheme.spacingM),
        
        // Unit selector
        Row(
          children: [
            Text(
              'Every',
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: _buildUnitSelector(),
            ),
          ],
        ),
        
        const SizedBox(height: AppTheme.spacingM),
        
        // Value selector
        _buildValueSelector(),
        
        const SizedBox(height: AppTheme.spacingM),
        
        // Preview
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            color: AppTheme.primaryTeal.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.schedule,
                color: AppTheme.primaryTeal,
                size: 20,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Text(
                _getFrequencyPreview(),
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.primaryTeal,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnitSelector() {
    return DropdownButtonFormField<String>(
      value: _frequencyUnit,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(),
      ),
      items: NotificationSettings.availableUnits.map((unit) {
        return DropdownMenuItem(
          value: unit,
          child: Text(_capitalizeFirst(unit)),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _frequencyUnit = value;
            // Reset to a valid value for the new unit
            final options = NotificationSettings.getFrequencyOptions(value);
            if (!options.contains(_frequencyValue)) {
              _frequencyValue = options.first;
            }
          });
          _updateSettings();
        }
      },
    );
  }

  Widget _buildValueSelector() {
    final options = NotificationSettings.getFrequencyOptions(_frequencyUnit);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Value',
          style: AppTheme.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppTheme.spacingS),
        Wrap(
          spacing: AppTheme.spacingS,
          runSpacing: AppTheme.spacingS,
          children: options.map((value) {
            final isSelected = value == _frequencyValue;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _frequencyValue = value;
                });
                _updateSettings();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM,
                  vertical: AppTheme.spacingS,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryTeal : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryTeal : AppTheme.textLight.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  value.toString(),
                  style: AppTheme.bodyMedium.copyWith(
                    color: isSelected ? Colors.white : AppTheme.textDark,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _getFrequencyPreview() {
    final unit = _frequencyValue == 1 
        ? _frequencyUnit.substring(0, _frequencyUnit.length - 1) // Remove 's' for singular
        : _frequencyUnit;
    
    return 'Every $_frequencyValue $unit';
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
