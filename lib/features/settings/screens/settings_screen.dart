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

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
          : CustomScrollView(slivers: [
              // Header
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF7C5CFC), Color(0xFF5B3FD9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                      child: Row(children: [
                        // Avatar
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _email.isNotEmpty ? _email[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_email, style: const TextStyle(fontSize: 15,
                              fontWeight: FontWeight.w600, color: Colors.white),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: isAdmin ? 0.25 : 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isAdmin ? '👑 CEO Admin' : _tier.toUpperCase(),
                              style: const TextStyle(fontSize: 11, color: Colors.white,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ])),
                      ]),
                    ),
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                sliver: SliverList(delegate: SliverChildListDelegate([

                  // ── Account ───────────────────────────────────
                  _section('Account', [
                    _row(
                      icon: Icons.workspace_premium_rounded,
                      iconBg: AppColors.warningBg, iconColor: AppColors.warning,
                      title: 'Subscription',
                      trailing: _tier.toUpperCase(),
                      onTap: () => context.go('/subscriptions'),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // ── Notifications ─────────────────────────────
                  _section('Notifications', [
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
                      const Divider(height: 1, indent: 68),
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

                  // ── Privacy ───────────────────────────────────
                  _section('Privacy', [
                    _row(
                      icon: Icons.visibility_rounded,
                      iconBg: const Color(0xFFE3F2FD), iconColor: const Color(0xFF1976D2),
                      title: 'Profile visibility',
                      trailing: _visLabel(_visibility),
                      onTap: _pickVisibility,
                    ),
                    const Divider(height: 1, indent: 68),
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
                    const Divider(height: 1, indent: 68),
                    _row(
                      icon: Icons.delete_forever_rounded,
                      iconBg: AppColors.destructiveBg, iconColor: AppColors.destructive,
                      title: 'Delete my data',
                      titleColor: AppColors.destructive,
                      onTap: _deleteDialog,
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // ── About ─────────────────────────────────────
                  _section('About', [
                    _row(
                      icon: Icons.info_outline_rounded,
                      iconBg: AppColors.bg2, iconColor: AppColors.label3,
                      title: 'Version', trailing: '1.0.0', showChevron: false,
                    ),
                    const Divider(height: 1, indent: 68),
                    _row(
                      icon: Icons.shield_outlined,
                      iconBg: AppColors.bg2, iconColor: AppColors.label3,
                      title: 'Privacy Policy', onTap: _showPrivacy,
                    ),
                    const Divider(height: 1, indent: 68),
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
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: cardShadow,
                      ),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.logout_rounded, color: AppColors.destructive, size: 18),
                        SizedBox(width: 8),
                        Text('Sign Out', style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w700, color: AppColors.destructive)),
                      ]),
                    ),
                  ),
                ])),
              ),
            ]),
    );
  }

  // ── Section wrapper ────────────────────────────────────────────────────────

  Widget _section(String label, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(label.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: AppColors.label3, letterSpacing: 0.8)),
      ),
      Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: cardShadow,
        ),
        child: Column(children: children),
      ),
    ],
  );

  Widget _row({
    required IconData icon,
    required Color iconBg, required Color iconColor,
    required String title,
    String? trailing,
    Color? titleColor,
    bool showChevron = true,
    VoidCallback? onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: TextStyle(fontSize: 15,
                fontWeight: FontWeight.w500,
                color: titleColor ?? AppColors.label))),
            if (trailing != null)
              Text(trailing, style: const TextStyle(fontSize: 14, color: AppColors.label3)),
            if (showChevron && onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.label3),
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
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 15,
              fontWeight: FontWeight.w500, color: AppColors.label))),
          Switch(value: value, onChanged: onChanged),
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.separator,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Remind me before deadline',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.label)),
          ),
          const SizedBox(height: 8),
          for (final m in [5, 10, 15, 30])
            ListTile(
              title: Text('$m minutes before'),
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.separator,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Profile visibility',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.label)),
          ),
          const SizedBox(height: 8),
          for (final e in {'everyone': 'Everyone', 'friends': 'Friends only', 'private': 'Only me'}.entries)
            ListTile(
              title: Text(e.value),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Delete all data?', style: TextStyle(fontWeight: FontWeight.w700)),
          content: const Text('Deletes all tasks, verifications, friends and challenges. Cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await SupabaseService.deleteAllUserData();
                await Supabase.instance.client.auth.signOut();
                if (mounted) context.go('/login');
              },
              child: const Text('Delete', style: TextStyle(color: AppColors.destructive,
                  fontWeight: FontWeight.w700)),
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.55, maxChildSize: 0.9, minChildSize: 0.4, expand: false,
          builder: (ctx, sc) => ListView(controller: sc, padding: const EdgeInsets.all(24), children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                color: AppColors.label)),
            const SizedBox(height: 16),
            Text(body, style: const TextStyle(fontSize: 15, height: 1.7, color: AppColors.label2)),
          ]),
        ),
      );
}
