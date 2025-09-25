import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:be_positive/providers/affirmation_provider.dart';
import 'package:be_positive/utils/app_theme.dart';

class AddCustomAffirmationScreen extends StatefulWidget {
  const AddCustomAffirmationScreen({super.key});

  @override
  State<AddCustomAffirmationScreen> createState() => _AddCustomAffirmationScreenState();
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
    this.size = 40,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          minimumSize: Size(size, size),
        ),
        onPressed: onPressed,
        child: Icon(icon, size: iconSize),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  final String label;
  final String Function() valueBuilder;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final double? labelWidth;

  const _StepperRow({
    required this.label,
    required this.valueBuilder,
    required this.onDecrement,
    required this.onIncrement,
    this.labelWidth = 160,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final computedLabelW = (labelWidth ?? screenW * 0.5).clamp(120, 180).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
      child: Row(
        children: [
          SizedBox(
            width: computedLabelW,
            child: Text(
              label,
              style: AppTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _RoundIconButton(icon: Icons.remove, onPressed: onDecrement, size: 32, iconSize: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  valueBuilder(),
                  style: Theme.of(context).textTheme.bodyMedium,
                  softWrap: false,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _RoundIconButton(icon: Icons.add, onPressed: onIncrement, size: 32, iconSize: 18),
        ],
      ),
    );
  }
}

class _AddCustomAffirmationScreenState extends State<AddCustomAffirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Custom');

  bool _reminderEnabled = true;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 21, minute: 0);
  int _dailyCount = 1;
  final Set<int> _days = {1,2,3,4,5,6,7};

  @override
  void dispose() {
    _contentController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  int _minutesOf(TimeOfDay t) => t.hour * 60 + t.minute;

  void _ensureEndAfterStart() {
    final start = _minutesOf(_startTime);
    final end = _minutesOf(_endTime);
    if (end <= start) {
      final newEnd = (start + 15) % (24 * 60);
      _endTime = TimeOfDay(hour: newEnd ~/ 60, minute: newEnd % 60);
    }
  }

  int _maxAllowedCount() {
    final start = _minutesOf(_startTime);
    final end = _minutesOf(_endTime);
    final total = (end - start).clamp(0, 24 * 60);
    final maxByFive = (total ~/ 5);
    return maxByFive.clamp(1, 96);
  }

  void _enforceCountCap() {
    final max = _maxAllowedCount();
    if (_dailyCount > max) _dailyCount = max;
    if (_dailyCount < 1) _dailyCount = 1;
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour == 0 ? 12 : hour}:$minute $period';
  }

  String _getDayLetter(int dayNumber) {
    switch (dayNumber) {
      case 1: return 'M';
      case 2: return 'T';
      case 3: return 'W';
      case 4: return 'T';
      case 5: return 'F';
      case 6: return 'S';
      case 7: return 'S';
      default: return '';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<AffirmationProvider>();
    final content = _contentController.text.trim();
    final category = _categoryController.text.trim().isEmpty ? 'Custom' : _categoryController.text.trim();

    final success = await provider.addCustomAffirmationWithReminder(
      content: content,
      category: category,
      enabled: _reminderEnabled,
      startHour: _startTime.hour,
      startMinute: _startTime.minute,
      endHour: _endTime.hour,
      endMinute: _endTime.minute,
      dailyCount: _dailyCount,
      selectedDays: _days.toList()..sort(),
    );

    if (!mounted) return;
    if (!success) {
      final err = context.read<AffirmationProvider>().error;
      final msg = err ?? 'Limit reached. You can only add up to 5 custom affirmations.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Custom affirmation saved')),
    );
    if (Navigator.of(context).canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Custom Affirmation'),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        children: [
          // Affirmation content card
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            decoration: AppTheme.cardDecoration,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Affirmation', style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppTheme.spacingS),
                  TextFormField(
                    controller: _contentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'e.g., I am focused, confident, and capable.',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter an affirmation' : null,
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  Text('Category', style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppTheme.spacingS),
                  TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      hintText: 'e.g., Confidence, Health, Career',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacingL),

          // Reminder configuration card
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            decoration: AppTheme.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Reminder',
                      style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Switch(
                      value: _reminderEnabled,
                      onChanged: (v) => setState(() => _reminderEnabled = v),
                    ),
                  ],
                ),

                const SizedBox(height: AppTheme.spacingS),

                // How many
                _StepperRow(
                  label: 'How many',
                  valueBuilder: () => '${_dailyCount}x',
                  onDecrement: () {
                    setState(() {
                      _dailyCount = (_dailyCount - 1).clamp(1, _maxAllowedCount());
                    });
                  },
                  onIncrement: () {
                    setState(() {
                      _dailyCount = (_dailyCount + 1).clamp(1, _maxAllowedCount());
                    });
                  },
                ),

                const Divider(height: AppTheme.spacingXL),

                // Start at
                _StepperRow(
                  label: 'Start at',
                  valueBuilder: () => _formatTime(_startTime),
                  onDecrement: () {
                    setState(() {
                      final m = (_startTime.hour * 60 + _startTime.minute - 15) % (24 * 60);
                      _startTime = TimeOfDay(hour: m ~/ 60, minute: m % 60);
                      _enforceCountCap();
                      _ensureEndAfterStart();
                    });
                  },
                  onIncrement: () {
                    setState(() {
                      final m = (_startTime.hour * 60 + _startTime.minute + 15) % (24 * 60);
                      _startTime = TimeOfDay(hour: m ~/ 60, minute: m % 60);
                      _enforceCountCap();
                      _ensureEndAfterStart();
                    });
                  },
                ),

                const Divider(height: AppTheme.spacingXL),

                // End at
                _StepperRow(
                  label: 'End at',
                  valueBuilder: () => _formatTime(_endTime),
                  onDecrement: () {
                    setState(() {
                      final total = (_endTime.hour * 60 + _endTime.minute - 15);
                      var minutes = (total % (24 * 60) + (24 * 60)) % (24 * 60);
                      _endTime = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
                      _ensureEndAfterStart();
                      _enforceCountCap();
                    });
                  },
                  onIncrement: () {
                    setState(() {
                      final minutesTotal = (_endTime.hour * 60 + _endTime.minute + 15) % (24 * 60);
                      _endTime = TimeOfDay(hour: minutesTotal ~/ 60, minute: minutesTotal % 60);
                      _ensureEndAfterStart();
                      _enforceCountCap();
                    });
                  },
                ),

                const SizedBox(height: AppTheme.spacingS),

                Text('Repeat', style: AppTheme.bodyMedium),
                const SizedBox(height: AppTheme.spacingS),
                Wrap(
                  spacing: AppTheme.spacingS,
                  runSpacing: AppTheme.spacingS,
                  children: [
                    for (final day in const [7,1,2,3,4,5,6]) // S M T W T F S
                      ChoiceChip(
                        label: SizedBox(
                          width: 28,
                          height: 28,
                          child: Center(
                            child: Text(
                              _getDayLetter(day),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                        selected: _days.contains(day),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _days.add(day);
                            } else {
                              _days.remove(day);
                            }
                          });
                        },
                        shape: const CircleBorder(),
                        selectedColor: AppTheme.primaryTeal.withOpacity(0.2),
                        labelStyle: Theme.of(context).textTheme.bodySmall,
                        showCheckmark: false,
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacingXL),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
