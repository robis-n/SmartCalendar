import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/notification_service.dart';
import '../../../services/supabase_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _tier       = AppConstants.tierFree;
  String _email      = '';
  bool   _notifs     = true;
  int    _leadMins   = 15;
  String _visibility = 'friends';
  bool   _shareStats = false;
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

  @override
  Widget build(BuildContext context) {
    final isAdmin = _tier == AppConstants.tierAdmin;
    final initial = _email.isNotEmpty ? _email[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
          : CustomScrollView(slivers: [
              // ── Editorial header ────────────────────────────────
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('PROFILE',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: AppColors.accent, letterSpacing: 2.0,
                        )),
                      const SizedBox(height: 20),
                      Row(children: [
                        // Avatar with gold ring
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.accentLight,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 1.5),
                          ),
                          child: Center(child: Text(initial,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                                color: AppColors.accent))),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_email,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                                color: AppColors.label),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: isAdmin ? AppColors.accentLight : AppColors.bg2,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isAdmin
                                    ? AppColors.accent.withValues(alpha: 0.4)
                                    : AppColors.separator,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              isAdmin ? 'CEO ADMIN' : _tier.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                color: isAdmin ? AppColors.accent : AppColors.label3,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ])),
                      ]),
                    ]),
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                sliver: SliverList(delegate: SliverChildListDelegate([

                  // ── Account ───────────────────────────────────────
                  _sectionLabel('ACCOUNT'),
                  _section([
                    _row(
                      icon: Icons.workspace_premium_rounded,
                      iconBg: AppColors.warningBg, iconColor: AppColors.warning,
                      title: 'Subscription',
                      trailing: _tier.toUpperCase(),
                      onTap: () => context.go('/subscriptions'),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // ── Notifications ─────────────────────────────────
                  _sectionLabel('NOTIFICATIONS'),
                  _section([
                    _switchRow(
                      icon: Icons.notifications_rounded,
                      iconBg: AppColors.accentLight, iconColor: AppColors.accent,
                      title: 'Enable notifications',
                      value: _notifs,
                      onChanged: (v) async {
                        setState(() => _notifs = v);
                        await SupabaseService.updatePreferences({'notifications_enabled': v});
                        if (!v) await NotificationService().cancelAll();
                      },
                    ),
                    if (_notifs) ...[
                      Container(height: 0.5, color: AppColors.separator,
                          margin: const EdgeInsets.only(left: 68)),
                      _row(
                        icon: Icons.timer_rounded,
                        iconBg: AppColors.successBg, iconColor: AppColors.success,
                        title: 'Remind me',
                        trailing: '$_leadMins min before',
                        onTap: _pickLeadTime,
                      ),
                    ],
                  ]),
                  const SizedBox(height: 20),

                  // ── Privacy ───────────────────────────────────────
                  _sectionLabel('PRIVACY'),
                  _section([
                    _row(
                      icon: Icons.visibility_rounded,
                      iconBg: AppColors.bg2, iconColor: AppColors.label2,
                      title: 'Profile visibility',
                      trailing: _visLabel(_visibility),
                      onTap: _pickVisibility,
                    ),
                    Container(height: 0.5, color: AppColors.separator,
                        margin: const EdgeInsets.only(left: 68)),
                    _switchRow(
                      icon: Icons.bar_chart_rounded,
                      iconBg: AppColors.successBg, iconColor: AppColors.success,
                      title: 'Share analytics',
                      value: _shareStats,
                      onChanged: (v) async {
                        setState(() => _shareStats = v);
                        await SupabaseService.updatePrivacySettings({'share_analytics': v});
                      },
                    ),
                    Container(height: 0.5, color: AppColors.separator,
                        margin: const EdgeInsets.only(left: 68)),
                    _row(
                      icon: Icons.delete_forever_rounded,
                      iconBg: AppColors.destructiveBg, iconColor: AppColors.destructive,
                      title: 'Delete my data',
                      titleColor: AppColors.destructive,
                      onTap: _deleteDialog,
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // ── About ─────────────────────────────────────────
                  _sectionLabel('ABOUT'),
                  _section([
                    _row(
                      icon: Icons.info_outline_rounded,
                      iconBg: AppColors.bg2, iconColor: AppColors.label3,
                      title: 'Version', trailing: '1.0.0', showChevron: false,
                    ),
                    Container(height: 0.5, color: AppColors.separator,
                        margin: const EdgeInsets.only(left: 68)),
                    _row(
                      icon: Icons.shield_outlined,
                      iconBg: AppColors.bg2, iconColor: AppColors.label3,
                      title: 'Privacy Policy', onTap: _showPrivacy,
                    ),
                    Container(height: 0.5, color: AppColors.separator,
                        margin: const EdgeInsets.only(left: 68)),
                    _row(
                      icon: Icons.description_outlined,
                      iconBg: AppColors.bg2, iconColor: AppColors.label3,
                      title: 'Terms of Service', onTap: _showTerms,
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Sign out
                  GestureDetector(
                    onTap: () async {
                      await Supabase.instance.client.auth.signOut();
                      if (!mounted) return;
                      // ignore: use_build_context_synchronously
                      context.go('/login');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.destructiveBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.destructive.withValues(alpha: 0.3), width: 0.5),
                      ),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.logout_rounded, color: AppColors.destructive, size: 16),
                        SizedBox(width: 8),
                        Text('Sign Out',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                              color: AppColors.destructive, letterSpacing: 0.5)),
                      ]),
                    ),
                  ),
                ])),
              ),
            ]),
    );
  }

  // ── Section helpers ────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(label,
      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
          color: AppColors.label3, letterSpacing: 1.5)),
  );

  Widget _section(List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 0),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.separator, width: 0.5),
      boxShadow: cardShadow,
    ),
    child: Column(children: children),
  );

  Widget _row({
    required IconData icon,
    required Color iconBg, required Color iconColor,
    required String title,
    String? trailing,
    Color? titleColor,
    bool showChevron = true,
    VoidCallback? onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(title,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500,
              color: titleColor ?? AppColors.label))),
        if (trailing != null)
          Text(trailing,
            style: const TextStyle(fontSize: 13, color: AppColors.label3)),
        if (showChevron && onTap != null) ...[
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 16, color: AppColors.label3),
        ],
      ]),
    ),
  );

  Widget _switchRow({
    required IconData icon,
    required Color iconBg, required Color iconColor,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(children: [
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, color: iconColor, size: 16),
      ),
      const SizedBox(width: 14),
      Expanded(child: Text(title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.label))),
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
      Container(width: 36, height: 4,
          decoration: BoxDecoration(color: AppColors.separator,
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 20),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Text('Remind me before deadline',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.label)),
      ),
      const SizedBox(height: 8),
      for (final m in [5, 10, 15, 30])
        ListTile(
          title: Text('$m minutes before',
              style: const TextStyle(color: AppColors.label)),
          trailing: _leadMins == m
              ? const Icon(Icons.check_rounded, color: AppColors.accent) : null,
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
      Container(width: 36, height: 4,
          decoration: BoxDecoration(color: AppColors.separator,
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 20),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Text('Profile visibility',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.label)),
      ),
      const SizedBox(height: 8),
      for (final e in {'everyone': 'Everyone', 'friends': 'Friends only', 'private': 'Only me'}.entries)
        ListTile(
          title: Text(e.value, style: const TextStyle(color: AppColors.label)),
          trailing: _visibility == e.key
              ? const Icon(Icons.check_rounded, color: AppColors.accent) : null,
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
      title: const Text('Delete all data?',
          style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.label)),
      content: const Text(
          'Deletes all tasks, verifications, friends and challenges. Cannot be undone.',
          style: TextStyle(color: AppColors.label2)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.label3))),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await SupabaseService.deleteAllUserData();
            await Supabase.instance.client.auth.signOut();
            if (mounted) context.go('/login');
          },
          child: const Text('Delete',
              style: TextStyle(color: AppColors.destructive, fontWeight: FontWeight.w700)),
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
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.label)),
        const SizedBox(height: 16),
        Text(body,
          style: const TextStyle(fontSize: 15, height: 1.7, color: AppColors.label2)),
      ]),
    ),
  );
}
