import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/utils.dart';
import '../providers/market_providers.dart';
import '../providers/settings_providers.dart';

class FirstLaunchWelcome extends ConsumerStatefulWidget {
  const FirstLaunchWelcome({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FirstLaunchWelcome> createState() => _FirstLaunchWelcomeState();
}

class _FirstLaunchWelcomeState extends ConsumerState<FirstLaunchWelcome> {
  static final List<String> _watchlistOptions = <String>{
    ...Entities.indicesIndia,
    ...Entities.indicesUS,
    ...Entities.indicesEurope,
    ...Entities.indicesJapan,
    ...Entities.commodities,
    ...Entities.fx,
    ...Entities.bonds,
  }.toList(growable: false);

  static List<String> _onboardingDefaultWatchlist() {
    final defaults = <String>{...Entities.dashboardAssets};
    return _watchlistOptions.where(defaults.contains).toList(growable: false);
  }

  late final PageController _pageController;

  bool _isLoading = true;
  bool _showSetup = false;
  bool _isSaving = false;
  int _pageIndex = 0;
  List<String> _selectedWatchlist = _onboardingDefaultWatchlist();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadFirstLaunchState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadFirstLaunchState() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final seen = prefs.getBool(AppConstants.prefHasSeenWelcome) ?? false;

    if (!mounted) return;
    setState(() {
      _showSetup = !seen;
      _isLoading = false;
    });
  }

  Future<void> _finishSetup() async {
    setState(() => _isSaving = true);

    final watchlist = _selectedWatchlist.isEmpty
        ? _onboardingDefaultWatchlist()
        : [..._selectedWatchlist];
    try {
      await ref.read(watchlistProvider.notifier).save(watchlist);
    } catch (_) {
      // Keep setup non-blocking even when backend/watchlist API is temporarily unavailable.
    }

    await ref
        .read(sharedPreferencesProvider)
        .setBool(AppConstants.prefHasSeenWelcome, true);

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _showSetup = false;
    });
  }

  void _next() {
    if (_pageIndex >= _pages.length - 1) {
      _finishSetup();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_pageIndex == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _toggleWatchlistAsset(String asset, bool selected) {
    setState(() {
      if (selected) {
        if (!_selectedWatchlist.contains(asset)) {
          _selectedWatchlist = [..._selectedWatchlist, asset];
        }
      } else {
        _selectedWatchlist =
            _selectedWatchlist.where((a) => a != asset).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || !_showSetup) {
      return widget.child;
    }

    final isLast = _pageIndex == _pages.length - 1;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'Setup ${_pageIndex + 1}/${_pages.length}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _isSaving ? null : _finishSetup,
                      child: const Text('Skip'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: LinearProgressIndicator(
                  value: (_pageIndex + 1) / _pages.length,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) => setState(() => _pageIndex = index),
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    if (page.kind == _SetupPageKind.watchlist) {
                      return _WatchlistPage(
                        options: _watchlistOptions,
                        selected: _selectedWatchlist,
                        onToggle: _toggleWatchlistAsset,
                      );
                    }
                    return _SimpleIntroPage(page: page);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Row(
                  children: [
                    if (_pageIndex > 0)
                      OutlinedButton(
                        onPressed: _isSaving ? null : _back,
                        child: const Text('Back'),
                      )
                    else
                      const SizedBox(width: 72),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _next,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              isLast
                                  ? Icons.check_rounded
                                  : Icons.arrow_forward_rounded,
                            ),
                      label: Text(isLast ? 'Start' : 'Continue'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_SetupPageData> get _pages => const [
        _SetupPageData(
          kind: _SetupPageKind.intro,
          title: 'Welcome to EconAtlas',
          description:
              'Your daily market workspace for tracking signals, opportunities and risk in one app.',
          bullets: [
            'Overview shows key headlines, market sentiment, volatility pulse, institutional flows, and IPO tracker.',
            'Watchlist keeps your selected assets first so daily checks stay focused.',
            'Market gives live status, point and % change, and detailed charts for each asset.',
            'Economy tracks macro indicators for India, US, Europe, and Japan.',
            'Discover focuses on India with beginner-friendly Stock and Mutual Fund screening plus compare mode.',
            'Quick tools are always available from the floating action button.',
          ],
        ),
        _SetupPageData(
          kind: _SetupPageKind.watchlist,
          title: 'Choose watchlist assets',
          description:
              'Pick assets for your dashboard watchlist. You can edit this anytime.',
          bullets: [],
        ),
      ];
}

enum _SetupPageKind { intro, watchlist }

class _SetupPageData {
  const _SetupPageData({
    required this.kind,
    required this.title,
    required this.description,
    required this.bullets,
  });

  final _SetupPageKind kind;
  final String title;
  final String description;
  final List<String> bullets;
}

class _SimpleIntroPage extends StatelessWidget {
  const _SimpleIntroPage({required this.page});

  final _SetupPageData page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.auto_graph_rounded,
              color: theme.colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            page.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            page.description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          ...page.bullets.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      point,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _WatchlistPage extends StatelessWidget {
  const _WatchlistPage({
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final List<String> options;
  final List<String> selected;
  final void Function(String asset, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = <String, List<String>>{
      'Indices': [
        ...Entities.indicesIndia,
        ...Entities.indicesUS,
        ...Entities.indicesEurope,
        ...Entities.indicesJapan,
      ],
      'Commodities': [...Entities.commodities],
      'Currencies': [...Entities.fx],
      'Bonds': [...Entities.bonds],
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Default watchlist',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose what appears first on your dashboard.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ...groups.entries.map((entry) {
            final visibleAssets =
                entry.value.where((asset) => options.contains(asset)).toList();
            if (visibleAssets.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...visibleAssets.map((asset) {
                        final isSelected = selected.contains(asset);
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: isSelected,
                          title: Text(displayName(asset)),
                          controlAffinity: ListTileControlAffinity.trailing,
                          onChanged: (value) => onToggle(asset, value ?? false),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            );
          }),
          Text(
            '${selected.length} selected',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
