import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error_utils.dart';
import '../../../core/utils.dart';
import '../../../data/models/asset_catalog.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final watchlistAsync = ref.watch(watchlistProvider);
    final catalogAsync = ref.watch(assetCatalogProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Watchlist'),
        actions: [
          IconButton(
            tooltip: 'Reset defaults',
            icon: const Icon(Icons.restore_rounded),
            onPressed: () =>
                ref.read(watchlistProvider.notifier).resetToDefaults(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(watchlistProvider.notifier).load();
          // forceRefreshAssetCatalog clears the cache key so the
          // provider hits the network instead of returning cached
          // data instantly via its background-microtask path.
          await forceRefreshAssetCatalog(ref);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          children: [
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search assets',
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),
            watchlistAsync.when(
              loading: () => const ShimmerCard(height: 110),
              error: (err, _) => ErrorView(
                message: friendlyErrorMessage(err),
                onRetry: () => ref.read(watchlistProvider.notifier).load(),
              ),
              data: (assets) => _selectedSection(context, assets),
            ),
            const SizedBox(height: 12),
            catalogAsync.when(
              loading: () => const ShimmerList(itemCount: 6, itemHeight: 70),
              error: (err, _) => ErrorView(
                message: friendlyErrorMessage(err),
                onRetry: () => ref.invalidate(assetCatalogProvider),
              ),
              data: (catalog) {
                final selected = watchlistAsync.valueOrNull ?? const <String>[];
                final filtered = catalog.assets.where((item) {
                  if (_query.isEmpty) return true;
                  final name = item.asset.toLowerCase();
                  final region = item.region.toLowerCase();
                  return name.contains(_query) || region.contains(_query);
                }).toList()
                  ..sort((a, b) => a.priorityRank.compareTo(b.priorityRank));
                return _catalogSection(context, filtered, selected);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectedSection(BuildContext context, List<String> assets) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected (${assets.length})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (assets.isEmpty)
              Text(
                'No assets selected yet.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: assets.length,
                onReorder: (oldIndex, newIndex) => ref
                    .read(watchlistProvider.notifier)
                    .reorder(oldIndex, newIndex),
                itemBuilder: (context, index) {
                  final asset = assets[index];
                  return ListTile(
                    key: ValueKey('selected-$asset'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.drag_handle_rounded),
                    title: Text(displayName(asset)),
                    trailing: IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () =>
                          ref.read(watchlistProvider.notifier).toggle(asset),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _catalogSection(BuildContext context, List<AssetCatalogItem> catalog,
      List<String> selected) {
    final theme = Theme.of(context);
    final grouped = <String, List<AssetCatalogItem>>{};
    String categoryFor(AssetCatalogItem item) {
      switch (item.instrumentType) {
        case 'index':
          return 'Indices';
        case 'commodity':
          return 'Commodities';
        case 'crypto':
          return 'Crypto';
        case 'currency':
          return 'Currencies';
        case 'bond_yield':
          return 'Bonds';
        default:
          return 'Other';
      }
    }

    for (final item in catalog) {
      final key = categoryFor(item);
      grouped.putIfAbsent(key, () => []).add(item);
    }

    final orderedKeys = grouped.keys.toList()
      ..sort((a, b) {
        const order = [
          'Indices',
          'Commodities',
          'Crypto',
          'Currencies',
          'Bonds',
          'Other',
        ];
        final ai = order.indexOf(a);
        final bi = order.indexOf(b);
        if (ai == -1 && bi == -1) return a.compareTo(b);
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return ai.compareTo(bi);
      });

    return Column(
      children: orderedKeys.map((region) {
        final items = grouped[region]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    region,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...items.map((item) {
                    final isSelected = selected.contains(item.asset);
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: isSelected,
                      title: Text(displayName(item.asset)),
                      controlAffinity: ListTileControlAffinity.trailing,
                      onChanged: (_) => ref
                          .read(watchlistProvider.notifier)
                          .toggle(item.asset),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
