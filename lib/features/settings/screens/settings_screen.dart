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
  String _tier        = AppConstants.tierFree;
  String _email       = '';
  bool   _notifs      = true;
  int    _leadMins    = 15;
  String _visibility  = 'friends';
  bool   _shareStats  = false;
  bool   _loading     = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final p = await SupabaseService.getUserProfile();
    final prefs   = Map<String, dynamic>.from((p?['preferences']     as Map?) ?? {});
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

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final isAdmin = _tier == AppConstants.tierAdmin;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 1.5))
          : ListView(
              children: [
                // Profile
                ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.accent.withValues(alpha: 0.12),
                    child: Text(
                      _email.isNotEmpty ? _email[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.accent),
                    ),
                  ),
                  title: Text(_email, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    isAdmin ? '👑 CEO Admin' : _tier.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      color: isAdmin ? const Color(0xFFB8860B) : AppColors.label3,
                      fontWeight: isAdmin ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 20),

                // ── Account ─────────────────────────────
                _header('Account'),
                _tile('Subscription', _tier.toUpperCase(),
                    onTap: () => context.go('/subscriptions')),
                const SizedBox(height: 20),

                // ── Notifications ────────────────────────
                _header('Notifications'),
                SwitchListTile(
                  title: const Text('Enable Notifications', style: TextStyle(fontSize: 15)),
                  value: _notifs,
                  onChanged: (v) async {
                    setState(() => _notifs = v);
                    await SupabaseService.updatePreferences({'notifications_enabled': v});
                    if (!v) await NotificationService().cancelAll();
                  },
                ),
                const Divider(height: 1, indent: 16),
                _tile(
                  'Remind me',
                  '$_leadMins min before',
                  enabled: _notifs,
                  onTap: _notifs ? _pickLeadTime : null,
                ),
                const SizedBox(height: 20),

                // ── Privacy ──────────────────────────────
                _header('Privacy'),
                _tile('Profile visibility', _visLabel(_visibility), onTap: _pickVisibility),
                const Divider(height: 1, indent: 16),
                SwitchListTile(
                  title: const Text('Share Analytics', style: TextStyle(fontSize: 15)),
                  value: _shareStats,
                  onChanged: (v) async {
                    setState(() => _shareStats = v);
                    await SupabaseService.updatePrivacySettings({'share_analytics': v});
                  },
                ),
                const Divider(height: 1, indent: 16),
                _tile('Delete my data', '', color: AppColors.destructive, onTap: _deleteDialog),
                const SizedBox(height: 20),

                // ── About ────────────────────────────────
                _header('About'),
                _tile('Version', '1.0.0', onTap: null, chevron: false),
                const Divider(height: 1, indent: 16),
                _tile('Privacy Policy', '', onTap: _showPrivacy),
                const Divider(height: 1, indent: 16),
                _tile('Terms of Service', '', onTap: _showTerms),
                const SizedBox(height: 24),

                // Sign out
                ListTile(
                  title: const Text('Sign Out',
                      style: TextStyle(fontSize: 15, color: AppColors.destructive)),
                  onTap: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (!mounted) return;
                    // ignore: use_build_context_synchronously
                    context.go('/login');
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  // ── Helpers ────────────────────────────────────────────

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Text(t.toUpperCase(),
            style: const TextStyle(fontSize: 11, color: AppColors.label3,
                fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      );

  Widget _tile(String label, String value, {
    VoidCallback? onTap, Color? color, bool chevron = true, bool enabled = true,
  }) =>
      ListTile(
        title: Text(label,
            style: TextStyle(fontSize: 15, color: enabled ? (color ?? AppColors.label) : AppColors.label3)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (value.isNotEmpty)
            Text(value, style: const TextStyle(fontSize: 15, color: AppColors.label3)),
          if (chevron) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.label3),
          ],
        ]),
        onTap: enabled ? onTap : null,
      );

  String _visLabel(String v) => switch (v) {
        'everyone' => 'Everyone',
        'private'  => 'Private',
        _          => 'Friends only',
      };

  void _pickLeadTime() => showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Remind me before deadline',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              for (final m in [5, 10, 15, 30])
                ListTile(
                  title: Text('$m minutes before'),
                  trailing: _leadMins == m ? const Icon(Icons.check, color: AppColors.accent) : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() => _leadMins = m);
                    NotificationService.leadMinutes = m;
                    await SupabaseService.updatePreferences({'reminder_lead_minutes': m});
                    _snack('Reminders set to $m min before deadline');
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );

  void _pickVisibility() => showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Who can see your profile?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              for (final e in {'everyone': 'Everyone', 'friends': 'Friends only', 'private': 'Private'}.entries)
                ListTile(
                  title: Text(e.value),
                  trailing: _visibility == e.key ? const Icon(Icons.check, color: AppColors.accent) : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() => _visibility = e.key);
                    await SupabaseService.updatePrivacySettings({'profile_visibility': e.key});
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );

  void _deleteDialog() => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete my data'),
          content: const Text(
              'Deletes all tasks, verifications, friends and challenges. Cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await SupabaseService.deleteAllUserData();
                await Supabase.instance.client.auth.signOut();
                if (mounted) context.go('/login');
              },
              child: const Text('Delete', style: TextStyle(color: AppColors.destructive)),
            ),
          ],
        ),
      );

  void _showPrivacy() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.4, expand: false,
          builder: (ctx, sc) => Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(controller: sc, children: const [
              Text('Privacy Policy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              SizedBox(height: 16),
              Text(
                'SmartCalendar collects the minimum data necessary.\n\n'
                '• Email address for authentication\n'
                '• Tasks you create\n'
                '• Verification photos (stored securely)\n\n'
                'We never sell your data. Delete all data anytime from Settings.',
                style: TextStyle(fontSize: 15, height: 1.6),
              ),
            ]),
          ),
        ),
      );

  void _showTerms() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.4, expand: false,
          builder: (ctx, sc) => Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(controller: sc, children: const [
              Text('Terms of Service', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              SizedBox(height: 16),
              Text(
                '1. Use for lawful purposes only.\n'
                '2. Do not submit false verification photos.\n'
                '3. Free tier: up to 10 tasks/month.\n'
                '4. Subscriptions auto-renew unless cancelled.\n\n'
                'SmartCalendar v1.0 — June 2026',
                style: TextStyle(fontSize: 15, height: 1.6),
              ),
            ]),
          ),
        ),
      );
}
