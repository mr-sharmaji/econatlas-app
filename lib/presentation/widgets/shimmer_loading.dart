import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerCard extends StatelessWidget {
  final double height;
  final double? width;

  const ShimmerCard({
    super.key,
    this.height = 100,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF21262D) : Colors.grey.shade300,
      highlightColor: isDark ? const Color(0xFF30363D) : Colors.grey.shade100,
      child: Container(
        height: height,
        width: width,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class ShimmerList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const ShimmerList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 100,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (context, index) => ShimmerCard(height: itemHeight),
    );
  }
}

/// Shimmer skeleton for the Discover home feed (search + chips + horizontal sections).
class ShimmerDiscoverHome extends StatelessWidget {
  const ShimmerDiscoverHome({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF21262D) : Colors.grey.shade300;
    final highlight = isDark ? const Color(0xFF30363D) : Colors.grey.shade100;

    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(h / 2),
          ),
        );

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Search bar placeholder
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 16),
          // Chip row placeholder
          Row(children: [
            bar(70, 28),
            const SizedBox(width: 8),
            bar(90, 28),
            const SizedBox(width: 8),
            bar(80, 28),
          ]),
          const SizedBox(height: 24),
          // Section title + horizontal cards (×3)
          for (int i = 0; i < 3; i++) ...[
            bar(140, 16),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: Row(children: [
                for (int j = 0; j < 3; j++) ...[
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: j < 2 ? 8 : 0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

/// Shimmer skeleton for stock detail screen (title + chart + metrics).
class ShimmerStockDetail extends StatelessWidget {
  const ShimmerStockDetail({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF21262D) : Colors.grey.shade300;
    final highlight = isDark ? const Color(0xFF30363D) : Colors.grey.shade100;

    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(h / 2),
          ),
        );

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + price
            bar(180, 20),
            const SizedBox(height: 8),
            bar(120, 14),
            const SizedBox(height: 24),
            // Chart placeholder
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 16),
            // Period chips
            Row(children: [
              for (int i = 0; i < 5; i++) ...[
                bar(48, 28),
                if (i < 4) const SizedBox(width: 8),
              ],
            ]),
            const SizedBox(height: 24),
            // Metrics grid (2×3)
            for (int i = 0; i < 3; i++) ...[
              Row(children: [
                Expanded(child: bar(double.infinity, 48)),
                const SizedBox(width: 12),
                Expanded(child: bar(double.infinity, 48)),
              ]),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shimmer skeleton for mutual fund detail screen.
class ShimmerMfDetail extends StatelessWidget {
  const ShimmerMfDetail({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF21262D) : Colors.grey.shade300;
    final highlight = isDark ? const Color(0xFF30363D) : Colors.grey.shade100;

    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(h / 2),
          ),
        );

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fund name
            bar(240, 18),
            const SizedBox(height: 8),
            bar(160, 14),
            const SizedBox(height: 24),
            // Chart placeholder
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 16),
            // Returns row
            Row(children: [
              for (int i = 0; i < 3; i++) ...[
                Expanded(child: bar(double.infinity, 56)),
                if (i < 2) const SizedBox(width: 12),
              ],
            ]),
            const SizedBox(height: 24),
            // Info rows
            for (int i = 0; i < 4; i++) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [bar(100, 14), bar(60, 14)],
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline shimmer row for pagination loading.
class ShimmerInlineRow extends StatelessWidget {
  final double height;
  const ShimmerInlineRow({super.key, this.height = 80});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF21262D) : Colors.grey.shade300,
      highlightColor: isDark ? const Color(0xFF30363D) : Colors.grey.shade100,
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Shimmer skeleton for market detail screen (verdict + header + chart + range + tags).
class ShimmerMarketDetail extends StatelessWidget {
  const ShimmerMarketDetail({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF21262D) : Colors.grey.shade300;
    final highlight = isDark ? const Color(0xFF30363D) : Colors.grey.shade100;

    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(h / 2),
          ),
        );

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Verdict card
            Container(
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(height: 12),
            // Display name
            bar(200, 22),
            const SizedBox(height: 8),
            // Chips row
            Row(children: [
              bar(60, 24),
              const SizedBox(width: 8),
              bar(80, 24),
              const SizedBox(width: 8),
              bar(40, 24),
            ]),
            const SizedBox(height: 16),
            // Price + change
            Row(children: [
              bar(140, 28),
              const SizedBox(width: 10),
              bar(70, 24),
            ]),
            const SizedBox(height: 4),
            bar(120, 12),
            const SizedBox(height: 20),
            // Period chips
            Row(children: [
              for (int i = 0; i < 8; i++) ...[
                bar(36, 28),
                if (i < 7) const SizedBox(width: 8),
              ],
            ]),
            const SizedBox(height: 12),
            // Chart placeholder
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 14),
            // Range card
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(height: 14),
            // Tags row
            Row(children: [
              bar(80, 28),
              const SizedBox(width: 8),
              bar(100, 28),
              const SizedBox(width: 8),
              bar(70, 28),
            ]),
            const SizedBox(height: 14),
            // Score stats row
            Row(children: [
              for (int i = 0; i < 3; i++) ...[
                Expanded(child: bar(double.infinity, 56)),
                if (i < 2) const SizedBox(width: 12),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}

class ShimmerHorizontalList extends StatelessWidget {
  final int itemCount;
  final double itemWidth;
  final double itemHeight;

  const ShimmerHorizontalList({
    super.key,
    this.itemCount = 4,
    this.itemWidth = 150,
    this.itemHeight = 90,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: itemHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemBuilder: (context, index) => Shimmer.fromColors(
          baseColor: isDark ? const Color(0xFF21262D) : Colors.grey.shade300,
          highlightColor:
              isDark ? const Color(0xFF30363D) : Colors.grey.shade100,
          child: Container(
            width: itemWidth,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
