import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../application/shop_detail_provider.dart';
import '../../data/models/shop_model.dart';
import '../widgets/menu_tab.dart';
import '../../../cart/presentation/widgets/cart_fab.dart';
import '../../../../core/router/app_router.dart';
import '../../../bookings/presentation/widgets/booking_tab.dart';

class ShopDetailScreen extends ConsumerWidget {
  const ShopDetailScreen({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(shopDetailProvider(shopId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: shopAsync.when(
        loading: () => const SafeArea(child: SkeletonLoader.detail()),
        error: (error, stack) => SafeArea(
          child: ErrorView(
            message: "We couldn't load this shop right now. Please try again.",
            onRetry: () => ref.invalidate(shopDetailProvider(shopId)),
          ),
        ),
        data: (shop) => _ShopDetailContent(shop: shop),
      ),
    );
  }
}

const double _kCoverImageHeight = 256;
const double _kCardOverlap = 48;

class _ShopDetailContent extends StatefulWidget {
  const _ShopDetailContent({required this.shop});
  final ShopModel shop;

  @override
  State<_ShopDetailContent> createState() => _ShopDetailContentState();
}

class _ShopDetailContentState extends State<_ShopDetailContent>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    if (widget.shop.acceptsBooking) {
      _tabController = TabController(length: 2, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    final hasBookingTab = shop.acceptsBooking;

    // FIX (scroll-lock bug): the old layout ran an outer CustomScrollView
    // (cover photo + info card + tab bar) AND an inner ListView per tab
    // (MenuTab/BookingTab), stacked via SliverFillRemaining. Those were
    // two completely independent scroll positions — scrolling one never
    // told the other it had reached its end, which is exactly why the
    // screen appeared to "lock": you were actually still scrolling the
    // *inner* list after the *outer* one had already hit its bound (or
    // vice versa), so trying to scroll back up did nothing until you
    // found the specific scrollable that still had room to move.
    //
    // NestedScrollView is the framework-supported fix for precisely this
    // shape (header + TabBarView, single physics): it owns ONE outer
    // scroll position and hands inner scrollables (MenuTab/BookingTab,
    // now CustomScrollViews themselves) a shared, coordinated controller
    // via PrimaryScrollController. Scrolling from either the header area
    // or the list now drives the same position, so it always scrolls
    // smoothly back to the top exactly as far as it scrolled down.
    return Stack(
      children: [
        NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              // FIX: _CoverImage and the overlapping _ShopInfoCard live in
              // ONE sliver (avoids the old cross-sliver clipping bug, where
              // a Transform reaching into the previous sliver got clipped
              // at the sliver boundary and swallowed the top of the card).
              //
              // The overlap itself is done WITHOUT any negative EdgeInsets
              // or margin. `Padding`'s render object (RenderPadding, in
              // shifted_box.dart) has the exact same `padding.isNonNegative`
              // assertion as Container's margin — a negative EdgeInsets
              // throws at runtime either way, it just wasn't hit until the
              // first frame that actually laid this screen out.
              //
              // Instead: a Stack reserves only (coverHeight - _kCardOverlap)
              // of layout space via a plain SizedBox (a real, non-negative
              // height), while the actual cover image is Positioned on top
              // of it at full height with clipBehavior: Clip.none, so it
              // paints _kCardOverlap px past the Stack's reserved box. The
              // card, as the next Column child, then starts right where
              // that reserved box ends and — being painted after, i.e. on
              // top — visually covers that overflowing strip of the image.
              // Net effect: identical overlap look, non-negative sizes only.
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const SizedBox(
                            height: _kCoverImageHeight - _kCardOverlap),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: _CoverImage(shop: shop),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.gutter),
                      child: _ShopInfoCard(shop: shop),
                    ),
                    if (hasBookingTab)
                      const SizedBox(height: AppSpacing.stackSm),
                  ],
                ),
              ),
              // The tab bar is the one piece of "header" that should stay
              // pinned once you scroll into the list — SliverOverlapAbsorber
              // records how much space it occupies so MenuTab/BookingTab's
              // own CustomScrollView (via SliverOverlapInjector) can pad
              // around it correctly instead of the first item starting
              // hidden underneath it.
              if (hasBookingTab)
                SliverOverlapAbsorber(
                  handle:
                      NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                  sliver: SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarHeaderDelegate(
                      tabBar: TabBar(
                        controller: _tabController,
                        labelColor: AppColors.primaryContainer,
                        unselectedLabelColor: AppColors.secondary,
                        indicatorColor: AppColors.primaryContainer,
                        indicatorSize: TabBarIndicatorSize.label,
                        labelStyle: AppTextStyles.headlineMd,
                        unselectedLabelStyle: AppTextStyles.headlineMd,
                        tabs: const [
                          Tab(
                            icon: Icon(Icons.restaurant_menu_rounded, size: 20),
                            text: 'Order',
                            iconMargin: EdgeInsets.only(bottom: 4),
                          ),
                          Tab(
                            icon: Icon(Icons.event_seat_rounded, size: 20),
                            text: 'Book a Table',
                            iconMargin: EdgeInsets.only(bottom: 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ];
          },
          body: hasBookingTab
              ? TabBarView(
                  controller: _tabController,
                  children: [
                    MenuTab(shopId: shop.id),
                    BookingTab(shopId: shop.id, shopName: shop.name),
                  ],
                )
              : MenuTab(shopId: shop.id),
        ),
        // Back button floats over the cover photo — matches
        // shop_detail_updated's mobile back-button treatment.
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.stackMd),
            child: _CircleIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => context.pop(),
            ),
          ),
        ),
        // CartFab renders its own Positioned internally (bottom-fixed,
        // per menu_updated's floating cart bar) — must sit directly in
        // this Stack's children, not wrapped in Align/Padding/etc.
        CartFab(
          onTap: () => context.push(AppRoutes.cart),
        ),
      ],
    );
  }
}

