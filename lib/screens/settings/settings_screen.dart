import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/user_provider.dart';
import '../../providers/affirmation_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/focus_areas_chips.dart';
import '../../models/custom_affirmation_reminder.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  Widget _buildRemindersCard() {
    return InkWell(
      onTap: () => context.push('/notification-settings'),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        decoration: AppTheme.cardDecoration,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.notifications_active,
                color: AppTheme.primaryTeal,
                size: 24,
              ),
            ),

            const SizedBox(width: AppTheme.spacingM),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reminders',
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Manage reminder frequency, time range, days and sound',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textLight,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.textLight,
            ),
          ],
        ),
      ),
    );
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer2<UserProvider, AffirmationProvider>(
          builder: (context, userProvider, affirmationProvider, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: CustomScrollView(
                slivers: [
                  // App Bar
                  SliverAppBar(
                    floating: true,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    expandedHeight: 80,
                    flexibleSpace: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingL,
                        vertical: AppTheme.spacingL,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Settings',
                            style: AppTheme.headingMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Content
                  SliverPadding(
                    padding: const EdgeInsets.all(AppTheme.spacingL),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Profile & Preferences Section
                        _buildSectionHeader('Profile & Preferences'),
                        const SizedBox(height: AppTheme.spacingM),
                        
                        _buildProfileCard(userProvider),
                        
                        const SizedBox(height: AppTheme.spacingXL),
                        
                        // Set Reminders
                        _buildSectionHeader('Set Reminders'),
                        const SizedBox(height: AppTheme.spacingM),
                        // Reminders entry (opens full reminders configuration screen)
                        _buildRemindersCard(),
                        const SizedBox(height: AppTheme.spacingXL),
                        
                        // Add New Affirmations Section
                        _buildSectionHeader('Add New Affirmations'),
                        const SizedBox(height: AppTheme.spacingM),
                        
                        _buildAddAffirmationCard(affirmationProvider),
                        
                        const SizedBox(height: AppTheme.spacingM),
                        
                        _buildManualAffirmationsCard(affirmationProvider),
                        
                        const SizedBox(height: AppTheme.spacingXL),
                        
                        // App Information Section
                        _buildSectionHeader('About'),
                        const SizedBox(height: AppTheme.spacingM),
                        
                        _buildAboutCard(),
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTheme.headingSmall.copyWith(
        color: AppTheme.textDark,
      ),
    );
  }

  Widget _buildProfileCard(UserProvider userProvider) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Age Group: ${userProvider.displayAgeGroup}',
                style: AppTheme.bodyMedium,
              ),
              const Spacer(),
              IconButton(
                onPressed: () => context.push('/profile-settings'),
                icon: const Icon(Icons.edit),
                iconSize: 20,
                color: AppTheme.textLight,
              ),
            ],
          ),
          
          Text(
            'Gender: ${userProvider.displayGender}',
            style: AppTheme.bodyMedium,
          ),
          
          const SizedBox(height: AppTheme.spacingM),
          
          Text(
            'Focus Areas',
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingS),
          
          FocusAreasChips(
            focusAreas: userProvider.displayFocusAreas,
            showAll: true,
          ),
        ],
      ),
    );
  }

  // Notification card removed from Settings; configuration now lives under
  // the dedicated Notifications tab/screen.

  Widget _buildAddAffirmationCard(AffirmationProvider affirmationProvider) {
    final used = affirmationProvider.affirmations.where((a) => a.isCustom).length;
    final limit = 5;
    return InkWell(
      onTap: () => context.push('/add-custom-affirmation'),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        decoration: AppTheme.cardDecoration,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.secondaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.add,
                color: AppTheme.secondaryPurple,
                size: 24,
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add New Affirmation',
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Create your own personalized affirmations • $used/$limit used',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textLight,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.textLight,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualAffirmationsCard(AffirmationProvider affirmationProvider) {
    // Get custom affirmations
    final customAffirmations = affirmationProvider.affirmations
        .where((a) => a.isCustom)
        .take(2)
        .toList();

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manual Affirmations',
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingM),
          
          if (customAffirmations.isEmpty)
            Text(
              'No custom affirmations yet. Tap the + button above to add your first one.',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textLight,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ...customAffirmations.map((affirmation) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
              child: Row(
                children: [
                  const Icon(
                    Icons.format_quote,
                    size: 16,
                    color: AppTheme.textLight,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Text(
                      affirmation.content,
                      style: AppTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      _showEditCustomAffirmationSheet(context, affirmation.id, affirmation.content, affirmation.category);
                    },
                    icon: const Icon(Icons.edit),
                    iconSize: 16,
                    color: AppTheme.textLight,
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  void _showEditCustomAffirmationSheet(BuildContext context, String id, String content, String category) {
    final contentController = TextEditingController(text: content);
    final categoryController = TextEditingController(text: category);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return FutureBuilder<CustomAffirmationReminder?>(
          future: context.read<AffirmationProvider>().getCustomReminderById(id),
          builder: (context, snap) {
            final initial = snap.data;
            // Hoisted state for the sheet – persists across setSheetState calls
            bool seeded = false;
            bool reminderEnabled = true;
            TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
            TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);
            int dailyCount = 4;
            final Set<int> days = {1,2,3,4,5,6,7};

            return StatefulBuilder(
              builder: (context, setSheetState) {
                if (!seeded && initial != null) {
                  reminderEnabled = initial.enabled;
                  startTime = TimeOfDay(hour: initial.startHour, minute: initial.startMinute);
                  endTime = TimeOfDay(hour: initial.endHour, minute: initial.endMinute);
                  dailyCount = initial.dailyCount;
                  days
                    ..clear()
                    ..addAll(initial.selectedDays);
                  seeded = true;
                }

                int minutesOf(TimeOfDay t) => t.hour * 60 + t.minute;
                void ensureEndAfterStart() {
                  final s = minutesOf(startTime);
                  final e = minutesOf(endTime);
                  if (e <= s) {
                    final newEnd = (s + 15) % (24 * 60);
                    endTime = TimeOfDay(hour: newEnd ~/ 60, minute: newEnd % 60);
                  }
                }
                int maxAllowedCount() {
                  final total = (minutesOf(endTime) - minutesOf(startTime)).clamp(0, 24 * 60);
                  final maxByFive = (total ~/ 5);
                  return maxByFive.clamp(1, 96);
                }
                void enforceCountCap() {
                  final max = maxAllowedCount();
                  if (dailyCount > max) dailyCount = max;
                  if (dailyCount < 1) dailyCount = 1;
                }

                String formatTime(TimeOfDay t) {
                  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
                  final m = t.minute.toString().padLeft(2, '0');
                  final p = t.period == DayPeriod.am ? 'AM' : 'PM';
                  return '$h:$m $p';
                }
                String dayLetter(int d) {
                  switch (d) {
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

                return Padding(
                  padding: EdgeInsets.only(
                    left: AppTheme.spacingL,
                    right: AppTheme.spacingL,
                    top: AppTheme.spacingL,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + AppTheme.spacingL,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit affirmation', style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: AppTheme.spacingM),
                        TextField(
                          controller: contentController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Affirmation',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        TextField(
                          controller: categoryController,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingL),

                        // Reminder section
                        Container(
                          padding: const EdgeInsets.all(AppTheme.spacingL),
                          decoration: AppTheme.cardDecoration,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('Reminder', style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                                  const Spacer(),
                                  Switch(
                                    value: reminderEnabled,
                                    onChanged: (v) => setSheetState(() => reminderEnabled = v),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacingS),
                              // How many
                              Row(
                                children: [
                                  SizedBox(
                                    width: 160,
                                    child: Text('How many', style: AppTheme.bodyMedium),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: () => setSheetState(() { dailyCount = (dailyCount - 1).clamp(1, maxAllowedCount()); }),
                                  ),
                                  Expanded(
                                    child: Center(child: Text('${dailyCount}x')),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () => setSheetState(() { dailyCount = (dailyCount + 1).clamp(1, maxAllowedCount()); }),
                                  ),
                                ],
                              ),
                              const Divider(),
                              // Start at
                              Row(
                                children: [
                                  SizedBox(width: 160, child: Text('Start at', style: AppTheme.bodyMedium)),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: () => setSheetState(() {
                                      final m = (startTime.hour * 60 + startTime.minute - 15) % (24 * 60);
                                      startTime = TimeOfDay(hour: m ~/ 60, minute: m % 60);
                                      enforceCountCap();
                                      ensureEndAfterStart();
                                    }),
                                  ),
                                  Expanded(child: Center(child: Text(formatTime(startTime)))),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () => setSheetState(() {
                                      final m = (startTime.hour * 60 + startTime.minute + 15) % (24 * 60);
                                      startTime = TimeOfDay(hour: m ~/ 60, minute: m % 60);
                                      enforceCountCap();
                                      ensureEndAfterStart();
                                    }),
                                  ),
                                ],
                              ),
                              const Divider(),
                              // End at
                              Row(
                                children: [
                                  SizedBox(width: 160, child: Text('End at', style: AppTheme.bodyMedium)),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: () => setSheetState(() {
                                      final total = (endTime.hour * 60 + endTime.minute - 15);
                                      final minutes = (total % (24 * 60) + (24 * 60)) % (24 * 60);
                                      endTime = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
                                      ensureEndAfterStart();
                                      enforceCountCap();
                                    }),
                                  ),
                                  Expanded(child: Center(child: Text(formatTime(endTime)))),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () => setSheetState(() {
                                      final minutes = (endTime.hour * 60 + endTime.minute + 15) % (24 * 60);
                                      endTime = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
                                      ensureEndAfterStart();
                                      enforceCountCap();
                                    }),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacingS),
                              Text('Repeat', style: AppTheme.bodyMedium),
                              const SizedBox(height: AppTheme.spacingS),
                              Wrap(
                                spacing: AppTheme.spacingS,
                                runSpacing: AppTheme.spacingS,
                                children: [
                                  for (final d in const [7,1,2,3,4,5,6])
                                    ChoiceChip(
                                      label: SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: Center(child: Text(dayLetter(d))),
                                      ),
                                      selected: days.contains(d),
                                      onSelected: (sel) => setSheetState(() {
                                        if (sel) {
                                          days.add(d);
                                        } else {
                                          days.remove(d);
                                        }
                                      }),
                                      shape: const CircleBorder(),
                                      selectedColor: AppTheme.primaryTeal.withOpacity(0.2),
                                      showCheckmark: false,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppTheme.spacingL),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final updatedContent = contentController.text.trim();
                                  final updatedCategory = categoryController.text.trim().isEmpty
                                      ? category
                                      : categoryController.text.trim();
                                  final reminder = CustomAffirmationReminder(
                                    affirmationId: id,
                                    enabled: reminderEnabled,
                                    startHour: startTime.hour,
                                    startMinute: startTime.minute,
                                    endHour: endTime.hour,
                                    endMinute: endTime.minute,
                                    dailyCount: dailyCount,
                                    selectedDays: days.toList()..sort(),
                                  );
                                  final ok = await context.read<AffirmationProvider>().updateCustomAffirmation(
                                        id: id,
                                        content: updatedContent.isEmpty ? content : updatedContent,
                                        category: updatedCategory,
                                        reminder: reminder,
                                      );
                                  if (!mounted) return;
                                  Navigator.of(ctx).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(ok ? 'Affirmation updated' : 'Failed to update')),
                                  );
                                },
                                icon: const Icon(Icons.save),
                                label: const Text('Save'),
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingM),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (dctx) => AlertDialog(
                                      title: const Text('Delete affirmation?'),
                                      content: const Text('This will remove the affirmation and its reminder.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Cancel')),
                                        TextButton(onPressed: () => Navigator.of(dctx).pop(true), child: const Text('Delete')),
                                      ],
                                    ),
                                  );
                                  if (confirmed != true) return;
                                  final ok = await context.read<AffirmationProvider>().deleteCustomAffirmationById(id);
                                  if (!mounted) return;
                                  Navigator.of(ctx).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(ok ? 'Affirmation deleted' : 'Failed to delete')),
                                  );
                                },
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Delete'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAboutCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: AppTheme.spacingM),
              
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BePositive!',
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Version 1.0.0',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacingM),
          
          Text(
            'Your daily source of personalized motivation and positivity. All data is stored locally on your device for complete privacy.',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textLight,
              height: 1.4,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    // Show privacy policy
                  },
                  child: const Text('Privacy Policy'),
                ),
              ),
              
              const SizedBox(width: AppTheme.spacingM),
              
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    // Show about dialog
                  },
                  child: const Text('About'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
