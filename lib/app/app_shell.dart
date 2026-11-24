import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/constants/app_constants.dart';
import '../features/attendance/domain/attendance_event.dart';
import '../features/geofence/domain/geofence_config.dart';
import 'app_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
//   Direction: calm, field-ready. Deep pine ink + one warm amber signal.
//   The single memorable element is the pulsing punch button on Home.
// ─────────────────────────────────────────────────────────────────────────────
const indigo = Color(0xFF1F6F5C); // kept for backwards compatibility
const ink = Color(0xFF0F2A26);

class AppColors {
  static const primary = Color(0xFF1F6F5C); // pine
  static const primaryDark = Color(0xFF0F2A26); // deep ink
  static const primarySoft = Color(0xFFE3F0EC);
  static const bg = Color(0xFFF4F6F5);
  static const surface = Colors.white;
  static const border = Color(0xFFE2E8E5);
  static const text = Color(0xFF0F2A26);
  static const muted = Color(0xFF63726E);
  static const success = Color(0xFF16875F);
  static const successSoft = Color(0xFFDDF3EA);
  static const warning = Color(0xFFC77A0A);
  static const warningSoft = Color(0xFFFCEFD6);
  static const danger = Color(0xFFC4412B);
  static const dangerSoft = Color(0xFFFBE6E1);
  static const signal = Color(0xFFF2A93B); // amber: "on duty / check out"
  static const heroGradient = LinearGradient(
    colors: [Color(0xFF0F2A26), Color(0xFF1B4F44)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 22.0;
}

/// Apply in MaterialApp: `theme: buildGeoPulseTheme()`.
ThemeData buildGeoPulseTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(primary: AppColors.primary, surface: AppColors.surface);
  final textTheme = GoogleFonts.interTextTheme(
    ThemeData.light().textTheme,
  ).apply(bodyColor: AppColors.text, displayColor: AppColors.text);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: textTheme,
    primaryTextTheme: GoogleFonts.interTextTheme(
      ThemeData.light().primaryTextTheme,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: AppColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: AppColors.primarySoft,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: s.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.muted,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shell
// ─────────────────────────────────────────────────────────────────────────────
class AppShell extends StatefulWidget {
  final AppController controller;
  const AppShell({required this.controller, super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int tab = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.resumeMonitoring();
      widget.controller.retryPendingAttendance();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (_, __) {
      final c = widget.controller;
      if (c.loading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (!c.session.authenticated) return ReferenceLoginPage(c: c);
      if (c.monitoringStatus?.ready != true) {
        return PermissionGate(c: c);
      }
      final pages = <Widget>[
        AttendanceHomePage(c: c),
        AttendanceHistoryPage(c: c),
        DiagnosticsPage(c: c),
      ];
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              IndexedStack(index: tab, children: pages),
              if (c.busy)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: Colors.transparent,
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (v) => setState(() => tab = v),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month_rounded),
                label: 'Attendance',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Permission gate
// ─────────────────────────────────────────────────────────────────────────────
class PermissionGate extends StatefulWidget {
  final AppController c;
  const PermissionGate({required this.c, super.key});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  bool requesting = false;
  bool explanationShown = false;
  String? error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!explanationShown) {
      explanationShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _explainAndRequest());
    }
  }

  Future<void> _explainAndRequest() async {
    if (!mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        icon: const Icon(
          Icons.shield_outlined,
          size: 36,
          color: AppColors.primary,
        ),
        title: const Text('Allow location and notifications'),
        content: const Text(
          'GeoPulse uses Android geofencing and your precise background '
          'location to record ENTER and EXIT events at workplaces assigned by '
          'your employer, including while the app is closed or the screen is '
          'locked. Events are stored on this device and sent to your employer’s '
          'Frappe server with event time, coordinates when Android provides '
          'them, accuracy, distance, battery/charging state, network signal, '
          'Android/device model, installation ID, and background-event status. '
          'Notifications report events and tracking problems; denying them '
          'does not stop geofencing. Android may delay or miss transitions, and '
          'Force Stop disables tracking until you open the app again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Close app'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (proceed == true) {
      await _request();
    } else {
      await SystemNavigator.pop();
    }
  }

  Future<void> _request() async {
    if (requesting) return;
    setState(() {
      requesting = true;
      error = null;
    });
    try {
      await widget.c.requestMonitoringPermissions();
      await widget.c.refreshStatus();
    } catch (exception) {
      error = '$exception';
      await widget.c.refreshStatus();
    } finally {
      if (mounted) setState(() => requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.c.monitoringStatus;
    final checks = <_PermItem>[
      _PermItem(
        'Location services',
        'Turn on GPS on this device',
        Icons.gps_fixed_rounded,
        status?.locationServices == true,
      ),
      _PermItem(
        'Precise location',
        'Needed for accurate workplace checks',
        Icons.my_location_rounded,
        status?.precisePermission == true,
      ),
      _PermItem(
        'Background location',
        'Records arrival even when the app is closed',
        Icons.explore_outlined,
        status?.backgroundPermission == true,
      ),
      _PermItem(
        'Notifications',
        'Recommended for event and tracking alerts',
        Icons.notifications_active_outlined,
        status?.notificationsPermission == true,
      ),
      _PermItem(
        'Google Play services',
        'Powers native geofencing',
        Icons.android_rounded,
        status?.googlePlayServicesAvailable == true,
      ),
    ];
    final enabledCount = checks.where((check) => check.ok).length;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.paddingOf(context).top + 28,
              24,
              28,
            ),
            decoration: const BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _LogoBadge(size: 52),
                const SizedBox(height: 20),
                const Text(
                  'Set up GeoPulse',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$enabledCount of ${checks.length} ready. Turn on each item to start.',
                  style: TextStyle(color: Colors.white.withValues(alpha: .75)),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: enabledCount / checks.length,
                    minHeight: 6,
                    color: AppColors.signal,
                    backgroundColor: Colors.white.withValues(alpha: .18),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              children: [
                for (final check in checks) _PermTile(item: check),
                if (error != null)
                  Message(error!, error: true, margin: EdgeInsets.zero),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: requesting ? null : _request,
                    icon: requesting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.verified_user_outlined),
                    label: const Text('Grant permissions'),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: openAppSettings,
                          child: Text('App settings'),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: geo.Geolocator.openLocationSettings,
                          child: Text('Location settings'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermItem {
  final String title, subtitle;
  final IconData icon;
  final bool ok;
  const _PermItem(this.title, this.subtitle, this.icon, this.ok);
}

class _PermTile extends StatelessWidget {
  final _PermItem item;
  const _PermTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.ok ? AppColors.success : AppColors.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: item.ok ? AppColors.border : color.withValues(alpha: .5),
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          _IconTile(item.icon, color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Icon(
            item.ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: color,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Login
// ─────────────────────────────────────────────────────────────────────────────
class _LogoBadge extends StatelessWidget {
  final double size;
  const _LogoBadge({this.size = 76});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: EdgeInsets.all(size * .18),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(size * .3),
      border: Border.all(color: Colors.white.withValues(alpha: .3)),
    ),
    child: Image.asset('assets/branding/geopulse_logo.png'),
  );
}

class ReferenceLoginPage extends StatefulWidget {
  final AppController c;
  const ReferenceLoginPage({required this.c, super.key});

  @override
  State<ReferenceLoginPage> createState() => _ReferenceLoginPageState();
}

class _ReferenceLoginPageState extends State<ReferenceLoginPage> {
  final user = TextEditingController();
  final password = TextEditingController();
  bool hidden = true;

  @override
  void dispose() {
    user.dispose();
    password.dispose();
    super.dispose();
  }

  void login() {
    if (user.text.trim().isEmpty || password.text.isEmpty) return;
    widget.c.login(AppConstants.defaultSiteUrl, user.text, password.text);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    body: SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              28,
              MediaQuery.paddingOf(context).top + 48,
              28,
              96,
            ),
            decoration: const BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _LogoBadge(size: 60),
                const SizedBox(height: 28),
                const Text(
                  'Your workday,\nrecorded on arrival.',
                  style: TextStyle(
                    fontSize: 34,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'GeoPulse marks attendance when you reach your work location.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .75),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A0F2A26),
                            blurRadius: 30,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Sign in',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Use your company account.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                          const SizedBox(height: 20),
                          if (widget.c.error != null)
                            Message(
                              widget.c.error!,
                              error: true,
                              margin: const EdgeInsets.only(bottom: 14),
                            ),
                          TextField(
                            controller: user,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            decoration: const InputDecoration(
                              labelText: 'Employee ID or email',
                              prefixIcon: Icon(
                                Icons.badge_outlined,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: password,
                            obscureText: hidden,
                            onSubmitted: (_) => login(),
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: AppColors.primary,
                              ),
                              suffixIcon: IconButton(
                                tooltip: hidden
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () =>
                                    setState(() => hidden = !hidden),
                                icon: Icon(
                                  hidden
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: widget.c.busy ? null : login,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                            ),
                            child: widget.c.busy
                                ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Sign in',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: AppColors.muted,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Sent only to your company’s secure server.\nNo login? Ask HR for your credentials.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class EmployeeLoginPage extends StatelessWidget {
  final AppController c;
  const EmployeeLoginPage({required this.c, super.key});
  @override
  Widget build(BuildContext context) => ReferenceLoginPage(c: c);
}

// ─────────────────────────────────────────────────────────────────────────────
// Home
// ─────────────────────────────────────────────────────────────────────────────

/// Rebuilds [builder] on a fixed interval (used for clock and worked time).
class _Ticking extends StatefulWidget {
  final Duration every;
  final WidgetBuilder builder;
  const _Ticking({
    required this.builder,
    this.every = const Duration(seconds: 15),
  });
  @override
  State<_Ticking> createState() => _TickingState();
}

class _TickingState extends State<_Ticking> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.every, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// The one memorable element: a big punch button. While on duty, soft rings
/// pulse outward to show the app is actively monitoring your location.
class _PunchButton extends StatefulWidget {
  final bool checkingIn;
  final bool enabled;
  final VoidCallback onPressed;
  const _PunchButton({
    required this.checkingIn,
    required this.enabled,
    required this.onPressed,
  });
  @override
  State<_PunchButton> createState() => _PunchButtonState();
}

class _PunchButtonState extends State<_PunchButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (!widget.checkingIn && !reduce) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse.stop();
    }
  }

  @override
  void didUpdateWidget(covariant _PunchButton old) {
    super.didUpdateWidget(old);
    didChangeDependencies();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onDuty = !widget.checkingIn;
    final face = onDuty ? AppColors.signal : Colors.white;
    final iconColor = onDuty ? AppColors.primaryDark : AppColors.primary;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.checkingIn ? 'Check in' : 'Check out',
      child: SizedBox(
        width: 240,
        height: 240,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Stack(
                alignment: Alignment.center,
                children: [
                  for (final phase in const [0.0, .5])
                    _ring(onDuty ? (_pulse.value + phase) % 1 : null),
                ],
              ),
            ),
            Opacity(
              opacity: widget.enabled ? 1 : .55,
              child: Material(
                color: face,
                shape: const CircleBorder(),
                elevation: 6,
                shadowColor: Colors.black54,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.enabled
                      ? () {
                          HapticFeedback.mediumImpact();
                          widget.onPressed();
                        }
                      : null,
                  child: SizedBox(
                    width: 156,
                    height: 156,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.checkingIn
                              ? Icons.login_rounded
                              : Icons.logout_rounded,
                          size: 40,
                          color: iconColor,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.checkingIn ? 'Check in' : 'Check out',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: iconColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ring(double? t) {
    // Static faint ring when off duty (t == null), expanding ring when on duty.
    final scale = t == null ? 1.12 : 1 + .5 * t;
    final opacity = t == null ? .12 : (1 - t) * .28;
    return IgnorePointer(
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 156,
          height: 156,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: opacity),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class AttendanceHomePage extends StatelessWidget {
  final AppController c;
  const AttendanceHomePage({required this.c, super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final checkingIn = c.nextAttendanceAction == AttendanceAction.checkIn;
    final dashboardEmployee = (c.dashboard['employee'] as Map?) ?? const {};
    final displayName =
        '${dashboardEmployee['employee_name'] ?? dashboardEmployee['name'] ?? c.session.employeeName}';
    final lastLog = c.dashboard['last_log'] as Map?;
    final today = c.attendance.where((e) {
      final d = DateTime.tryParse('${e['event_timestamp']}')?.toLocal();
      final now = DateTime.now();
      return d != null &&
          d.year == now.year &&
          d.month == now.month &&
          d.day == now.day;
    }).toList();
    Map<String, Object?>? checkInLog;
    Map<String, Object?>? checkOutLog;
    for (final log in today) {
      if (log['action'] == 'IN') checkInLog ??= log;
      if (log['action'] == 'OUT') checkOutLog = log;
    }
    String attendanceTime(Map<String, Object?>? log) {
      final timestamp = DateTime.tryParse('${log?['event_timestamp']}');
      return timestamp == null
          ? '--:--'
          : TimeOfDay.fromDateTime(timestamp.toLocal()).format(context);
    }

    String worked() {
      final start = DateTime.tryParse('${checkInLog?['event_timestamp']}');
      if (start == null) return '0h 0m';
      final end = checkingIn
          ? (DateTime.tryParse('${checkOutLog?['event_timestamp']}') ??
                DateTime.now())
          : DateTime.now();
      final d = end.difference(start);
      if (d.isNegative) return '0h 0m';
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }

    final locationReady = c.monitoringStatus?.ready == true;

    return RefreshIndicator(
      onRefresh: c.refreshFromServer,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Row(
            children: [
              _Avatar(name: displayName, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                    Text(
                      displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        letterSpacing: -.3,
                      ),
                    ),
                  ],
                ),
              ),
              _IconBubble(
                icon: Icons.sync_rounded,
                tooltip: 'Refresh',
                onTap: c.refresh,
              ),
            ],
          ),
          if (c.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Message(c.error!, error: true, margin: EdgeInsets.zero),
            ),
          if (c.notice != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Message(c.notice!, margin: EdgeInsets.zero),
            ),
          const SizedBox(height: 20),
          // Hero: clock, punch button, today's numbers
          Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x330F2A26),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Ticking(
                            builder: (ctx) => Text(
                              TimeOfDay.now().format(ctx),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.5,
                                height: 1.05,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _friendlyDate(DateTime.now()),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .72),
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusChip(
                      checkingIn ? 'Off duty' : 'On duty',
                      color: checkingIn ? Colors.white : AppColors.signal,
                      background: Colors.white.withValues(alpha: .14),
                      icon: Icons.circle,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _PunchButton(
                  checkingIn: checkingIn,
                  enabled: !c.busy,
                  onPressed: () => c.recordAttendance(
                    checkingIn
                        ? AttendanceAction.checkIn
                        : AttendanceAction.checkOut,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      locationReady
                          ? Icons.location_on_rounded
                          : Icons.location_off_rounded,
                      size: 16,
                      color: locationReady
                          ? const Color(0xFF8EE3BE)
                          : AppColors.signal,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      locationReady
                          ? 'Location is on and monitored'
                          : 'Location needs attention',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: _Ticking(
                    every: const Duration(seconds: 30),
                    builder: (_) => Row(
                      children: [
                        _HeroStat('In', attendanceTime(checkInLog)),
                        const _HeroDivider(),
                        _HeroStat('Out', attendanceTime(checkOutLog)),
                        const _HeroDivider(),
                        _HeroStat('Worked', worked()),
                      ],
                    ),
                  ),
                ),
                if (lastLog != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Last ${lastLog['log_type'] ?? 'log'} at ${lastLog['time'] ?? ''}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .6),
                        fontSize: 12.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SectionTitle('This week', padding: _sectionPad),
          _WeekStrip(
            records: (c.monthlyAttendance['attendance'] as List? ?? const [])
                .whereType<Map>()
                .toList(growable: false),
          ),
          const SectionTitle('Requests', padding: _sectionPad),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ActionRow(
                  label: 'Leave application',
                  icon: Icons.event_note_rounded,
                  color: AppColors.primary,
                  onTap: () => _showApiRequired(context, 'Leave application'),
                ),
                const Divider(indent: 70),
                _ActionRow(
                  label: 'Attendance request',
                  icon: Icons.fact_check_rounded,
                  color: AppColors.success,
                  onTap: () => _showApiRequired(context, 'Attendance request'),
                ),
                const Divider(indent: 70),
                _ActionRow(
                  label: 'Salary slip',
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.warning,
                  onTap: () => _showApiRequired(context, 'Salary slip'),
                ),
                const Divider(indent: 70),
                _ActionRow(
                  label: 'Location history',
                  icon: Icons.route_rounded,
                  color: AppColors.primaryDark,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        backgroundColor: AppColors.bg,
                        appBar: AppBar(
                          title: const Text('Location history'),
                          backgroundColor: AppColors.bg,
                          surfaceTintColor: Colors.transparent,
                        ),
                        body: EventHistoryPage(c: c),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (c.assignedLocations.isNotEmpty) ...[
            const SectionTitle('Your work locations', padding: _sectionPad),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < c.assignedLocations.length; i++) ...[
                    if (i > 0) const Divider(indent: 70),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const _IconTile(
                            Icons.location_on_rounded,
                            AppColors.primary,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${c.assignedLocations[i]['location_name'] ?? 'Work location'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                                if ('${c.assignedLocations[i]['address'] ?? ''}'
                                    .trim()
                                    .isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      '${c.assignedLocations[i]['address']}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showApiRequired(
    BuildContext context,
    String feature,
  ) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Text(feature),
      content: Text(
        '$feature isn’t available in the app yet. Please use ERPNext on the web for now.',
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

class _HeroStat extends StatelessWidget {
  final String label, value;
  const _HeroStat(this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .65),
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

class _HeroDivider extends StatelessWidget {
  const _HeroDivider();
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 28,
    color: Colors.white.withValues(alpha: .15),
  );
}

/// Mon–Sun strip showing which days this week have attendance.
class _WeekStrip extends StatelessWidget {
  final List<Map> records;
  const _WeekStrip({required this.records});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final byDay = <String, String>{};
    for (final r in records) {
      final d = DateTime.tryParse('${r['attendance_date'] ?? ''}');
      if (d != null) {
        byDay['${d.year}-${d.month}-${d.day}'] = '${r['status'] ?? ''}';
      }
    }
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Builder(
              builder: (_) {
                final day = monday.add(Duration(days: i));
                final status = byDay['${day.year}-${day.month}-${day.day}'];
                final isToday =
                    day.year == now.year &&
                    day.month == now.month &&
                    day.day == now.day;
                final present = status == 'Present';
                final other = status != null && !present;
                final fill = present
                    ? AppColors.success
                    : other
                    ? AppColors.warning
                    : Colors.transparent;
                return Expanded(
                  child: Semantics(
                    label:
                        '${_weekdayName(i)} ${day.day}: ${status ?? (isToday ? 'today' : 'no record')}',
                    child: Column(
                      children: [
                        Text(
                          names[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isToday
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: isToday
                                ? AppColors.primary
                                : AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: fill,
                            border: Border.all(
                              color: isToday
                                  ? AppColors.primary
                                  : (status == null
                                        ? AppColors.border
                                        : Colors.transparent),
                              width: isToday ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: status != null
                                  ? Colors.white
                                  : AppColors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _weekdayName(int i) => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][i];
}

class _ActionRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionRow({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadius.md),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _IconTile(icon, color),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    ),
  );
}

const _sectionPad = EdgeInsets.fromLTRB(2, 26, 0, 12);
const _sectionStyle = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w800,
  color: AppColors.text,
  letterSpacing: -.2,
);

// ─────────────────────────────────────────────────────────────────────────────
// Attendance history
// ─────────────────────────────────────────────────────────────────────────────
class AttendanceHistoryPage extends StatefulWidget {
  final AppController c;
  const AttendanceHistoryPage({required this.c, super.key});

  @override
  State<AttendanceHistoryPage> createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  late int selectedMonth;
  late int selectedYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedMonth = now.month;
    selectedYear = now.year;
  }

  Future<void> _loadAttendance() =>
      widget.c.loadAttendancePeriod(month: selectedMonth, year: selectedYear);

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final allRecords = (c.monthlyAttendance['attendance'] as List? ?? const [])
        .whereType<Map>()
        .toList(growable: false);
    final records = allRecords;
    final summary = (c.monthlyAttendance['summary'] as Map?) ?? const {};
    final currentYear = DateTime.now().year;
    final years = List<int>.generate(6, (index) => currentYear - index);
    return RefreshIndicator(
      onRefresh: _loadAttendance,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const Text(
            'Attendance',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              Icon(
                Icons.cloud_done_outlined,
                size: 16,
                color: AppColors.success,
              ),
              SizedBox(width: 6),
              Text(
                'Synced with Frappe HR',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<int>(
                  initialValue: selectedMonth,
                  decoration: const InputDecoration(
                    labelText: 'Month',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  items: [
                    for (var month = 1; month <= 12; month++)
                      DropdownMenuItem(
                        value: month,
                        child: Text(_months[month - 1]),
                      ),
                  ],
                  onChanged: c.busy
                      ? null
                      : (month) async {
                          if (month == null || month == selectedMonth) return;
                          setState(() => selectedMonth = month);
                          await _loadAttendance();
                        },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  initialValue: selectedYear,
                  decoration: const InputDecoration(labelText: 'Year'),
                  items: years
                      .map(
                        (year) =>
                            DropdownMenuItem(value: year, child: Text('$year')),
                      )
                      .toList(growable: false),
                  onChanged: c.busy
                      ? null
                      : (year) async {
                          if (year == null || year == selectedYear) return;
                          setState(() => selectedYear = year);
                          await _loadAttendance();
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (c.monthlyAttendance['from_date_display'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                '${c.monthlyAttendance['from_date_display']} – '
                '${c.monthlyAttendance['to_date_display']}  •  '
                '${c.monthlyAttendance['timezone'] ?? ''}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (summary.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Metric(
                    'Present',
                    '${(summary['status_counts'] as Map?)?['Present'] ?? 0}',
                    Icons.event_available,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Metric(
                    'Absent',
                    '${(summary['status_counts'] as Map?)?['Absent'] ?? 0}',
                    Icons.event_busy_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const _IconTile(Icons.schedule_rounded, AppColors.primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Total working hours',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${summary['total_working_hours'] ?? 0} h',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (records.isEmpty)
            const Empty(
              Icons.calendar_today_outlined,
              'No attendance for this period',
              'Check in from Home and your records will show up here.',
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < records.length; i++) ...[
                    if (i > 0) const Divider(indent: 76),
                    _MonthlyAttendanceTile(record: records[i]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PageAppBar extends StatelessWidget {
  final String section;
  const _PageAppBar({required this.section});

  @override
  Widget build(BuildContext context) => Text(
    section,
    style: const TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      color: AppColors.text,
      letterSpacing: -.8,
    ),
  );
}

class _MonthlyAttendanceTile extends StatelessWidget {
  final Map record;
  const _MonthlyAttendanceTile({required this.record});

  Color _statusColor(String status) {
    if (status == 'Present') return AppColors.success;
    if (status == 'Absent') return AppColors.danger;
    if (status == 'On Leave') return AppColors.primary;
    if (status == 'Half Day') return AppColors.warning;
    if (status == 'Work From Home') return AppColors.primaryDark;
    return AppColors.muted;
  }

  @override
  Widget build(BuildContext context) {
    final status =
        '${record['status_display'] ?? record['status'] ?? 'Unknown'}';
    final color = _statusColor(status);
    final date = DateTime.tryParse('${record['attendance_date'] ?? ''}');
    final dayName = '${record['day_name'] ?? ''}';
    final dateDisplay =
        '${record['attendance_date_display'] ?? record['attendance_date'] ?? '--'}';
    final inTime = '${record['in_time_display'] ?? '--'}';
    final outTime = '${record['out_time_display'] ?? '--'}';
    final hours =
        '${record['working_hours_display'] ?? '${record['working_hours'] ?? 0} h'}';
    final late = record['late_entry'] == 1 || record['late_entry'] == true;
    final early = record['early_exit'] == 1 || record['early_exit'] == true;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      date == null ? '--' : '${date.day}',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: color,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      dayName.isEmpty ? '' : dayName.substring(0, 3),
                      style: TextStyle(fontSize: 11, color: color),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateDisplay,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${record['shift'] ?? 'No shift'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(
                status,
                color: color,
                background: color.withValues(alpha: .1),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _AttendanceTimeRow(
                  label: 'Check In',
                  value: inTime,
                  icon: Icons.login_rounded,
                ),
                const SizedBox(height: 8),
                _AttendanceTimeRow(
                  label: 'Check Out',
                  value: outTime,
                  icon: Icons.logout_rounded,
                ),
                const Divider(height: 18),
                Row(
                  children: [
                    const Text(
                      'Working hours',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    const Spacer(),
                    Text(
                      hours,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (late || early) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (late)
                  const StatusChip(
                    'Late Entry',
                    color: AppColors.warning,
                    background: AppColors.warningSoft,
                  ),
                if (early)
                  const StatusChip(
                    'Early Exit',
                    color: AppColors.warning,
                    background: AppColors.warningSoft,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AttendanceTimeRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _AttendanceTimeRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 17, color: AppColors.muted),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      const Spacer(),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

String _friendlyDate(DateTime date) {
  final weekday = const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][date.weekday - 1];
  final month = const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][date.month - 1];
  return '$weekday, ${date.day} $month ${date.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Legacy / secondary pages (restyled through shared tokens)
// ─────────────────────────────────────────────────────────────────────────────
class PageTitle extends StatelessWidget {
  final String title, subtitle;
  const PageTitle(this.title, this.subtitle, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
            letterSpacing: -.6,
          ),
        ),
        Text(subtitle, style: const TextStyle(color: AppColors.muted)),
      ],
    ),
  );
}

class DashboardPage extends StatelessWidget {
  final AppController c;
  final VoidCallback manage;
  const DashboardPage({required this.c, required this.manage, super.key});
  @override
  Widget build(BuildContext context) {
    final active = c.geofences.where((e) => e.enabled).toList();
    final enter = c.events.where((e) => e['event_type'] == 'ENTER').firstOrNull;
    final exit = c.events.where((e) => e['event_type'] == 'EXIT').firstOrNull;
    final status = c.monitoringStatus;
    return RefreshIndicator(
      onRefresh: c.refresh,
      child: ListView(
        children: [
          const PageTitle('GeoPulse', 'Offline-first Android geofencing'),
          if (c.error != null) Message(c.error!, error: true),
          if (c.notice != null) Message(c.notice!),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        status?.ready == true
                            ? Icons.sensors
                            : Icons.warning_amber,
                        color: status?.ready == true
                            ? const Color(0xFF8EF0C5)
                            : AppColors.signal,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status?.ready == true
                            ? 'Monitoring is on'
                            : 'Action needed',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '${active.length} active ${active.length == 1 ? 'location' : 'locations'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _status(status),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: manage,
                    icon: const Icon(Icons.tune),
                    label: const Text('Manage monitoring'),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                Metric(
                  'Total events',
                  '${c.syncCounts.values.fold<int>(0, (a, b) => a + b)}',
                  Icons.swap_vert,
                ),
                Metric(
                  'Pending sync',
                  '${c.syncCounts['pending'] ?? 0}',
                  Icons.cloud_upload_outlined,
                ),
                Metric(
                  'Failed sync',
                  '${c.syncCounts['failed'] ?? 0}',
                  Icons.error_outline,
                ),
                Metric(
                  'Native zones',
                  '${status?.registeredGeofenceCount ?? 0}',
                  Icons.radar,
                ),
              ],
            ),
          ),
          EventSummary('Last entry', enter, Icons.login, AppColors.success),
          EventSummary('Last exit', exit, Icons.logout, AppColors.warning),
          if (active.isNotEmpty) ...[
            const SectionTitle('Active configuration'),
            ...active.map(
              (g) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: const _IconTile(Icons.location_on, AppColors.primary),
                title: Text(
                  g.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${g.radiusMeters.round()} m • ${g.latitude}, ${g.longitude}',
                ),
                trailing: Switch(
                  value: g.enabled,
                  onChanged: c.busy ? null : (v) => c.setEnabled(g, v),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _status(dynamic s) {
    if (s == null) return 'Checking Android services…';
    if (!s.locationServices) return 'Location services are turned off.';
    if (!s.backgroundPermission) {
      return 'Background location permission is missing.';
    }
    if (!s.googlePlayServicesAvailable) {
      return 'Google Play services are unavailable or outdated.';
    }
    return s.ignoringBatteryOptimizations
        ? 'Android can deliver native transitions.'
        : 'Ready. Battery saver may delay delivery or sync.';
  }
}

class LocationsPage extends StatelessWidget {
  final AppController c;
  const LocationsPage({required this.c, super.key});
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      const PageTitle('Locations', 'Create, edit, enable, or stop monitoring'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: FilledButton.icon(
          onPressed: c.busy ? null : () => edit(context),
          icon: const Icon(Icons.add_location_alt),
          label: const Text('Add location'),
        ),
      ),
      const SizedBox(height: 14),
      if (c.geofences.isEmpty)
        const Empty(
          Icons.radar,
          'No locations yet',
          'Add coordinates and a radius to start monitoring.',
        )
      else
        ...c.geofences.map(
          (g) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      const _IconTile(Icons.location_on, AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              g.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${g.radiusMeters.round()} m • ${g.latitude.toStringAsFixed(6)}, ${g.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                            if ((g.assignedTo ?? '').isNotEmpty)
                              Text(
                                'Assigned: ${g.assignedTo}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Switch(
                        value: g.enabled,
                        onChanged: c.busy ? null : (v) => c.setEnabled(g, v),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => edit(context, g),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                      TextButton.icon(
                        onPressed: () => remove(context, g),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
  Future<void> edit(BuildContext context, [GeofenceConfig? g]) async {
    final draft = await showModalBottomSheet<GeofenceDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GeofenceEditor(c: c, existing: g),
    );
    if (draft != null) {
      await c.saveGeofence(
        id: g?.id,
        name: draft.name,
        address: draft.address,
        assignedTo: draft.assigned,
        latitude: draft.lat,
        longitude: draft.lon,
        radiusMeters: draft.radius,
        enabled: g?.enabled ?? true,
      );
    }
  }

  Future<void> remove(BuildContext context, GeofenceConfig g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Stop monitoring?'),
        content: const Text('Past and unsynced events will be kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(100, 44),
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Stop monitoring'),
          ),
        ],
      ),
    );
    if (ok == true) await c.deleteGeofence(g);
  }
}

class EventHistoryPage extends StatelessWidget {
  final AppController c;

  const EventHistoryPage({required this.c, super.key});

  static const Color _green = Color(0xFF16A34A);
  static const Color _orange = Color(0xFFEA580C);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _red = Color(0xFFDC2626);

  String _text(Object? value, [String fallback = 'Not available']) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  bool _isEnter(Map<String, Object?> event) {
    return _text(event['event_type']).toUpperCase() == 'ENTER';
  }

  bool _isExit(Map<String, Object?> event) {
    return _text(event['event_type']).toUpperCase() == 'EXIT';
  }

  DateTime? _dateOf(Map<String, Object?> event) {
    final raw = event['event_timestamp'];
    if (raw == null) return null;

    if (raw is DateTime) return raw.toLocal();

    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  String _dateKey(Map<String, Object?> event) {
    final date = _dateOf(event);

    if (date == null) return 'Unknown date';

    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _dateLabel(String key) {
    if (key == 'Unknown date') return key;

    final date = DateTime.tryParse(key);
    if (date == null) return key;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = DateTime(date.year, date.month, date.day);

    if (current == today) return 'Today';

    if (current == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _timeLabel(Map<String, Object?> event) {
    final value = event['event_timestamp'];

    if (value == null) return 'Time unavailable';

    return localTime(value);
  }

  String _syncStatus(Map<String, Object?> event) {
    return _text(event['sync_status'], 'Pending');
  }


  bool _isSynced(String status) {
    return status.toLowerCase() == 'synced';
  }

  bool _isFailed(String status) {
    final value = status.toLowerCase();
    return value == 'failed' || value == 'error';
  }

  Color _syncColor(String status) {
    if (_isSynced(status)) return _green;
    if (_isFailed(status)) return _red;
    return const Color(0xFFD97706);
  }

  IconData _syncIcon(String status) {
    if (_isSynced(status)) return Icons.cloud_done_rounded;
    if (_isFailed(status)) return Icons.error_outline_rounded;
    return Icons.cloud_upload_outlined;
  }

  void _openEventDetails(BuildContext context, Map<String, Object?> event) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Material(
              color: Theme.of(sheetContext).colorScheme.surface,
              child: EventDetails(event),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final events = List<Map<String, Object?>>.from(c.events);

    events.sort((a, b) {
      final aDate = _dateOf(a);
      final bDate = _dateOf(b);

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    });

    final enteredCount = events.where(_isEnter).length;
    final exitedCount = events.where(_isExit).length;

    final pendingCount = events.where((event) {
      return !_isSynced(_syncStatus(event));
    }).length;

    final grouped = <String, List<Map<String, Object?>>>{};

    for (final event in events) {
      final key = _dateKey(event);
      grouped.putIfAbsent(key, () => []).add(event);
    }

    final currentPage = (c.eventOffset ~/ AppController.pageSize) + 1;

    final hasPrevious = c.eventOffset > 0;
    final hasNext = c.events.length >= AppController.pageSize;

    return Container(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF6F8FC),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const PageTitle(
            'Location history',
            'Your work location entries and exits',
          ),

          // Summary dashboard: current page only
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activity overview',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _summaryCard(
                        context,
                        title: 'Entries',
                        value: '$enteredCount',
                        icon: Icons.login_rounded,
                        color: _green,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _summaryCard(
                        context,
                        title: 'Exits',
                        value: '$exitedCount',
                        icon: Icons.logout_rounded,
                        color: _orange,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _summaryCard(
                        context,
                        title: 'Not synced',
                        value: '$pendingCount',
                        icon: Icons.sync_problem_rounded,
                        color: _blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Showing activity counts for page $currentPage',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          if (events.isEmpty)
            _emptyState(context)
          else ...[
            for (final entry in grouped.entries) ...[
              // Date group
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _dateLabel(entry.key),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.07,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        '${entry.value.length} events',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Divider(
                        color: theme.dividerColor.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),

              // Timeline
              for (var index = 0; index < entry.value.length; index++)
                _timelineEvent(
                  context,
                  event: entry.value[index],
                  isLast: index == entry.value.length - 1,
                ),

              const SizedBox(height: 14),
            ],
          ],

          // Pagination
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: _pagination(
              context,
              currentPage: currentPage,
              hasPrevious: hasPrevious,
              hasNext: hasNext,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineEvent(
    BuildContext context, {
    required Map<String, Object?> event,
    required bool isLast,
  }) {
    final theme = Theme.of(context);

    final enter = _isEnter(event);
    final exit = _isExit(event);

    final color = enter
        ? _green
        : exit
        ? _orange
        : _blue;

    final icon = enter
        ? Icons.login_rounded
        : exit
        ? Icons.logout_rounded
        : Icons.location_on_rounded;

    final action = enter
        ? 'Entered'
        : exit
        ? 'Left'
        : _text(event['event_type'], 'Location event');

    final geofence = _text(event['geofence_name'], 'Unknown location');

    final status = _syncStatus(event);
    final synced = _isSynced(status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timeline line and indicator
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: Icon(icon, size: 19, color: color),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        color: theme.dividerColor.withValues(alpha: 0.4),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Event card
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _openEventDetails(context, event),
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  '$action $geofence',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 15,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  _timeLabel(event),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              _eventBadge(
                                label: enter
                                    ? 'ENTRY'
                                    : exit
                                    ? 'EXIT'
                                    : 'EVENT',
                                icon: icon,
                                color: color,
                              ),
                              _eventBadge(
                                label: status,
                                icon: _syncIcon(status),
                                color: _syncColor(status),
                              ),
                              if (event['background_event'] == true ||
                                  event['background_event'] == 1 ||
                                  event['background_event']
                                          ?.toString()
                                          .toLowerCase() ==
                                      'true')
                                _eventBadge(
                                  label: 'Background',
                                  icon: Icons.layers_outlined,
                                  color: _blue,
                                ),
                            ],
                          ),
                          if (!synced &&
                              _isFailed(status) &&
                              _text(event['last_error'], '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    size: 15,
                                    color: _red,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _text(event['last_error']),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: _red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventBadge({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pagination(
    BuildContext context, {
    required int currentPage,
    required bool hasPrevious,
    required bool hasNext,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous page',
            onPressed: hasPrevious ? c.previousPage : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Page $currentPage',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${c.events.length} events shown',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: hasNext ? c.nextPage : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 45),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.route_rounded, color: _blue, size: 38),
            ),
            const SizedBox(height: 20),
            Text(
              'No location events yet',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When you enter or leave a registered work location, '
              'your activity will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SyncPage extends StatelessWidget {
  final AppController c;
  const SyncPage({required this.c, super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    body: SafeArea(
      child: ListView(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(12, 16, 20, 16),
            leading: IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back),
            ),
            title: const Text(
              'Sync',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            subtitle: const Text('Uses your signed-in employee account'),
          ),
          if (c.error != null) Message(c.error!, error: true),
          if (c.notice != null) Message(c.notice!),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Metric(
                    'Pending',
                    '${c.syncCounts['pending'] ?? 0}',
                    Icons.schedule,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Metric(
                    'Failed',
                    '${c.syncCounts['failed'] ?? 0}',
                    Icons.warning_amber,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Metric(
                    'Synced',
                    '${c.syncCounts['synced'] ?? 0}',
                    Icons.cloud_done_outlined,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Employee sync',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Signed in as ${c.session.employeeName} (${c.session.employeeId}).',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  StatusChip(
                    c.deviceEnrollment['enrolled'] == true
                        ? 'Device enrolled and enabled'
                        : c.deviceEnrollmentError ??
                              'This device still needs enrollment',
                    color: c.deviceEnrollment['enrolled'] == true
                        ? AppColors.success
                        : AppColors.warning,
                    background: c.deviceEnrollment['enrolled'] == true
                        ? AppColors.successSoft
                        : AppColors.warningSoft,
                    icon: c.deviceEnrollment['enrolled'] == true
                        ? Icons.verified_user_outlined
                        : Icons.phonelink_lock_outlined,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: c.busy ? null : c.synchronize,
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync now'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: c.busy ? null : c.enrollDevice,
                    icon: const Icon(Icons.phonelink_lock),
                    label: const Text('Enroll this device'),
                  ),
                  if (c.lastSuccessfulSync != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Last synced: ${c.lastSuccessfulSync}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile
// ─────────────────────────────────────────────────────────────────────────────
class DiagnosticsPage extends StatelessWidget {
  final AppController c;
  const DiagnosticsPage({required this.c, super.key});

  String _or(String v) => v.isEmpty ? 'Not provided' : v;
  String _time(DateTime? value) => value == null
      ? 'No verified activity yet'
      : localTime(value.toIso8601String());

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const _PageAppBar(section: 'Profile'),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(AppRadius.lg + 4),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white.withValues(alpha: .2),
                backgroundImage: c.session.employeeImage.isEmpty
                    ? null
                    : NetworkImage(
                        c.session.employeeImage.startsWith('http')
                            ? c.session.employeeImage
                            : '${c.session.baseUrl}${c.session.employeeImage}',
                      ),
                child: c.session.employeeImage.isEmpty
                    ? Text(
                        c.session.employeeName.isEmpty
                            ? 'E'
                            : c.session.employeeName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.session.employeeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      c.session.employeeId,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .75),
                      ),
                    ),
                    if (c.session.designation.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: StatusChip(
                          c.session.designation,
                          color: Colors.white,
                          background: Colors.white.withValues(alpha: .16),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SectionTitle('Work', padding: _sectionPad),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              KeyValue('Designation', _or(c.session.designation)),
              KeyValue('Date of joining', _or(c.session.dateOfJoining)),
              KeyValue('Company email', _or(c.session.companyEmail)),
            ],
          ),
        ),
        const SectionTitle('Personal', padding: _sectionPad),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              KeyValue('Date of birth', _or(c.session.dateOfBirth)),
              KeyValue('Gender', _or(c.session.gender)),
              KeyValue('Personal email', _or(c.session.personalEmail)),
              KeyValue('Cell number', _or(c.session.cellNumber)),
              KeyValue('Emergency phone', _or(c.session.emergencyPhoneNumber)),
            ],
          ),
        ),
        const SectionTitle('Tracking health', padding: _sectionPad),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              KeyValue(
                'Overall status',
                c.monitoringStatus?.ready == true
                    ? ((c.syncCounts['pending'] ?? 0) > 0
                          ? 'Configured · synchronization pending'
                          : 'Configured')
                    : 'Action required',
              ),
              KeyValue(
                'Background location',
                c.monitoringStatus?.backgroundPermission == true
                    ? 'Allowed'
                    : 'Permission blocked',
              ),
              KeyValue(
                'Precise location',
                c.monitoringStatus?.precisePermission == true
                    ? 'Allowed'
                    : 'Approximate or blocked',
              ),
              KeyValue(
                'Location services',
                c.monitoringStatus?.locationServices == true ? 'On' : 'Off',
              ),
              KeyValue(
                'Google Play services',
                c.monitoringStatus?.googlePlayServicesAvailable == true
                    ? 'Available'
                    : 'Unavailable or unknown',
              ),
              KeyValue(
                'Registered workplaces',
                '${c.monitoringStatus?.registeredGeofenceCount ?? 0}',
              ),
              KeyValue(
                'Last registration check',
                c.registrationError == null
                    ? _time(c.lastRegistrationAttempt)
                    : 'Failed · ${c.registrationError}',
              ),
              KeyValue('Last recorded event', _time(c.lastRecordedEvent)),
              KeyValue('Last successful sync', _time(c.lastSuccessfulSync)),
              KeyValue(
                'Pending / failed sync',
                '${c.syncCounts['pending'] ?? 0} / ${c.syncCounts['failed'] ?? 0}',
              ),
              KeyValue(
                'Background sync worker',
                c.monitoringStatus?.workManagerState ?? 'UNKNOWN',
              ),
              KeyValue(
                'Battery restrictions',
                c.monitoringStatus?.ignoringBatteryOptimizations == true
                    ? 'Unrestricted by Android optimization'
                    : 'May delay callbacks or synchronization',
              ),
            ],
          ),
        ),
        const SectionTitle('Privacy and data', padding: _sectionPad),
        const AppCard(
          padding: EdgeInsets.all(16),
          child: Text(
            'GeoPulse records workplace ENTER/EXIT events and sends them to '
            'your employer’s Frappe server. A record may include event time, '
            'coordinates supplied by Android, accuracy, distance, battery and '
            'charging state, network availability signal, Android/device '
            'model, installation ID, and whether it was captured in the '
            'background. Android may delay or miss events. Force Stop disables '
            'tracking until the app is opened again. Contact your employer for '
            'the approved retention policy and privacy-policy URL.',
            style: TextStyle(color: AppColors.muted, height: 1.45),
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: c.busy ? null : c.logout,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: BorderSide(color: AppColors.danger.withValues(alpha: .35)),
          ),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}

class GeofenceDraft {
  final String name, address, assigned;
  final double lat, lon, radius;
  const GeofenceDraft(
    this.name,
    this.address,
    this.assigned,
    this.lat,
    this.lon,
    this.radius,
  );
}

class GeofenceEditor extends StatefulWidget {
  final AppController c;
  final GeofenceConfig? existing;
  const GeofenceEditor({required this.c, this.existing, super.key});
  @override
  State<GeofenceEditor> createState() => _GeofenceEditorState();
}

class _GeofenceEditorState extends State<GeofenceEditor> {
  late final TextEditingController name, address, assigned, lat, lon, radius;
  String? error;
  bool locating = false;
  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    name = TextEditingController(text: g?.name);
    address = TextEditingController(text: g?.address);
    assigned = TextEditingController(text: g?.assignedTo);
    lat = TextEditingController(text: g?.latitude.toString());
    lon = TextEditingController(text: g?.longitude.toString());
    radius = TextEditingController(
      text: (g?.radiusMeters ?? AppConstants.defaultRadiusMeters)
          .toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    name.dispose();
    address.dispose();
    assigned.dispose();
    lat.dispose();
    lon.dispose();
    radius.dispose();
    super.dispose();
  }

  Future<void> locate() async {
    setState(() => locating = true);
    try {
      await widget.c.requestMonitoringPermissions();
      final p = await widget.c.currentPosition();
      lat.text = p.latitude.toStringAsFixed(7);
      lon.text = p.longitude.toStringAsFixed(7);
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  void save() {
    final a = double.tryParse(lat.text),
        b = double.tryParse(lon.text),
        r = double.tryParse(radius.text);
    if (name.text.trim().isEmpty ||
        a == null ||
        b == null ||
        r == null ||
        a < -90 ||
        a > 90 ||
        b < -180 ||
        b > 180 ||
        r < 50 ||
        r > 10000) {
      setState(
        () => error =
            'Enter a name, valid coordinates, and a radius from 50 to 10,000 meters.',
      );
      return;
    }
    Navigator.pop(
      context,
      GeofenceDraft(
        name.text.trim(),
        address.text.trim(),
        assigned.text.trim(),
        a,
        b,
        r,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Text(
            widget.existing == null ? 'New location' : 'Edit location',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const Text(
            'Native geofencing saves battery by avoiding continuous GPS.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: address,
            decoration: const InputDecoration(labelText: 'Address or note'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: assigned,
            decoration: const InputDecoration(
              labelText: 'Assigned user reference',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: lat,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Latitude'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: lon,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Longitude'),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: locating ? null : locate,
              icon: locating
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: const Text('Use current location'),
            ),
          ),
          TextField(
            controller: radius,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Radius in meters',
              helperText: '50–10,000; default 200',
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Message(error!, error: true, margin: EdgeInsets.zero),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: save,
            icon: const Icon(Icons.radar),
            label: const Text('Save and monitor'),
          ),
        ],
      ),
    ),
  );
}

class EventDetails extends StatelessWidget {
  final Map<String, Object?> event;

  const EventDetails(this.event, {super.key});

  String _value(String key) {
    final value = event[key];

    if (value == null || value.toString().trim().isEmpty) {
      return 'Not available';
    }

    return value.toString();
  }

  String _yesNo(String key) {
    final value = event[key];

    if (value == null) return 'Not available';

    if (value == true ||
        value == 1 ||
        value.toString().toLowerCase() == 'true' ||
        value.toString() == '1') {
      return 'Yes';
    }

    if (value == false ||
        value == 0 ||
        value.toString().toLowerCase() == 'false' ||
        value.toString() == '0') {
      return 'No';
    }

    return value.toString();
  }

  String _unitValue(String key, String unit) {
    final value = event[key];

    if (value == null || value.toString().trim().isEmpty) {
      return 'Not available';
    }

    final number = num.tryParse(value.toString());

    if (number == null) return value.toString();

    return '${number.toStringAsFixed(1)} $unit';
  }

  String _dateValue(String key) {
    final raw = event[key];

    if (raw == null) return 'Not available';

    final date = DateTime.tryParse(raw.toString());

    if (date == null) return raw.toString();

    final local = date.toLocal();

    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final eventType = _value('event_type').toUpperCase();
    final isEnter = eventType.contains('ENTER');
    final isExit = eventType.contains('EXIT');

    final eventColor = isEnter
        ? const Color(0xFF16A34A)
        : isExit
        ? const Color(0xFFEA580C)
        : const Color(0xFF2563EB);

    final eventIcon = isEnter
        ? Icons.login_rounded
        : isExit
        ? Icons.logout_rounded
        : Icons.location_on_rounded;

    final syncStatus = _value('sync_status');
    final isSynced = syncStatus.toLowerCase() == 'synced';

    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    final backgroundColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF5F7FB);

    return SafeArea(
      child: Container(
        color: backgroundColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bottom sheet drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 14),
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),

            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Event Details',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Event overview
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: eventColor.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: eventColor.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: eventColor.withValues(alpha: 0.14),
                          child: Icon(eventIcon, color: eventColor, size: 32),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          eventType,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: eventColor,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _value('geofence_name'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _dateValue('event_timestamp'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _statusChip(
                              label: syncStatus,
                              icon: isSynced
                                  ? Icons.cloud_done_rounded
                                  : Icons.cloud_upload_outlined,
                              color: isSynced
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFD97706),
                            ),
                            _statusChip(
                              label: _yesNo('background_event') == 'Yes'
                                  ? 'Background'
                                  : 'Foreground',
                              icon: Icons.layers_outlined,
                              color: const Color(0xFF2563EB),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  _section(
                    title: 'Location Information',
                    icon: Icons.location_on_outlined,
                    color: const Color(0xFF2563EB),
                    surfaceColor: surfaceColor,
                    children: [
                      _detailRow(
                        Icons.place_outlined,
                        'Geofence Name',
                        _value('geofence_name'),
                      ),
                      _detailRow(
                        Icons.my_location_rounded,
                        'Latitude',
                        _value('latitude'),
                      ),
                      _detailRow(
                        Icons.explore_outlined,
                        'Longitude',
                        _value('longitude'),
                      ),
                      _detailRow(
                        Icons.gps_fixed_rounded,
                        'GPS Accuracy',
                        _unitValue('accuracy_meters', 'm'),
                      ),
                      _detailRow(
                        Icons.social_distance_rounded,
                        'Distance from Center',
                        _unitValue('distance_from_center_meters', 'm'),
                      ),
                      _detailRow(
                        Icons.radio_button_unchecked_rounded,
                        'Geofence Radius',
                        _unitValue('radius_meters', 'm'),
                        isLast: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _section(
                    title: 'Battery & Connectivity',
                    icon: Icons.battery_charging_full_rounded,
                    color: const Color(0xFF16A34A),
                    surfaceColor: surfaceColor,
                    children: [
                      _detailRow(
                        Icons.battery_std_rounded,
                        'Battery Level',
                        _unitValue('battery_percentage', '%'),
                      ),
                      _detailRow(
                        Icons.bolt_rounded,
                        'Charging Status',
                        _value('charging_status'),
                      ),
                      _detailRow(
                        Icons.network_cell_rounded,
                        'Network Type',
                        _value('network_type'),
                      ),
                      _detailRow(
                        Icons.wifi_rounded,
                        'Internet Available',
                        _yesNo('internet_available'),
                        isLast: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _section(
                    title: 'Device Information',
                    icon: Icons.smartphone_rounded,
                    color: const Color(0xFF7C3AED),
                    surfaceColor: surfaceColor,
                    children: [
                      _detailRow(
                        Icons.fingerprint_rounded,
                        'Device ID',
                        _value('device_id'),
                      ),
                      _detailRow(
                        Icons.android_rounded,
                        'Android Version',
                        _value('android_version'),
                      ),
                      _detailRow(
                        Icons.business_outlined,
                        'Manufacturer',
                        _value('device_manufacturer'),
                      ),
                      _detailRow(
                        Icons.phone_android_rounded,
                        'Device Model',
                        _value('device_model'),
                        isLast: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _section(
                    title: 'Synchronization',
                    icon: Icons.sync_rounded,
                    color: const Color(0xFF0891B2),
                    surfaceColor: surfaceColor,
                    children: [
                      _detailRow(
                        Icons.cloud_done_outlined,
                        'Sync Status',
                        syncStatus,
                        valueColor: isSynced
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFD97706),
                      ),
                      _detailRow(
                        Icons.repeat_rounded,
                        'Retry Count',
                        _value('retry_count'),
                      ),
                      _detailRow(
                        Icons.access_time_rounded,
                        'Synced At',
                        _dateValue('synced_at'),
                      ),
                      _detailRow(
                        Icons.error_outline_rounded,
                        'Last Error',
                        _value('last_error'),
                        isLast: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Center(
                    child: Text(
                      'Geofence Event Log',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Color color,
    required Color surfaceColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.13)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    bool isLast = false,
    Color? valueColor,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    flex: 4,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: SelectableText(
                      value,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: valueColor ?? theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!isLast)
              Divider(
                height: 1,
                color: theme.dividerColor.withValues(alpha: 0.3),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared components
// ─────────────────────────────────────────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppRadius.md),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: child,
      ),
    ),
  );
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color, background;
  final IconData? icon;
  const StatusChip(
    this.label, {
    required this.color,
    required this.background,
    this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: icon == Icons.circle ? 8 : 14, color: color),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconTile(this.icon, this.color);
  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Icon(icon, color: color, size: 22),
  );
}

class _IconBubble extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  const _IconBubble({required this.icon, this.onTap, this.tooltip});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip ?? '',
    child: Material(
      color: Colors.white,
      shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppColors.text, size: 22),
        ),
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  final String name;
  final double radius;
  const _Avatar({required this.name, this.radius = 22});
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: AppColors.primary,
    child: Text(
      name.isEmpty ? 'E' : name[0].toUpperCase(),
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
    ),
  );
}

class Metric extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const Metric(this.label, this.value, this.icon, {super.key});
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
            height: 1,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    ),
  );
}

class EventSummary extends StatelessWidget {
  final String label;
  final Map<String, Object?>? event;
  final IconData icon;
  final Color color;
  const EventSummary(
    this.label,
    this.event,
    this.icon,
    this.color, {
    super.key,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
    child: AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _IconTile(icon, color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  event == null
                      ? 'No event recorded'
                      : '${event!['geofence_name']} • ${localTime(event!['event_timestamp'])}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class Message extends StatelessWidget {
  final String text;
  final bool error;
  final EdgeInsetsGeometry margin;
  const Message(
    this.text, {
    this.error = false,
    this.margin = const EdgeInsets.fromLTRB(20, 0, 20, 10),
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    final color = error ? AppColors.danger : AppColors.success;
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? AppColors.dangerSoft : AppColors.successSoft,
        border: Border.all(color: color.withValues(alpha: .25)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error ? Icons.error_outline_rounded : Icons.check_circle_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class Check extends StatelessWidget {
  final String label;
  final bool value, optional;
  const Check(this.label, this.value, {this.optional = false, super.key});
  @override
  Widget build(BuildContext context) {
    final color = value
        ? AppColors.success
        : optional
        ? AppColors.warning
        : AppColors.danger;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(
        value
            ? Icons.check_circle_rounded
            : optional
            ? Icons.info_outline
            : Icons.cancel_rounded,
        color: color,
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: StatusChip(
        value
            ? 'Ready'
            : optional
            ? 'Recommended'
            : 'Required',
        color: color,
        background: color.withValues(alpha: .12),
      ),
    );
  }
}

class KeyValue extends StatelessWidget {
  final String label, value;
  const KeyValue(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.text,
              fontSize: 13.5,
            ),
          ),
        ),
      ],
    ),
  );
}

class SectionTitle extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry padding;
  const SectionTitle(
    this.text, {
    this.padding = const EdgeInsets.fromLTRB(20, 22, 20, 8),
    super.key,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Text(text, style: _sectionStyle),
  );
}

class Empty extends StatelessWidget {
  final IconData icon;
  final String title, text;
  const Empty(this.icon, this.title, this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
    child: Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: AppColors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 34, color: AppColors.primary),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
      ],
    ),
  );
}

String localTime(Object? value) {
  final d = DateTime.tryParse('$value');
  return d == null ? 'unknown' : d.toLocal().toString();
}
