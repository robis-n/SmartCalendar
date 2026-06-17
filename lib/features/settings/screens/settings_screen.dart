import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/constants/app_constants.dart';
import '../../../services/account_manager.dart';
import '../../../services/device_calendar_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/supabase_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../friends/screens/friends_screen.dart';
import '../../analytics/screens/analytics_screen.dart';
import '../../subscriptions/screens/subscription_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _tier       = AppConstants.tierFree;
  String _email      = '';
  bool   _notifs     = true;
  int    _leadMins   = 15;
  String _visibility = 'friends';
  bool   _shareStats = false;
  bool   _deviceCals = DeviceCalendarService.enabled;
  bool   _loading    = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final p = await SupabaseService.getUserProfile();
    final prefs   = Map<String, dynamic>.from((p?['preferences']      as Map?) ?? {});
    final privacy = Map<String, dynamic>.from((p?['privacy_settings'] as Map?) ?? {});
    if (mounted) {
      setState(() {
        _tier       = p?['subscription_tier'] ?? AppConstants.tierFree;
        _email      = Supabase.instance.client.auth.currentUser?.email ?? '';
        _notifs     = prefs['notifications_enabled']  as bool?   ?? true;
        _leadMins   = prefs['reminder_lead_minutes']  as int?    ?? 15;
        _visibility = privacy['profile_visibility']   as String? ?? 'friends';
        _shareStats = privacy['share_analytics']      as bool?   ?? false;
        _loading    = false;
      });
      NotificationService.leadMinutes = _leadMins;
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _push(Widget screen) =>
      Navigator.of(context).push(CupertinoPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final flags = ref.watch(featureFlagsProvider);
    final isAdmin = _tier == AppConstants.tierAdmin;
    final initial = _email.isNotEmpty ? _email[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.label, strokeWidth: 2))
          : CustomScrollView(slivers: [
              // ── Header ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: Column(children: [
                      Container(
                        width: 76, height: 76,
                        decoration: BoxDecoration(
                          color: AppColors.bg2,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.label, width: 1.5),
                        ),
                        child: Center(child: Text(initial,
                          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
                              color: AppColors.label))),
                      ),
                      const SizedBox(height: 14),
                      Text(_email,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                            color: AppColors.label, letterSpacing: -0.3),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAdmin ? AppColors.label : AppColors.bg2,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.separator, width: 1),
                        ),
                        child: Text(
                          isAdmin ? 'CEO ADMIN' : _tier.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: isAdmin ? AppColors.bg : AppColors.label3,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 130),
                sliver: SliverList(delegate: SliverChildListDelegate([

                  // ── Appearance ────────────────────────────────────
                  _sectionLabel('APPEARANCE'),
                  _ThemeSelector(
                    mode: themeMode,
                    onChanged: (m) => ref.read(themeModeProvider.notifier).set(m),
                  ),
                  const SizedBox(height: 12),
                  _TextSizeSelector(
                    scale: ref.watch(textScaleProvider),
                    onChanged: (s) => ref.read(textScaleProvider.notifier).set(s),
                  ),
                  const SizedBox(height: 12),
                  _AccentColorPicker(
                    selectedIndex: ref.watch(accentColorProvider),
                    customColor: ref.watch(customAccentColorProvider),
                    onPick: (i) => ref.read(accentColorProvider.notifier).pick(i),
                    onPickCustomColor: (color) {
                      ref.read(customAccentColorProvider.notifier).set(color);
                      ref.read(accentColorProvider.notifier).pick(kCustomAccentIndex);
                    },
                  ),
                  const SizedBox(height: 12),
                  _TimeFormatSelector(
                    use24h: ref.watch(timeFormatProvider),
                    onChanged: (v) => ref.read(timeFormatProvider.notifier).set(v),
                  ),
                  const SizedBox(height: 22),

                  // ── Features — show only what you use ─────────────
                  _sectionLabel('FEATURES'),
                  _section([
                    for (var i = 0; i < Feature.all.length; i++) ...[
                      if (i > 0) _divider(),
                      _featureRow(Feature.all[i], flags),
                    ],
                  ]),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
                    child: Text(
                      'Turn off what you don\'t use to keep the app lean. You can switch anything back on here anytime.',
                      style: TextStyle(fontSize: 12, color: AppColors.label3, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Calendars (Apple / Google via the phone) ──────
                  // Placed high up for accessibility — it's a primary control.
                  if (!kIsWeb) ...[
                    _sectionLabel('CALENDARS'),
                    _section([
                      _switchRow(
                        icon: Icons.calendar_month_outlined,
                        title: 'Show phone calendars',
                        value: _deviceCals,
                        onChanged: (v) async {
                          if (v) {
                            final ok = await DeviceCalendarService.ensurePermission();
                            if (!ok) {
                              _snack('Calendar access was denied — allow it in iOS Settings');
                              return;
                            }
                          }
                          await DeviceCalendarService.setEnabled(v);
                          setState(() => _deviceCals = v);
                        },
                      ),
                      if (_deviceCals) ...[
                        _divider(),
                        _row(
                          icon: Icons.checklist_rounded,
                          title: 'Choose calendars',
                          onTap: _pickCalendars,
                        ),
                      ],
                    ]),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
                      child: Text(
                        'Events from Apple Calendar and any Google accounts on this phone appear inside your calendar. Read-only — your tasks stay private.',
                        style: TextStyle(fontSize: 12, color: AppColors.label3, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 22),
                  ],

                  // ── Social & stats (hidden when the feature is off) ─
                  if (flags[Feature.social] ?? true) ...[
                    _sectionLabel('SOCIAL & STATS'),
                    _section([
                      _row(
                        icon: Icons.people_outline_rounded,
                        title: 'Friends',
                        onTap: () => _push(const FriendsScreen()),
                      ),
                      _divider(),
                      _row(
                        icon: Icons.bar_chart_rounded,
                        title: 'Statistics',
                        onTap: () => _push(const AnalyticsScreen()),
                      ),
                    ]),
                    const SizedBox(height: 22),
                  ],

                  // ── Account ───────────────────────────────────────
                  _sectionLabel('ACCOUNT'),
                  _section([
                    _row(
                      icon: Icons.workspace_premium_outlined,
                      title: 'Subscription',
                      trailing: _tier.toUpperCase(),
                      onTap: () => _push(const SubscriptionScreen()),
                    ),
                  ]),
                  const SizedBox(height: 22),

                  // ── Accounts — instant switching, no retyping ─────
                  _sectionLabel('ACCOUNTS'),
                  _accountsSection(),
                  const SizedBox(height: 22),

                  // ── Notifications ─────────────────────────────────
                  _sectionLabel('NOTIFICATIONS'),
                  _section([
                    _switchRow(
                      icon: Icons.notifications_none_rounded,
                      title: 'Enable notifications',
                      value: _notifs,
                      onChanged: (v) async {
                        setState(() => _notifs = v);
                        await SupabaseService.updatePreferences({'notifications_enabled': v});
                        if (!v) await NotificationService().cancelAll();
                      },
                    ),
                    if (_notifs) ...[
                      _divider(),
                      _row(
                        icon: Icons.timer_outlined,
                        title: 'Remind me',
                        trailing: '$_leadMins min before',
                        onTap: _pickLeadTime,
                      ),
                      _divider(),
                      // On-device diagnosis for "it never fired": one tap
                      // proves permission + scheduling + timezone end-to-end.
                      _row(
                        icon: Icons.notification_add_outlined,
                        title: 'Send test reminder',
                        trailing: 'fires in 30 s',
                        onTap: () async {
                          final ok =
                              await NotificationService().permissionsGranted();
                          if (!ok) {
                            _snack('Notifications are off for SmartCalendar — '
                                'enable them in iOS Settings → Notifications');
                            return;
                          }
                          await NotificationService().scheduleTestIn30s();
                          _snack('Scheduled — lock your phone and wait 30 s');
                        },
                      ),
                    ],
                  ]),
                  const SizedBox(height: 22),

                  // ── Privacy ───────────────────────────────────────
                  _sectionLabel('PRIVACY'),
                  _section([
                    _row(
                      icon: Icons.visibility_outlined,
                      title: 'Profile visibility',
                      trailing: _visLabel(_visibility),
                      onTap: _pickVisibility,
                    ),
                    _divider(),
                    _switchRow(
                      icon: Icons.insights_outlined,
                      title: 'Share analytics',
                      value: _shareStats,
                      onChanged: (v) async {
                        setState(() => _shareStats = v);
                        await SupabaseService.updatePrivacySettings({'share_analytics': v});
                      },
                    ),
                    _divider(),
                    _row(
                      icon: Icons.delete_outline_rounded,
                      title: 'Delete my data',
                      onTap: _deleteDialog,
                    ),
                  ]),
                  const SizedBox(height: 22),

                  // ── About ─────────────────────────────────────────
                  _sectionLabel('ABOUT'),
                  _section([
                    _row(icon: Icons.info_outline_rounded, title: 'Version',
                        trailing: '1.0.0', showChevron: false),
                    _divider(),
                    _row(icon: Icons.shield_outlined, title: 'Privacy Policy',
                        onTap: _showPrivacy),
                    _divider(),
                    _row(icon: Icons.description_outlined, title: 'Terms of Service',
                        onTap: _showTerms),
                  ]),
                  const SizedBox(height: 22),

                  // Sign out — also forgets this account locally, because
                  // signOut revokes the refresh token we stored for it.
                  GestureDetector(
                    onTap: () async {
                      await AccountManager.signOutCurrent();
                      if (!mounted) return;
                      // ignore: use_build_context_synchronously
                      context.go('/login');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: AppColors.bg2,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.separator, width: 0.8),
                      ),
                      child: Center(
                        child: Text('Sign out',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                              color: AppColors.label)),
                      ),
                    ),
                  ),
                ])),
              ),
            ]),
    );
  }

  // ── Accounts (multi-session switcher) ─────────────────────────────────────

  Widget _accountsSection() {
    final accounts = AccountManager.accounts();
    final meId = AccountManager.currentUserId();
    final children = <Widget>[];

    for (var i = 0; i < accounts.length; i++) {
      final a = accounts[i];
      final isMe = a['id'] == meId;
      final username = (a['username'] as String?) ?? '';
      final title = username.isNotEmpty ? '@$username' : (a['email'] ?? '?');
      if (i > 0) children.add(_divider());
      children.add(InkWell(
        onTap: isMe ? null : () => _switchAccount(a),
        onLongPress: isMe ? null : () => _forgetAccountDialog(a),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: isMe ? AppColors.label : AppColors.bg2,
                shape: BoxShape.circle,
                border: isMe ? null : Border.all(color: AppColors.separator, width: 0.8),
              ),
              alignment: Alignment.center,
              child: Text(
                title.replaceFirst('@', '').isNotEmpty
                    ? title.replaceFirst('@', '')[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: isMe ? AppColors.bg : AppColors.label),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500,
                      color: AppColors.label)),
              if (isMe)
                Text('Current', style: TextStyle(fontSize: 12, color: AppColors.label3)),
            ])),
            if (!isMe)
              Text('Switch', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: AppColors.label3)),
          ]),
        ),
      ));
    }

    children.add(_divider());
    children.add(_row(
      icon: Icons.person_add_alt_1_outlined,
      title: 'Add account',
      onTap: _addAccount,
    ));

    return _section(children);
  }

  Future<void> _switchAccount(Map<String, dynamic> a) async {
    final err = await AccountManager.switchTo(a['id'] as String);
    if (!mounted) return;
    if (err != null) {
      _snack(err);
      setState(() {}); // dead entry was dropped — refresh the list
      return;
    }
    _snack('Switched to ${(a['username'] as String?)?.isNotEmpty == true ? '@${a['username']}' : a['email']}');
    context.go('/dashboard');
  }

  void _forgetAccountDialog(Map<String, dynamic> a) => showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text('Forget this account?',
          style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.label)),
      content: Text('${a['email']} will need to sign in again on this device.',
          style: TextStyle(color: AppColors.label2)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Keep', style: TextStyle(color: AppColors.label3))),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await AccountManager.forget(a['id'] as String);
            if (mounted) setState(() {});
          },
          child: Text('Forget',
              style: TextStyle(color: AppColors.label, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );

  Future<void> _addAccount() async {
    final ok = await Navigator.of(context, rootNavigator: true).push<bool>(
      CupertinoPageRoute(builder: (_) => const LoginScreen(addAccount: true)),
    );
    if (ok == true && mounted) {
      _snack('Account added');
      context.go('/dashboard');
    }
  }

  // ── Section helpers ────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(left: 6, bottom: 10),
    child: Text(label,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
          color: AppColors.label3, letterSpacing: 1.5)),
  );

  Widget _section(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.separator, width: 0.5),
      boxShadow: cardShadow,
    ),
    child: Column(children: children),
  );

  Widget _divider() => Container(height: 0.5, color: AppColors.separator,
      margin: const EdgeInsets.only(left: 60));

  Widget _row({
    required IconData icon,
    required String title,
    String? trailing,
    bool showChevron = true,
    VoidCallback? onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(children: [
        Icon(icon, color: AppColors.label, size: 22),
        const SizedBox(width: 16),
        Expanded(child: Text(title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.label))),
        if (trailing != null)
          Text(trailing, style: TextStyle(fontSize: 14, color: AppColors.label3)),
        if (showChevron && onTap != null) ...[
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.label3),
        ],
      ]),
    ),
  );

  Widget _switchRow({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    child: Row(children: [
      Icon(icon, color: AppColors.label, size: 22),
      const SizedBox(width: 16),
      Expanded(child: Text(title,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.label))),
      Switch.adaptive(value: value, onChanged: onChanged),
    ]),
  );

  // A feature-visibility toggle (title + subtitle + switch).
  Widget _featureRow((String, String, String) f, Map<String, bool> flags) {
    final on = flags[f.$1] ?? true;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.$2,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.label)),
            const SizedBox(height: 2),
            Text(f.$3,
                style: TextStyle(fontSize: 12, color: AppColors.label3)),
          ]),
        ),
        const SizedBox(width: 12),
        Switch.adaptive(
          value: on,
          onChanged: (v) =>
              ref.read(featureFlagsProvider.notifier).toggle(f.$1, v),
        ),
      ]),
    );
  }

  // ── Bottom sheets / dialogs ────────────────────────────────────────────────

  String _visLabel(String v) => switch (v) {
    'everyone' => 'Everyone',
    'private'  => 'Only me',
    _          => 'Friends',
  };

  void _pickLeadTime() => showModalBottomSheet(
    context: context,
    useRootNavigator: true, // cover the floating nav bar
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 12),
      Container(width: 40, height: 5,
          decoration: BoxDecoration(color: AppColors.separator,
              borderRadius: BorderRadius.circular(3))),
      const SizedBox(height: 20),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text('Remind me before deadline',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.label)),
      ),
      const SizedBox(height: 8),
      for (final m in [5, 10, 15, 30])
        ListTile(
          title: Text('$m minutes before',
              style: TextStyle(color: AppColors.label)),
          trailing: _leadMins == m
              ? Icon(Icons.check_rounded, color: AppColors.label) : null,
          onTap: () async {
            Navigator.pop(ctx);
            setState(() => _leadMins = m);
            NotificationService.leadMinutes = m;
            await SupabaseService.updatePreferences({'reminder_lead_minutes': m});
            _snack('Reminders set to $m min before');
          },
        ),
      const SizedBox(height: 8),
    ])),
  );

  // Per-calendar visibility chooser — grouped by account kind with custom
  // group support. Sections: Apple / Google / Other + user-created groups.
  Future<void> _pickCalendars() async {
    final cals = await DeviceCalendarService.allCalendars();
    if (!mounted) return;
    if (cals.isEmpty) {
      _snack('No calendars found on this device');
      return;
    }
    final hidden = DeviceCalendarService.hiddenCalendarIds();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _CalendarPickerSheet(
        cals: cals,
        hidden: hidden,
      ),
    );
  }

  void _pickVisibility() => showModalBottomSheet(
    context: context,
    useRootNavigator: true, // cover the floating nav bar
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 12),
      Container(width: 40, height: 5,
          decoration: BoxDecoration(color: AppColors.separator,
              borderRadius: BorderRadius.circular(3))),
      const SizedBox(height: 20),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text('Profile visibility',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.label)),
      ),
      const SizedBox(height: 8),
      for (final e in {'everyone': 'Everyone', 'friends': 'Friends only', 'private': 'Only me'}.entries)
        ListTile(
          title: Text(e.value, style: TextStyle(color: AppColors.label)),
          trailing: _visibility == e.key
              ? Icon(Icons.check_rounded, color: AppColors.label) : null,
          onTap: () async {
            Navigator.pop(ctx);
            setState(() => _visibility = e.key);
            await SupabaseService.updatePrivacySettings({'profile_visibility': e.key});
          },
        ),
      const SizedBox(height: 8),
    ])),
  );

  void _deleteDialog() => showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text('Delete all data?',
          style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.label)),
      content: Text(
          'Deletes all tasks, verifications, friends and challenges. Cannot be undone.',
          style: TextStyle(color: AppColors.label2)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.label3))),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await SupabaseService.deleteAllUserData();
            await Supabase.instance.client.auth.signOut();
            if (mounted) context.go('/login');
          },
          child: Text('Delete',
              style: TextStyle(color: AppColors.label, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );

  void _showPrivacy() => _sheet('Privacy Policy',
      'SmartCalendar collects the minimum data necessary.\n\n'
      '• Email address for authentication\n'
      '• Tasks you create\n'
      '• Verification photos (stored securely)\n\n'
      'We never sell your data. Delete all data anytime from Settings.');

  void _showTerms() => _sheet('Terms of Service',
      '1. Use for lawful purposes only.\n'
      '2. Do not submit false verification photos.\n'
      '3. Free tier: up to 10 tasks/month.\n'
      '4. Subscriptions auto-renew unless cancelled.\n\n'
      'SmartCalendar v1.0 — June 2026');

  void _sheet(String title, String body) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true, // cover the floating nav bar
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.55, maxChildSize: 0.9, minChildSize: 0.4, expand: false,
      builder: (ctx, sc) => ListView(controller: sc, padding: const EdgeInsets.all(28), children: [
        Text(title,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.label)),
        const SizedBox(height: 16),
        Text(body,
          style: TextStyle(fontSize: 16, height: 1.7, color: AppColors.label2)),
      ]),
    ),
  );
}

