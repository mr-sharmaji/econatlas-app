import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../providers/providers.dart';
import '../widgets/about_content.dart';

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  static const int _unlockTapsRequired = 7;

  int _tapCount = 0;
  String _versionText = 'Version unavailable';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _versionText = '${info.version}+${info.buildNumber}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _versionText = 'Version unavailable');
    }
  }

  void _onVersionTap() {
    final messenger = ScaffoldMessenger.of(context);
    final unlocked = ref.read(developerOptionsUnlockedProvider);
    if (unlocked) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Developer options already unlocked.'),
          duration: Duration(milliseconds: 900),
        ),
      );
      return;
    }

    _tapCount += 1;
    final remaining = _unlockTapsRequired - _tapCount;
    if (remaining <= 0) {
      ref.read(developerOptionsUnlockedProvider.notifier).setUnlocked(true);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Developer options unlocked.'),
        ),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text('$remaining more taps to unlock Developer Options.'),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About EconAtlas')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const AboutContent(),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('App version'),
                  subtitle: Text(_versionText),
                  onTap: _onVersionTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
