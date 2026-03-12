import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/constants.dart';
import '../../../core/error_utils.dart';
import '../../providers/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final unitSystem = ref.watch(unitSystemProvider);
    final chartTimezone = ref.watch(chartTimezoneProvider);
    final watchlistState = ref.watch(watchlistProvider);
    final developerUnlocked = ref.watch(developerOptionsUnlockedProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Price format',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set how prices are shown across market screens.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _FullWidthToggle<UnitSystem>(
                    selected: unitSystem,
                    compact: true,
                    options: const [
                      _ToggleChoice(
                        value: UnitSystem.indian,
                        label: 'INR',
                        icon: Icons.currency_rupee_rounded,
                      ),
                      _ToggleChoice(
                        value: UnitSystem.international,
                        label: 'USD',
                        icon: Icons.attach_money_rounded,
                      ),
                    ],
                    onChanged: (value) {
                      ref.read(unitSystemProvider.notifier).set(value);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    unitSystem == UnitSystem.indian
                        ? 'INR mode applies commodity conversions and market-standard INR formatting.'
                        : 'USD mode keeps international commodity units with market-standard formatting.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Timezone',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Used for absolute date and time labels app-wide.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _FullWidthToggle<ChartTimezone>(
                    selected: chartTimezone,
                    compact: true,
                    options: const [
                      _ToggleChoice(
                        value: ChartTimezone.deviceLocal,
                        label: 'Local',
                        icon: Icons.smartphone_rounded,
                      ),
                      _ToggleChoice(
                        value: ChartTimezone.ist,
                        label: 'IST',
                        icon: Icons.public_rounded,
                      ),
                      _ToggleChoice(
                        value: ChartTimezone.americaNewYork,
                        label: 'EST',
                        icon: Icons.travel_explore_rounded,
                      ),
                    ],
                    onChanged: (value) {
                      ref.read(chartTimezoneProvider.notifier).set(value);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Relative labels like "2h ago" remain relative.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _FullWidthToggle<ThemeMode>(
                    selected: themeMode,
                    compact: true,
                    options: const [
                      _ToggleChoice(
                        value: ThemeMode.dark,
                        label: 'Dark',
                        icon: Icons.dark_mode_rounded,
                      ),
                      _ToggleChoice(
                        value: ThemeMode.light,
                        label: 'Light',
                        icon: Icons.light_mode_rounded,
                      ),
                      _ToggleChoice(
                        value: ThemeMode.system,
                        label: 'System',
                        icon: Icons.settings_suggest_rounded,
                      ),
                    ],
                    onChanged: (value) {
                      ref.read(themeModeProvider.notifier).setThemeMode(value);
                    },
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.playlist_add_check_rounded),
                  title: const Text('Manage watchlist'),
                  subtitle: Text(
                    watchlistState.valueOrNull == null
                        ? 'Choose and reorder your tracked assets'
                        : '${watchlistState.valueOrNull!.length} selected assets',
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => context.push('/watchlist'),
                ),
                Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Colors.white.withValues(alpha: 0.06)),
                ListTile(
                  leading: const Icon(Icons.restore_rounded),
                  title: const Text('Reset watchlist to defaults'),
                  onTap: () =>
                      ref.read(watchlistProvider.notifier).resetToDefaults(),
                ),
              ],
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.feedback_outlined),
              title: const Text('Send feedback'),
              subtitle: const Text('Report issues or request improvements'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => _showFeedbackSheet(context, ref),
            ),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About EconAtlas'),
                  subtitle: const Text('App info, status guide, and version'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => context.push('/about'),
                ),
                if (developerUnlocked) ...[
                  Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Colors.white.withValues(alpha: 0.06)),
                  ListTile(
                    leading: const Icon(Icons.code_rounded),
                    title: const Text('Developer Options'),
                    subtitle: const Text('Diagnostics, backend URL, and logs'),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => context.push('/settings/developer'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _showFeedbackSheet(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    var category = 'bug';
    var submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) => Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Send feedback',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'bug', child: Text('Bug')),
                    DropdownMenuItem(
                        value: 'data_issue', child: Text('Data issue')),
                    DropdownMenuItem(
                        value: 'feature_request',
                        child: Text('Feature request')),
                    DropdownMenuItem(value: 'ux', child: Text('UX')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: submitting
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => category = value);
                        },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  enabled: !submitting,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Describe the issue or suggestion clearly',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed:
                          submitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: submitting
                          ? null
                          : () async {
                              final message = controller.text.trim();
                              if (message.length < 8) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Please enter at least 8 characters.'),
                                  ),
                                );
                                return;
                              }
                              setState(() => submitting = true);
                              try {
                                final pkg = await PackageInfo.fromPlatform();
                                final ds = ref.read(remoteDataSourceProvider);
                                await ds.submitFeedback(
                                  deviceId: ref.read(deviceIdProvider),
                                  category: category,
                                  message: message,
                                  appVersion:
                                      '${pkg.version}+${pkg.buildNumber}',
                                  platform:
                                      defaultTargetPlatform.name.toLowerCase(),
                                );
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Feedback sent. Thank you.'),
                                  ),
                                );
                              } catch (err) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(friendlyErrorMessage(err)),
                                  ),
                                );
                              } finally {
                                if (context.mounted) {
                                  setState(() => submitting = false);
                                }
                              }
                            },
                      icon: submitting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: const Text('Submit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ToggleChoice<T> {
  final T value;
  final String label;
  final IconData? icon;

  const _ToggleChoice({
    required this.value,
    required this.label,
    this.icon,
  });
}

class _FullWidthToggle<T> extends StatelessWidget {
  final T selected;
  final List<_ToggleChoice<T>> options;
  final ValueChanged<T> onChanged;
  final bool compact;

  const _FullWidthToggle({
    required this.selected,
    required this.options,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary.withValues(alpha: 0.34);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            Expanded(
              child: _FullWidthToggleButton<T>(
                option: options[i],
                selected: selected == options[i].value,
                compact: compact,
                selectedColor: selectedColor,
                onTap: () => onChanged(options[i].value),
              ),
            ),
            if (i != options.length - 1)
              Container(
                width: 1,
                height: compact ? 34 : 40,
                color: Colors.white10,
              ),
          ],
        ],
      ),
    );
  }
}

class _FullWidthToggleButton<T> extends StatelessWidget {
  final _ToggleChoice<T> option;
  final bool selected;
  final bool compact;
  final Color selectedColor;
  final VoidCallback onTap;

  const _FullWidthToggleButton({
    required this.option,
    required this.selected,
    required this.compact,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.all(3),
        padding: EdgeInsets.symmetric(
          vertical: compact ? 8 : 11,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected ? selectedColor : Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (option.icon != null) ...[
              Icon(
                option.icon,
                size: compact ? 14 : 16,
                color: selected ? Colors.white : Colors.white60,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                option.label,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: (compact
                        ? theme.textTheme.labelMedium
                        : theme.textTheme.titleSmall)
                    ?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