// ── Theme segmented selector ──────────────────────────────────────────────────

class _ThemeSelector extends StatelessWidget {
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;
  const _ThemeSelector({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = [
      (ThemeMode.system, Icons.brightness_auto_rounded, 'System'),
      (ThemeMode.light,  Icons.light_mode_rounded,      'Light'),
      (ThemeMode.dark,   Icons.dark_mode_rounded,       'Dark'),
    ];
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.separator, width: 0.5),
        boxShadow: cardShadow,
      ),
      child: Row(children: options.map((o) {
        final selected = mode == o.$1;
        return Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(o.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: selected ? AppColors.label : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(children: [
                Icon(o.$2, size: 22, color: selected ? AppColors.bg : AppColors.label3),
                const SizedBox(height: 6),
                Text(o.$3, style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: selected ? AppColors.bg : AppColors.label3,
                )),
              ]),
            ),
          ),
        );
      }).toList()),
    );
  }
}

// ── Time-format segmented selector (12h / 24h) ────────────────────────────────

class _TimeFormatSelector extends StatelessWidget {
  final bool use24h;
  final ValueChanged<bool> onChanged;
  const _TimeFormatSelector({required this.use24h, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = [(false, '12-hour', '9:00 PM'), (true, '24-hour', '21:00')];
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.separator, width: 0.5),
        boxShadow: cardShadow,
      ),
      child: Row(children: options.map((o) {
        final selected = use24h == o.$1;
        return Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(o.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected ? AppColors.label : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(children: [
                Text(o.$2,
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: selected ? AppColors.bg : AppColors.label3,
                    )),
                const SizedBox(height: 2),
                Text(o.$3,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected
                          ? AppColors.bg.withValues(alpha: 0.7)
                          : AppColors.label3,
                    )),
              ]),
            ),
          ),
        );
      }).toList()),
    );
  }
}

