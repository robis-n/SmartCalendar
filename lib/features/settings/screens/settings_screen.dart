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
  String _tier = AppConstants.tierFree;
  String _email = '';
  bool _notificationsEnabled = true;
  int _leadMinutes = 15;
  String _profileVisibility = 'friends';
  bool _shareAnalytics = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profile = await SupabaseService.getUserProfile();
    final prefs = Map<String, dynamic>.from(
      (profile?['preferences'] as Map?) ?? {},
    );
    final privacy = Map<String, dynamic>.from(
      (profile?['privacy_settings'] as Map?) ?? {},
    );
    setState(() {
      _tier = profile?['subscription_tier'] ?? AppConstants.tierFree;
      _email = Supabase.instance.client.auth.currentUser?.email ?? '';
      _notificationsEnabled = prefs['notifications_enabled'] as bool? ?? true;
      _leadMinutes = prefs['reminder_lead_minutes'] as int? ?? 15;
      _profileVisibility = privacy['profile_visibility'] as String? ?? 'friends';
      _shareAnalytics = privacy['share_analytics'] as bool? ?? false;
      _loading = false;
    });
    // Sync with notification service
    NotificationService.leadMinutes = _leadMinutes;
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.destructive : AppColors.success,
    ));
  }

  // ── Settings actions ───────────────────────────────────

  Future<void> _toggleNotifications(bool val) async {
    setState(() => _notificationsEnabled = val);
    await SupabaseService.updatePreferences({'notifications_enabled': val});
    if (!val) {
      await NotificationService().cancelAll();
    }
  }

  void _pickLeadTime() {
    const options = [5, 10, 15, 30];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Remind me before deadline',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(),
            ...options.map((min) => ListTile(
                  title: Text('$min minutes before'),
                  trailing: _leadMinutes == min
                      ? const Icon(Icons.check, color: AppColors.accent)
                      : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() => _leadMinutes = min);
                    NotificationService.leadMinutes = min;
                    await SupabaseService.updatePreferences({'reminder_lead_minutes': min});
                    _snack('Reminders set to $min min before deadline');
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _pickVisibility() {
    const options = {
      'everyone': 'Everyone',
      'friends': 'Friends Only',
      'private': 'Private',
    };
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Who can see your profile?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(),
            ...options.entries.map((e) => ListTile(
                  title: Text(e.value),
                  trailing: _profileVisibility == e.key
                      ? const Icon(Icons.check, color: AppColors.accent)
                      : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() => _profileVisibility = e.key);
                    await SupabaseService.updatePrivacySettings({'profile_visibility': e.key});
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleShareAnalytics(bool val) async {
    setState(() => _shareAnalytics = val);
    await SupabaseService.updatePrivacySettings({'share_analytics': val});
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete My Data'),
        content: const Text(
          'This will permanently delete all your tasks, verifications, friendships and challenges. '
          'Your account will remain but all data will be cleared.\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SupabaseService.deleteAllUserData();
              if (mounted) {
                _snack('All data deleted.');
              }
            },
            child: const Text('Delete Everything', style: TextStyle(color: AppColors.destructive)),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scroll) => Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(controller: scroll, children: const [
            Text('Privacy Policy', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            SizedBox(height: 16),
            Text(
              'SmartCalendar collects the minimum data necessary to provide you with a great productivity experience.\n\n'
              '• Account data: Your email address, used for authentication.\n'
              '• Task data: Tasks you create, including titles, descriptions, and scheduled times.\n'
              '• Verification photos: Photos you submit for task verification are stored securely.\n'
              '• Analytics data: Aggregated usage statistics to improve the app.\n\n'
              'We never sell your data. Your task data is visible only to you.\n\n'
              'You can delete all your data at any time from Settings > Delete My Data.\n\n'
              'For questions, contact privacy@smartcalendar.app',
              style: TextStyle(fontSize: 15, height: 1.6),
            ),
          ]),
        ),
      ),
    );
  }

  void _showTerms() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scroll) => Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(controller: scroll, children: const [
            Text('Terms of Service', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            SizedBox(height: 16),
            Text(
              'By using SmartCalendar, you agree to the following:\n\n'
              '1. Use the app for lawful purposes only.\n'
              '2. Do not attempt to bypass authentication or access other users\' data.\n'
              '3. Verification photos must be authentic — do not submit false evidence.\n'
              '4. The free tier allows up to 10 tasks per month.\n'
              '5. Subscriptions auto-renew unless cancelled before the renewal date.\n'
              '6. We reserve the right to suspend accounts that violate these terms.\n\n'
              'SmartCalendar is provided "as is" without warranty of any kind.\n\n'
              'Version 1.0 — Last updated June 2026',
              style: TextStyle(fontSize: 15, height: 1.6),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isAdmin = _tier == AppConstants.tierAdmin;

    return Scaffold(
      backgroundColor: AppColors.bg2,
      appBar: AppBar(title: const Text('Settings'), backgroundColor: AppColors.bg),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                // ── Profile card ────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                        child: Text(
                          _email.isNotEmpty ? _email[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.accent),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_email, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAdmin
                                  ? const Color(0xFFFFD700).withValues(alpha: 0.2)
                                  : AppColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isAdmin ? '👑 CEO Admin' : _tier.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isAdmin ? const Color(0xFFB8860B) : AppColors.accent,
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Account ─────────────────────────────
                _sectionHeader('Account'),
                _group([
                  _tile(
                    'Subscription',
                    _tier.toUpperCase(),
                    Icons.workspace_premium_outlined,
                    onTap: () => context.go('/subscriptions'),
                  ),
                ]),
                const SizedBox(height: 28),

                // ── Notifications ────────────────────────
                _sectionHeader('Notifications'),
                _group([
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_outlined, color: AppColors.label3, size: 20),
                    title: const Text('Enable Notifications', style: TextStyle(fontSize: 15)),
                    value: _notificationsEnabled,
                    onChanged: _toggleNotifications,
                  ),
                  const Divider(height: 0, indent: 52),
                  _tile(
                    'Reminder Lead Time',
                    '$_leadMinutes min before',
                    Icons.alarm_outlined,
                    onTap: _notificationsEnabled ? _pickLeadTime : null,
                    enabled: _notificationsEnabled,
                  ),
                ]),
                const SizedBox(height: 28),

                // ── Privacy ──────────────────────────────
                _sectionHeader('Privacy'),
                _group([
                  _tile(
                    'Profile Visibility',
                    _visibilityLabel(_profileVisibility),
                    Icons.visibility_outlined,
                    onTap: _pickVisibility,
                  ),
                  const Divider(height: 0, indent: 52),
                  SwitchListTile(
                    secondary: const Icon(Icons.bar_chart_outlined, color: AppColors.label3, size: 20),
                    title: const Text('Share Analytics', style: TextStyle(fontSize: 15)),
                    subtitle: const Text('Show your stats to friends', style: TextStyle(fontSize: 13, color: AppColors.label3)),
                    value: _shareAnalytics,
                    onChanged: _toggleShareAnalytics,
                  ),
                  const Divider(height: 0, indent: 52),
                  _tile(
                    'Delete My Data',
                    '',
                    Icons.delete_outline,
                    onTap: _showDeleteDialog,
                    color: AppColors.destructive,
                    chevron: false,
                  ),
                ]),
                const SizedBox(height: 28),

                // ── About ────────────────────────────────
                _sectionHeader('About'),
                _group([
                  _tile('Version', '1.0.0', Icons.info_outline, chevron: false),
                  const Divider(height: 0, indent: 52),
                  _tile('Privacy Policy', '', Icons.shield_outlined, onTap: _showPrivacyPolicy),
                  const Divider(height: 0, indent: 52),
                  _tile('Terms of Service', '', Icons.description_outlined, onTap: _showTerms),
                ]),
                const SizedBox(height: 28),

                // ── Sign out ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextButton(
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                      if (context.mounted) context.go('/login');
                    },
                    child: const Text(
                      'Sign Out',
                      style: TextStyle(color: AppColors.destructive, fontSize: 17, fontWeight: FontWeight.w400),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  String _visibilityLabel(String v) => switch (v) {
        'everyone' => 'Everyone',
        'private' => 'Private',
        _ => 'Friends Only',
      };

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(left: 32, bottom: 6),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(fontSize: 12, color: AppColors.label3, fontWeight: FontWeight.w500, letterSpacing: 0.5),
        ),
      );

  Widget _group(List<Widget> tiles) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
          child: Column(children: tiles),
        ),
      );

  Widget _tile(
    String label,
    String value,
    IconData icon, {
    VoidCallback? onTap,
    Color? color,
    bool chevron = true,
    bool enabled = true,
  }) =>
      ListTile(
        leading: Icon(icon, color: enabled ? (color ?? AppColors.label3) : AppColors.separator, size: 20),
        title: Text(label, style: TextStyle(fontSize: 15, color: enabled ? (color ?? AppColors.label) : AppColors.label3)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (value.isNotEmpty)
            Text(value, style: const TextStyle(fontSize: 15, color: AppColors.label3)),
          if (chevron) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.label3, size: 18),
          ],
        ]),
        onTap: enabled ? onTap : null,
      );
}
