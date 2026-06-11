import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
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
                  const SizedBox(height: 22),

                  // ── Social & stats (moved out of the tab bar) ─────
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

                  // ── Calendars (Apple / Google via the phone) ──────
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
      MaterialPageRoute(builder: (_) => const LoginScreen(addAccount: true)),
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

  // ── Bottom sheets / dialogs ────────────────────────────────────────────────

  String _visLabel(String v) => switch (v) {
    'everyone' => 'Everyone',
    'private'  => 'Only me',
    _          => 'Friends',
  };

  void _pickLeadTime() => showModalBottomSheet(
    context: context,
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

  void _pickVisibility() => showModalBottomSheet(
    context: context,
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