// ── Text-size segmented selector (S / M / L / XL) ─────────────────────────────

class _TextSizeSelector extends StatelessWidget {
  final double scale;
  final ValueChanged<double> onChanged;
  const _TextSizeSelector({required this.scale, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.separator, width: 0.5),
        boxShadow: cardShadow,
      ),
      child: Row(children: [
        for (var i = 0; i < TextScaleNotifier.steps.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(TextScaleNotifier.steps[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: scale == TextScaleNotifier.steps[i]
                      ? AppColors.label
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text('A',
                      style: TextStyle(
                        // Preview the size; ignore the global scaler here so
                        // the chips stay aligned.
                        fontSize: 12 + i * 3.0,
                        fontWeight: FontWeight.w800,
                        color: scale == TextScaleNotifier.steps[i]
                            ? AppColors.bg
                            : AppColors.label3,
                      )),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

// ── Theme (duotone) picker ────────────────────────────────────────────────────
// A horizontally-scrolling row of duotone swatches: each shows the dominant
// surface colour with the complementary accent as an inset dot, plus a name.
// Index 0 = Ink (monochrome). Selecting one recolours the whole app.

class _AccentColorPicker extends StatelessWidget {
  final int selectedIndex;        // 0 = Ink, 1..N = kAccentPalettes[i-1], kCustomAccentIndex = custom
  final Color customColor;
  final ValueChanged<int> onPick;
  final ValueChanged<Color> onPickCustomColor;
  const _AccentColorPicker({
    required this.selectedIndex,
    required this.customColor,
    required this.onPick,
    required this.onPickCustomColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.separator, width: 0.5),
        boxShadow: cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.palette_outlined, size: 22, color: AppColors.label),
          const SizedBox(width: 16),
          Text('Theme',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.label)),
        ]),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // Clip normally (default Clip.hardEdge) so swatches that overflow
          // horizontally are hidden by the scroll viewport instead of
          // bleeding past the card's edges. The vertical padding below is
          // part of the SCROLLABLE CONTENT, so it grows the viewport's own
          // height — that gives the selected swatch's glow room to breathe
          // without being clipped flat, without disabling clipping itself.
          padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
          child: Row(children: [
            _swatch(index: 0, name: 'Ink'),
            for (var i = 0; i < kAccentPalettes.length; i++)
              _swatch(index: i + 1, name: kAccentPalettes[i].name),
            _customSwatch(context),
          ]),
        ),
      ]),
    );
  }

  // The "Custom" swatch — shows the currently picked color (rainbow ring when
  // no custom pick yet). Opens the full HSV color picker sheet.
  Widget _customSwatch(BuildContext context) {
    final selected = selectedIndex == kCustomAccentIndex;
    return GestureDetector(
      onTap: () => _openColorSheet(context),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46, height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: selected
                  ? [BoxShadow(
                      color: customColor.withValues(alpha: 0.5),
                      blurRadius: 14, spreadRadius: 1)]
                  : null,
            ),
            child: ClipOval(
              child: Container(
                decoration: BoxDecoration(
                  gradient: selected
                      ? null
                      : const SweepGradient(colors: [
                          Color(0xFFFF3B30), Color(0xFFFF9500), Color(0xFFFFD60A),
                          Color(0xFF34C759), Color(0xFF0A84FF), Color(0xFFAF52DE),
                          Color(0xFFFF3B30),
                        ]),
                  color: selected ? customColor : null,
                  border: Border.all(
                    color: selected ? customColor : AppColors.separator,
                    width: selected ? 2.5 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: selected
                    ? Icon(Icons.check_rounded, size: 18, color: customColor.computeLuminance() > 0.4 ? Colors.black : Colors.white)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('Custom',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.label : AppColors.label3)),
        ]),
      ),
    );
  }

  void _openColorSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ColorPickerSheet(
        initialColor: customColor,
        onChanged: onPickCustomColor,
      ),
    );
  }

  Widget _swatch({required int index, required String name}) {
    final selected = index == selectedIndex;
    // Resolve the two colours this swatch previews (mode-aware).
    final Color dominant, accent;
    if (index == 0) {
      dominant = AppColors.isDark ? const Color(0xFF0B0B0D) : const Color(0xFFF6F5F1);
      accent   = AppColors.isDark ? const Color(0xFFF4F3EF) : const Color(0xFF0B0B0D);
    } else {
      final p = kAccentPalettes[index - 1];
      dominant = AppColors.isDark ? p.darkBg : p.lightBg;
      accent   = AppColors.isDark ? p.darkAccent : p.lightAccent;
    }
    return GestureDetector(
      onTap: () => onPick(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Column(children: [
          // Outer container owns the boxShadow glow (outside the clip).
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: 46, height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: selected
                  ? [BoxShadow(
                      color: accent.withValues(alpha: 0.45),
                      blurRadius: 14, spreadRadius: 1)]
                  : null,
            ),
            // ClipOval ensures the circle border and child content never bleed
            // outside the 46×46 circle — fixes the visible border-overflow bug.
            child: ClipOval(
              child: Container(
                decoration: BoxDecoration(
                  color: dominant,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? accent : AppColors.separator,
                    width: selected ? 2.5 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: selected
                    ? Icon(Icons.check_rounded, size: 18, color: accent)
                    : Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: Container(
                            width: 12, height: 12,
                            decoration: BoxDecoration(
                                color: accent, shape: BoxShape.circle),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(name,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.label : AppColors.label3)),
        ]),
      ),
    );
  }
}

// ── Full HSV color picker sheet ───────────────────────────────────────────────
// Uses flutter_colorpicker's SaturationValueIndicator + HueRingPicker so the
// user can pick ANY colour freely — hue ring on the outside, saturation/value
// square in the middle. The whole app recolours live as they drag.
class _ColorPickerSheet extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onChanged;
  const _ColorPickerSheet({required this.initialColor, required this.onChanged});
  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late Color _color = widget.initialColor;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 5,
              decoration: BoxDecoration(
                  color: AppColors.separator,
                  borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 16),
          Row(children: [
            Text('Pick a colour',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                    color: AppColors.label)),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Done',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: AppColors.label)),
            ),
          ]),
          const SizedBox(height: 12),
          HueRingPicker(
            pickerColor: _color,
            onColorChanged: (c) {
              setState(() => _color = c);
              widget.onChanged(c);
            },
            colorPickerHeight: 240,
            hueRingStrokeWidth: 28,
            enableAlpha: false,
            displayThumbColor: true,
          ),
          const SizedBox(height: 12),
          // Hex input row.
          Row(children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.bg2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.separator),
                ),
                alignment: Alignment.center,
                child: ColorPickerInput(
                  _color,
                  (c) {
                    setState(() => _color = c);
                    widget.onChanged(c);
                  },
                  enableAlpha: false,
                  embeddedText: false,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: _color, borderRadius: BorderRadius.circular(10)),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Calendar picker sheet (grouped by account kind + custom groups) ──────────

