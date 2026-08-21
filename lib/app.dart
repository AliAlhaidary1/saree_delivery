import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/app_controller.dart';
import 'features/screens.dart';
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
        builder: (_, s) => OrderDetailsScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/delivery/:id',
        builder: (_, s) => LiveDeliveryScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/cash', builder: (_, __) => const CashScreen()),
      GoRoute(path: '/funds', builder: (_, __) => const FundsScreen()),
      GoRoute(
        path: '/withdrawals',
        builder: (_, __) => const WithdrawalsScreen(),
      ),
      GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
      GoRoute(path: '/mail', builder: (_, __) => const MailSettingsScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/privacy', builder: (_, __) => const PrivacyScreen()),
      ShellRoute(
        builder: (context, state, child) =>
            DeliveryShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: '/orders',
            builder: (_, s) {
              final type = int.tryParse(s.uri.queryParameters['type'] ?? '');
              return OrdersScreen(type: type);
            },
          ),
          GoRoute(path: '/account', builder: (_, __) => const AccountScreen()),
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
    if (location.startsWith('/orders')) return 1;
    if (location.startsWith('/account')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.greyBg,
          appBar: AppBar(
            toolbarHeight: 64,
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
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.delivery_dining,
                      color: AppColors.orange,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'سريع ماركت',
                        style: TextStyle(
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
              ],
            ),
          ),
          body: child,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: NavigationBar(
              height: 68,
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
                    context.go('/account');
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard, color: AppColors.orange),
                  label: 'الرئيسية',
                ),
                NavigationDestination(
                  icon: Icon(Icons.local_shipping_outlined),
                  selectedIcon: Icon(
                    Icons.local_shipping,
                    color: AppColors.orange,
                  ),
                  label: 'الطلبات',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person, color: AppColors.orange),
                  label: 'حسابي',
                ),
              ],
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
    return MaterialApp.router(
      title: 'سريع ماركت — سائق التوصيل',
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
      theme: AppTheme.light,
    );
  }
}
