import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/app_controller.dart';
import 'features/screens.dart';
import 'features/akhdimni_screens.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: app.isLoggedIn ? '/' : '/login',
    refreshListenable: app,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final public = loc == '/login' || loc == '/privacy';
      if (!app.isLoggedIn && !public) return '/login';
      if (app.isLoggedIn && loc == '/login') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/order/:id',
        builder: (_, s) => CollectionOrderScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/collect/:id',
        builder: (_, s) => CollectionOrderScreen(id: s.pathParameters['id']!),
      ),
      // مرتجعات — مقابل /delivery_boy/orders/view/:id (ViewOrder.vue)
      GoRoute(
        path: '/assignment/:id',
        builder: (_, s) => OrderDetailsScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: '/delivery/:id',
        builder: (_, s) => LiveDeliveryScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/cash', builder: (_, __) => const CashScreen()),
      GoRoute(path: '/claim', builder: (_, __) => const ClaimOrdersScreen()),
      // مهام أخدمني — مقابل /delivery_boy/akhdimni (AkhdimniOrders.vue + AkhdimniPurchase.vue)
      GoRoute(path: '/akhdimni', builder: (_, __) => const AkhOrdersScreen()),
      GoRoute(
        path: '/akhdimni/:id',
        builder: (_, s) => AkhOrderDetailScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/funds', builder: (_, __) => const FundsScreen()),
      GoRoute(
        path: '/withdrawals',
        builder: (_, __) => const WithdrawalsScreen(),
      ),
      GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
      GoRoute(path: '/mail', builder: (_, __) => const MailSettingsScreen()),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/profile',
        redirect: (_, __) => '/account',
      ),
      GoRoute(path: '/privacy', builder: (_, __) => const PrivacyScreen()),
      ShellRoute(
        builder: (context, state, child) =>
            DeliveryShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: '/orders',
            builder: (_, __) => const VueOrdersScreen(),
          ),
          GoRoute(path: '/account', builder: (_, __) => const AccountScreen()),
          GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen()),
        ],
      ),
    ],
  );
}

class DeliveryShell extends StatelessWidget {
  const DeliveryShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  int get index {
    // مطابقة TheContainerDeliveryBoy.vue: الرئيسية / طلباتي / محفظتي / حسابي
    // تفاصيل الطلب /order/ والخريطة /delivery/ والالتقاط /claim تتبع تبويب طلباتي
    if (location.startsWith('/orders') ||
        location.startsWith('/order/') ||
        location.startsWith('/collect/') ||
        location.startsWith('/assignment/') ||
        location.startsWith('/delivery/') ||
        location.startsWith('/akhdimni') ||
        location.startsWith('/claim')) {
      return 1;
    }
    // محفظتي + فروعها (تحصيل/تحويلات/سحب/تقارير) تتبع تبويب محفظتي
    if (location.startsWith('/wallet') ||
        location.startsWith('/cash') ||
        location.startsWith('/funds') ||
        location.startsWith('/withdrawals') ||
        location.startsWith('/reports')) {
      return 2;
    }
    // حسابي + فروعها (ملفي/إعدادات/إشعارات/بريد/سياسات)
    if (location.startsWith('/account') ||
        location.startsWith('/profile') ||
        location.startsWith('/settings') ||
        location.startsWith('/mail') ||
        location.startsWith('/notifications') ||
        location.startsWith('/privacy')) {
      return 3;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final activeOrders = app.workloadInfo.activeCount;
        return Scaffold(
          backgroundColor: AppColors.greyBg,
          appBar: AppBar(
            toolbarHeight: 68,
            scrolledUnderElevation: 4,
            shadowColor: AppColors.navy.withValues(alpha: 0.3),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Image.asset(
                    'assets/brand/logo.webp',
                    height: 28,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.delivery_dining,
                      color: AppColors.orange,
                      size: 24,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.brand.identity['name_ar'] ?? 'سريع ماركت - توصيل',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        app.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (app.isOnline) const OnlineDot(),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'الإشعارات',
                  onPressed: () => context.push('/notifications'),
                  icon: Icon(
                    Icons.notifications_outlined,
                    color: AppColors.white.withValues(alpha: 0.9),
                  ),
                ),
                // قائمة الرأس — مقابل VerticalHeader.vue (حسابي / الاعدادات)
                PopupMenuButton<String>(
                  tooltip: 'القائمة',
                  icon: Icon(
                    Icons.more_vert,
                    color: AppColors.white.withValues(alpha: 0.9),
                  ),
                  onSelected: (v) {
                    if (v == 'account') context.go('/account');
                    if (v == 'settings') context.push('/settings');
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'account', child: Text('حسابي')),
                    PopupMenuItem(value: 'settings', child: Text('الاعدادات')),
                  ],
                ),
              ],
            ),
          ),
          body: child,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(
                top: BorderSide(color: AppColors.greyBorder),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: NavigationBar(
                height: 72,
              selectedIndex: index,
              elevation: 0,
              backgroundColor: AppColors.white,
              indicatorColor: AppColors.orange.withValues(alpha: 0.12),
              onDestinationSelected: (i) {
                switch (i) {
                  case 0:
                    context.go('/');
                  case 1:
                    context.go('/orders');
                  case 2:
                    context.go('/wallet');
                  case 3:
                    context.go('/account');
                }
              },
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard, color: AppColors.orange),
                  label: 'الرئيسية',
                ),
                NavigationDestination(
                  icon: activeOrders > 0
                      ? Badge(
                          label: Text('$activeOrders'),
                          backgroundColor: AppColors.orange,
                          child: const Icon(Icons.local_shipping_outlined),
                        )
                      : const Icon(Icons.local_shipping_outlined),
                  selectedIcon: activeOrders > 0
                      ? Badge(
                          label: Text('$activeOrders'),
                          backgroundColor: AppColors.orange,
                          child: Icon(
                            Icons.local_shipping,
                            color: AppColors.orange,
                          ),
                        )
                      : Icon(
                          Icons.local_shipping,
                          color: AppColors.orange,
                        ),
                  label: 'طلباتي',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(
                    Icons.account_balance_wallet,
                    color: AppColors.orange,
                  ),
                  label: 'محفظتي',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person, color: AppColors.orange),
                  label: 'حسابي',
                ),
              ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Pulsing online indicator dot.
class OnlineDot extends StatefulWidget {
  const OnlineDot({super.key});

  @override
  State<OnlineDot> createState() => _OnlineDotState();
}

class _OnlineDotState extends State<OnlineDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.orange,
            boxShadow: [
              BoxShadow(
                color: AppColors.orange.withValues(
                  alpha: 0.4 + _pulse.value * 0.4,
                ),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key, required this.router});
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        return MaterialApp.router(
          title: app.brand.identity['name_ar'] ?? 'سريع ماركت - توصيل',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
          theme: AppTheme.lightFor(app.brand),
        );
      },
    );
  }
}