const String _kCalGroupsKey = 'calendar_custom_groups';

class _CalGroup {
  String name;
  int colorArgb;
  Set<String> calendarIds;
  _CalGroup({required this.name, required this.colorArgb, Set<String>? calendarIds})
      : calendarIds = calendarIds ?? {};

  Map<String, dynamic> toJson() => {
    'name': name,
    'color': colorArgb,
    'ids': calendarIds.toList(),
  };
  factory _CalGroup.fromJson(Map<dynamic, dynamic> m) => _CalGroup(
    name: m['name'] as String? ?? 'Group',
    colorArgb: (m['color'] as num?)?.toInt() ?? 0xFF34C759,
    calendarIds: Set<String>.from((m['ids'] as List?) ?? []),
  );
}

List<_CalGroup> _loadCalGroups() {
  try {
    final raw = Hive.box(kSettingsBox).get(_kCalGroupsKey);
    if (raw is List) {
      return raw.whereType<Map>().map((m) => _CalGroup.fromJson(m)).toList();
    }
  } catch (_) {}
  return [];
}

void _saveCalGroups(List<_CalGroup> groups) {
  try {
    Hive.box(kSettingsBox).put(
        _kCalGroupsKey, groups.map((g) => g.toJson()).toList());
  } catch (_) {}
}