/// Wraps the shop's Order/Book-a-Table [TabBar] as a pinned sliver header
/// inside [NestedScrollView.headerSliverBuilder]. Keeping this tiny and
/// dedicated (rather than reaching for a generic helper) matches
/// menu_tab.dart/booking_tab.dart's "one clear owner per sliver" pattern.
class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  _TabBarHeaderDelegate({required this.tabBar});

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        child: tabBar,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarHeaderDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar;
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.shop});
  final ShopModel shop;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppSpacing.radiusLg * 2)),
      child: SizedBox(
        height: _kCoverImageHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            shop.coverImageUrl.isEmpty
                ? Container(color: AppColors.surfaceContainerHigh)
                : CachedNetworkImage(
                    imageUrl: shop.coverImageUrl,
                    fit: BoxFit.cover,
                    // Decode near the actual display size (2x for device
                    // pixel ratio) instead of the full source resolution.
                    memCacheWidth: 800,
                    memCacheHeight: 512,
                    placeholder: (context, url) =>
                        Container(color: AppColors.surfaceContainerHigh),
                    errorWidget: (context, url, error) =>
                        Container(color: AppColors.surfaceContainerHigh),
                  ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppColors.onSurface.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: AppColors.onSurface, size: 22),
        ),
      ),
    );
  }
}

class _ShopInfoCard extends StatelessWidget {
  const _ShopInfoCard({required this.shop});
  final ShopModel shop;

  @override
  Widget build(BuildContext context) {
    final statusColor = shop.isOpen ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.stackMd + 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.surfaceVariant),
        boxShadow: [
          BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.05),
              blurRadius: 16),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(shop.name, style: AppTextStyles.headlineLgMobile),
              ),
              const SizedBox(width: AppSpacing.stackSm),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      shop.isOpen ? 'Open' : 'Closed',
                      style:
                          AppTextStyles.labelCaps.copyWith(color: statusColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (shop.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.stackSm),
            Text(shop.description, style: AppTextStyles.bodySm),
          ],
          if (shop.address.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.stackMd),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 18, color: AppColors.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shop.address,
                    style: AppTextStyles.bodySm,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
