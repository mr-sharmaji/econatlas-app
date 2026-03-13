import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/error_utils.dart';
import '../../../core/utils.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';

class DeveloperOptionsScreen extends ConsumerStatefulWidget {
  const DeveloperOptionsScreen({super.key});

  @override
  ConsumerState<DeveloperOptionsScreen> createState() =>
      _DeveloperOptionsScreenState();
}

class _DeveloperOptionsScreenState
    extends ConsumerState<DeveloperOptionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _tailTimer;

  bool _tailEnabled = true;
  bool _loadingLogs = false;
  bool _loadingFeedback = false;
  bool _loadingJobs = false;
  List<String> _jobs = const [];
  final Map<String, String> _jobStatus = {}; // jobName → 'enqueued' | 'error' | 'loading'
  int _latestLogId = 0;
  String _minLevel = '';
  String? _logsState;
  String? _logsErrorMessage;
  String? _feedbackState;
  String? _feedbackErrorMessage;
  List<OpsLogEntry> _logs = const [];
  List<FeedbackSubmission> _feedbacks = const [];

  @override
  void initState() {
    super.initState();
    _loadLogs(fullReload: true);
    _loadFeedbackSubmissions();
    _loadJobsList();
    _syncTailTimer();
  }

  @override
  void dispose() {
    _tailTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _syncTailTimer() {
    _tailTimer?.cancel();
    if (!_tailEnabled) return;
    _tailTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _loadLogs(fullReload: false),
    );
  }

  Future<void> _loadLogs({required bool fullReload}) async {
    if (_loadingLogs) return;
    setState(() {
      _loadingLogs = true;
      if (fullReload) {
        _logsState = null;
        _logsErrorMessage = null;
      }
    });

    try {
      final ds = ref.read(remoteDataSourceProvider);
      final response = await ds.getOpsLogs(
        limit: 120,
        afterId: (fullReload || !_tailEnabled || _latestLogId <= 0)
            ? null
            : _latestLogId,
        minLevel: _minLevel.isEmpty ? null : _minLevel,
        contains: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );
      setState(() {
        _logsState = null;
        _logsErrorMessage = null;
        if (!fullReload && _tailEnabled && _latestLogId > 0) {
          _logs = [..._logs, ...response.entries];
          if (_logs.length > 300) {
            _logs = _logs.sublist(_logs.length - 300);
          }
        } else {
          _logs = response.entries;
        }
        _latestLogId = response.latestId;
      });
    } on DioException catch (err) {
      final code = err.response?.statusCode;
      setState(() {
        if (code == 403) {
          _logsState = 'restricted';
          _logsErrorMessage = 'Ops logs endpoint is restricted.';
        } else if (code == 404) {
          _logsState = 'disabled';
          _logsErrorMessage = 'Ops logs endpoint is disabled on backend.';
        } else {
          _logsState = 'error';
          _logsErrorMessage = friendlyErrorMessage(err);
        }
      });
    } catch (err) {
      setState(() {
        _logsState = 'error';
        _logsErrorMessage = err.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loadingLogs = false);
      }
    }
  }

  Future<void> _loadFeedbackSubmissions() async {
    if (_loadingFeedback) return;
    setState(() {
      _loadingFeedback = true;
      _feedbackState = null;
      _feedbackErrorMessage = null;
    });

    try {
      final ds = ref.read(remoteDataSourceProvider);
      final response = await ds.getFeedbackSubmissions(limit: 120);
      setState(() {
        _feedbackState = null;
        _feedbackErrorMessage = null;
        _feedbacks = response.entries;
      });
    } on DioException catch (err) {
      final code = err.response?.statusCode;
      setState(() {
        if (code == 403) {
          _feedbackState = 'restricted';
          _feedbackErrorMessage = 'Feedback list access is restricted.';
        } else if (code == 404) {
          _feedbackState = 'disabled';
          _feedbackErrorMessage = 'Feedback list endpoint is unavailable.';
        } else {
          _feedbackState = 'error';
          _feedbackErrorMessage = friendlyErrorMessage(err);
        }
      });
    } catch (err) {
      setState(() {
        _feedbackState = 'error';
        _feedbackErrorMessage = err.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loadingFeedback = false);
      }
    }
  }

  Future<void> _loadJobsList() async {
    if (_loadingJobs) return;
    setState(() => _loadingJobs = true);
    try {
      final ds = ref.read(remoteDataSourceProvider);
      final jobs = await ds.listJobs();
      if (mounted) setState(() => _jobs = jobs);
    } catch (err) {
      debugPrint('Failed to load jobs list: $err');
    } finally {
      if (mounted) setState(() => _loadingJobs = false);
    }
  }

  Future<void> _triggerJob(String jobName) async {
    setState(() => _jobStatus[jobName] = 'loading');
    try {
      final ds = ref.read(remoteDataSourceProvider);
      final result = await ds.triggerJob(jobName);
      if (mounted) {
        setState(() => _jobStatus[jobName] = result['status'] as String? ?? 'enqueued');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$jobName: ${_jobStatus[jobName]}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        String detail = err.toString();
        if (err is DioException) {
          final resp = err.response;
          if (resp != null) {
            detail = '${resp.statusCode}: ${resp.data}';
          } else {
            detail = err.message ?? err.type.name;
          }
        }
        setState(() => _jobStatus[jobName] = 'error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to trigger $jobName — $detail'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseUrl = ref.watch(baseUrlProvider);
    final dataHealth = ref.watch(dataHealthProvider);
    final marketStatus = ref.watch(marketStatusProvider).valueOrNull;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Developer Options')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const _SectionTitle(title: 'Connection'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: const Text('Backend URL'),
                  subtitle: Text(
                    baseUrl,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                      fontFamily: 'monospace',
                    ),
                  ),
                  trailing: const Icon(Icons.edit_outlined, size: 20),
                  onTap: () => _showBaseUrlDialog(context, ref, baseUrl),
                ),
                Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Colors.white.withValues(alpha: 0.06)),
                ListTile(
                  leading: const Icon(Icons.restore_rounded),
                  title: const Text('Reset backend URL'),
                  subtitle: const Text('Use production API endpoint'),
                  onTap: () => ref
                      .read(baseUrlProvider.notifier)
                      .setBaseUrl(AppConstants.defaultBaseUrl),
                ),
              ],
            ),
          ),
          const _SectionTitle(title: 'Diagnostics'),
          Card(
            child: dataHealth.when(
              loading: () => const ListTile(
                leading: CircularProgressIndicator(strokeWidth: 2),
                title: Text('Checking backend diagnostics...'),
              ),
              error: (err, _) => ListTile(
                leading: const Icon(Icons.error_outline_rounded),
                title: const Text('Diagnostics unavailable'),
                subtitle: Text(friendlyErrorMessage(err)),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () {
                    ref.invalidate(dataHealthProvider);
                    ref.invalidate(marketStatusProvider);
                  },
                ),
              ),
              data: (health) => Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.circle_notifications_outlined),
                    title: const Text('Market status'),
                    subtitle: Text(
                      marketStatus == null
                          ? 'Status unavailable'
                          : _marketStatusSummary(marketStatus),
                    ),
                  ),
                  Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Colors.white.withValues(alpha: 0.06)),
                  ListTile(
                    leading: const Icon(Icons.health_and_safety_outlined),
                    title: const Text('Backend data health'),
                    subtitle: Text(
                      'Assets: ${health.totalAssets} · Stale: ${health.staleAssets} · Avg lag: ${health.avgLatencySeconds?.toStringAsFixed(0) ?? '-'}s',
                    ),
                  ),
                  Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Colors.white.withValues(alpha: 0.06)),
                  ListTile(
                    leading: const Icon(Icons.refresh_rounded),
                    title: const Text('Refresh diagnostics'),
                    subtitle: const Text('Re-check market status and health'),
                    onTap: () {
                      ref.invalidate(dataHealthProvider);
                      ref.invalidate(marketStatusProvider);
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_jobs.isNotEmpty) ...[
            const _SectionTitle(title: 'Background Jobs'),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Trigger jobs manually',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Refresh job list',
                          onPressed: _loadJobsList,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _jobs.map((job) {
                        final status = _jobStatus[job];
                        final isLoading = status == 'loading';
                        return ActionChip(
                          avatar: isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  status == 'enqueued' || status == 'already_queued'
                                      ? Icons.check_circle_outline
                                      : status == 'error'
                                          ? Icons.error_outline
                                          : Icons.play_arrow_rounded,
                                  size: 18,
                                  color: status == 'enqueued' || status == 'already_queued'
                                      ? Colors.greenAccent
                                      : status == 'error'
                                          ? Colors.redAccent
                                          : null,
                                ),
                          label: Text(
                            job.replaceAll('_', ' '),
                            style: theme.textTheme.labelSmall,
                          ),
                          onPressed: isLoading ? null : () => _triggerJob(job),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const _SectionTitle(title: 'Ops logs'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Backend runtime logs',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Switch.adaptive(
                        value: _tailEnabled,
                        onChanged: (value) {
                          setState(() => _tailEnabled = value);
                          _syncTailTimer();
                          if (value) {
                            _loadLogs(fullReload: false);
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Refresh logs',
                        onPressed: () => _loadLogs(fullReload: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: _minLevel,
                          decoration: const InputDecoration(
                            labelText: 'Min level',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('All')),
                            DropdownMenuItem(
                                value: 'INFO', child: Text('Info')),
                            DropdownMenuItem(
                                value: 'WARNING', child: Text('Warning')),
                            DropdownMenuItem(
                                value: 'ERROR', child: Text('Error')),
                          ],
                          onChanged: (value) {
                            setState(() => _minLevel = value ?? '');
                            _loadLogs(fullReload: true);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Search message',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.search, size: 18),
                              onPressed: () => _loadLogs(fullReload: true),
                            ),
                          ),
                          onSubmitted: (_) => _loadLogs(fullReload: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loadingLogs && _logs.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (_logsState == 'restricted' ||
                      _logsState == 'disabled')
                    _logsStatusCard(
                      context: context,
                      icon: _logsState == 'restricted'
                          ? Icons.lock_outline_rounded
                          : Icons.toggle_off_rounded,
                      title: _logsState == 'restricted'
                          ? 'Logs access restricted'
                          : 'Logs endpoint disabled',
                      subtitle:
                          _logsErrorMessage ?? 'Ops logs are unavailable.',
                    )
                  else if (_logsState == 'error')
                    _logsStatusCard(
                      context: context,
                      icon: Icons.error_outline_rounded,
                      title: 'Unable to load logs',
                      subtitle: _logsErrorMessage ?? 'Unknown error',
                    )
                  else if (_logs.isEmpty)
                    _logsStatusCard(
                      context: context,
                      icon: Icons.inbox_outlined,
                      title: 'No logs',
                      subtitle: 'No log entries match the current filter.',
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _logs.length,
                      separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.06)),
                      itemBuilder: (context, index) {
                        final row = _logs[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          title: Text(
                            '[${row.level}] ${row.message}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.94),
                            ),
                          ),
                          subtitle: Text(
                            '#${row.id} · ${Formatters.dateTime(row.timestamp)} · ${row.logger}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white54,
                            ),
                          ),
                          leading: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _levelColor(row.level),
                              shape: BoxShape.circle,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            tooltip: 'Copy row',
                            onPressed: () async {
                              final payload =
                                  '[${row.level}] ${row.logger} #${row.id} ${row.message}';
                              await Clipboard.setData(
                                  ClipboardData(text: payload));
                              if (!mounted) return;
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text('Log row copied'),
                                  duration: Duration(milliseconds: 900),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const _SectionTitle(title: 'User feedback'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Recent feedback submissions',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Refresh feedback',
                        onPressed: _loadFeedbackSubmissions,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_loadingFeedback && _feedbacks.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (_feedbackState == 'restricted' ||
                      _feedbackState == 'disabled')
                    _logsStatusCard(
                      context: context,
                      icon: _feedbackState == 'restricted'
                          ? Icons.lock_outline_rounded
                          : Icons.toggle_off_rounded,
                      title: _feedbackState == 'restricted'
                          ? 'Feedback access restricted'
                          : 'Feedback endpoint unavailable',
                      subtitle: _feedbackErrorMessage ??
                          'Feedback submissions are unavailable.',
                    )
                  else if (_feedbackState == 'error')
                    _logsStatusCard(
                      context: context,
                      icon: Icons.error_outline_rounded,
                      title: 'Unable to load feedback',
                      subtitle: _feedbackErrorMessage ?? 'Unknown error',
                    )
                  else if (_feedbacks.isEmpty)
                    _logsStatusCard(
                      context: context,
                      icon: Icons.inbox_outlined,
                      title: 'No feedback yet',
                      subtitle: 'No user submissions found.',
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _feedbacks.length,
                      separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.06)),
                      itemBuilder: (context, index) {
                        final row = _feedbacks[index];
                        final meta = <String>[
                          _feedbackCategoryLabel(row.category),
                          if ((row.appVersion ?? '').trim().isNotEmpty)
                            row.appVersion!.trim(),
                          if ((row.platform ?? '').trim().isNotEmpty)
                            row.platform!.trim(),
                        ].join(' · ');
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          title: Text(
                            row.message,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.94),
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${Formatters.dateTime(row.createdAt)} · ${row.deviceId}${meta.isEmpty ? '' : ' · $meta'}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white54,
                            ),
                          ),
                          leading:
                              const Icon(Icons.feedback_outlined, size: 18),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            tooltip: 'Copy row',
                            onPressed: () async {
                              final payload =
                                  '[${row.category}] ${row.deviceId} ${row.message}';
                              await Clipboard.setData(
                                  ClipboardData(text: payload));
                              if (!mounted) return;
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text('Feedback row copied'),
                                  duration: Duration(milliseconds: 900),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const _SectionTitle(title: 'Access'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Hide Developer Options'),
              subtitle:
                  const Text('You can re-enable it by tapping app version 7x'),
              onTap: () {
                ref
                    .read(developerOptionsUnlockedProvider.notifier)
                    .setUnlocked(false);
                Navigator.of(context).maybePop();
              },
            ),
          ),
        ],
      ),
    );
  }

  String _feedbackCategoryLabel(String value) {
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'data_issue':
        return 'Data issue';
      case 'feature_request':
        return 'Feature request';
      default:
        return _titleCase(normalized);
    }
  }

  String _titleCase(String value) {
    final cleaned = value.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return value;
    return cleaned
        .split(RegExp(r'\s+'))
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _marketStatusSummary(MarketStatus status) {
    return 'India: ${status.indiaOpen ? 'Open' : 'Closed'} · '
        'US: ${status.usOpen ? 'Open' : 'Closed'} · '
        'Europe: ${status.europeOpen ? 'Open' : 'Closed'} · '
        'Japan: ${status.japanOpen ? 'Open' : 'Closed'}\n'
        'Currencies: ${status.fxOpen ? 'Open' : 'Closed'} · '
        'Commodities: ${status.commoditiesOpen ? 'Open' : 'Closed'} · '
        'Gift Nifty: ${status.giftNiftyOpen ? 'Open' : 'Closed'}';
  }

  Color _levelColor(String level) {
    switch (level.toUpperCase()) {
      case 'ERROR':
      case 'CRITICAL':
        return Colors.redAccent;
      case 'WARNING':
        return Colors.amber;
      default:
        return Colors.greenAccent;
    }
  }

  Widget _logsStatusCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBaseUrlDialog(
      BuildContext context, WidgetRef ref, String currentUrl) {
    final controller = TextEditingController(text: currentUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backend URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://api.velqon.xyz',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                ref.read(baseUrlProvider.notifier).setBaseUrl(url);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white38,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