class _CalendarPickerSheet extends StatefulWidget {
  final List<DeviceCalendarInfo> cals;
  final Set<String> hidden;
  const _CalendarPickerSheet({required this.cals, required this.hidden});
  @override
  State<_CalendarPickerSheet> createState() => _CalendarPickerSheetState();
}

class _CalendarPickerSheetState extends State<_CalendarPickerSheet> {
  late final Set<String> _hidden = Set.from(widget.hidden);
  late List<_CalGroup> _groups = _loadCalGroups();

  void _toggleCalendar(String id, bool visible) {
    setState(() {
      if (visible) { _hidden.remove(id); } else { _hidden.add(id); }
    });
    DeviceCalendarService.setCalendarHidden(id, !visible);
  }

  Future<void> _addGroup() async {
    final ctrl = TextEditingController();
    Color picked = const Color(0xFF0A84FF);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dlgCtx, ss) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text('New group',
              style: TextStyle(color: AppColors.label, fontWeight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              style: TextStyle(color: AppColors.label),
              decoration: InputDecoration(
                hintText: 'Group name',
                hintStyle: TextStyle(color: AppColors.label3),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.separator)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.accent)),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Text('Color:', style: TextStyle(color: AppColors.label2, fontSize: 14)),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () async {
                  Color temp = picked;
                  await showModalBottomSheet(
                    context: dlgCtx,
                    isScrollControlled: true,
                    backgroundColor: AppColors.card,
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                    builder: (_) => _ColorPickerSheet(
                      initialColor: picked,
                      onChanged: (c) => temp = c,
                    ),
                  );
                  ss(() => picked = temp);
                },
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: picked,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.separator),
                  ),
                ),
              ),
            ]),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx, false),
              child: Text('Cancel', style: TextStyle(color: AppColors.label3)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx, true),
              child: Text('Create', style: TextStyle(
                  color: AppColors.accent, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && ctrl.text.trim().isNotEmpty) {
      setState(() {
        _groups = [..._groups, _CalGroup(name: ctrl.text.trim(), colorArgb: picked.toARGB32())];
      });
      _saveCalGroups(_groups);
    }
    ctrl.dispose();
  }

  void _deleteGroup(int idx) {
    setState(() { _groups = [..._groups]..removeAt(idx); });
    _saveCalGroups(_groups);
  }

  Widget _sectionHeader(String label, {Color? dotColor, VoidCallback? onDelete}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 6),
        child: Row(children: [
          if (dotColor != null) ...[
            Container(width: 10, height: 10,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.label3,
                  letterSpacing: 0.8)),
          const Spacer(),
          if (onDelete != null)
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.delete_outline, size: 18, color: AppColors.label3),
            ),
        ]),
      );

  Widget _calRow(DeviceCalendarInfo c) {
    final visible = !_hidden.contains(c.id);
    final dot = c.color != null ? Color(c.color!) : AppColors.label2;
    final sub = switch (c.kind) {
      'google' => c.isReadOnly ? 'Google · read-only' : 'Google',
      'apple'  => c.isReadOnly ? 'Apple · read-only'  : 'Apple',
      _        => c.isReadOnly ? 'Read-only' : null,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(Icons.circle, size: 14, color: dot),
        const SizedBox(width: 14),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500,
                      color: AppColors.label)),
              if (sub != null)
                Text(sub, style: TextStyle(fontSize: 12, color: AppColors.label3)),
            ])),
        Switch.adaptive(
          value: visible,
          onChanged: (v) => _toggleCalendar(c.id, v),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apple  = widget.cals.where((c) => c.kind == 'apple').toList();
    final google = widget.cals.where((c) => c.kind == 'google').toList();
    final other  = widget.cals.where(
        (c) => c.kind != 'apple' && c.kind != 'google').toList();

    final items = <Widget>[];

    void addSection(String label, List<DeviceCalendarInfo> list, {Color? dotColor, VoidCallback? onDelete}) {
      if (list.isEmpty && onDelete == null) return;
      items.add(_sectionHeader(label, dotColor: dotColor, onDelete: onDelete));
      if (list.isEmpty) {
        items.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('No calendars assigned',
              style: TextStyle(fontSize: 13, color: AppColors.label3)),
        ));
        return;
      }
      for (var i = 0; i < list.length; i++) {
        items.add(_calRow(list[i]));
        if (i < list.length - 1) {
          items.add(Container(height: 0.5, color: AppColors.separator));
        }
      }
    }

    addSection('APPLE', apple);
    addSection('GOOGLE', google);
    addSection('OTHER', other);

    for (var gi = 0; gi < _groups.length; gi++) {
      final g = _groups[gi];
      final members = widget.cals.where((c) => g.calendarIds.contains(c.id)).toList();
      addSection(
        g.name.toUpperCase(),
        members,
        dotColor: Color(g.colorArgb),
        onDelete: () => _deleteGroup(gi),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 5,
            decoration: BoxDecoration(
                color: AppColors.separator,
                borderRadius: BorderRadius.circular(3))),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
          child: Row(children: [
            Text('Calendars',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                    color: AppColors.label, letterSpacing: -0.5)),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: AppColors.accent),
              tooltip: 'New group',
              onPressed: _addGroup,
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Done', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.label)),
            ),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            controller: scrollCtrl,
            padding: EdgeInsets.fromLTRB(
                24, 6, 24, MediaQuery.of(ctx).padding.bottom + 32),
            itemCount: items.length,
            itemBuilder: (_, i) => items[i],
          ),
        ),
      ]),
    );
  }
}
