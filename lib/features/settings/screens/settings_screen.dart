import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/supabase_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _tier = AppConstants.tierFree;
  String _email = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await SupabaseService.getUserProfile();
    setState(() {
      _tier = profile?['subscription_tier'] ?? AppConstants.tierFree;
      _email = Supabase.instance.client.auth.currentUser?.email ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _tier == AppConstants.tierAdmin;
    return Scaffold(
      backgroundColor: AppColors.bg2,
      appBar: AppBar(title: const Text('Settings'), backgroundColor: AppColors.bg),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // Profile section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.accent.withValues(alpha:0.15),
                  child: Text(_email.isNotEmpty ? _email[0].toUpperCase() : '?', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.accent)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_email, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  Row(children: [
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isAdmin ? const Color(0xFFFFD700).withValues(alpha:0.2) : AppColors.accent.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isAdmin ? '👑 CEO Admin' : _tier.toUpperCase(),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isAdmin ? const Color(0xFFB8860B) : AppColors.accent),
                      ),
                    ),
                  ]),
                ])),
              ]),
            ),
          ),
          const SizedBox(height: 24),

          _sectionHeader('Account'),
          _settingsGroup([
            _tile('Subscription', _tier.toUpperCase(), Icons.workspace_premium_outlined, onTap: () => context.go('/subscriptions')),
            _tile('Notifications', 'On', Icons.notifications_outlined),
            _tile('Calendar Integrations', '', Icons.calendar_today_outlined),
          ]),

          const SizedBox(height: 24),
          _sectionHeader('AI'),
          _settingsGroup([
            _tile('Scheduling Aggressiveness', 'Medium', Icons.auto_awesome_outlined),
            _tile('AI Tone', 'Direct', Icons.psychology_outlined),
            _tile('Learning Data', '', Icons.insights_outlined),
          ]),

          const SizedBox(height: 24),
          _sectionHeader('Privacy'),
          _settingsGroup([
            _tile('Profile Visibility', 'Friends Only', Icons.visibility_outlined),
            _tile('Share Analytics', 'Off', Icons.bar_chart_outlined),
            _tile('Delete My Data', '', Icons.delete_outline, color: AppColors.destructive),
          ]),

          const SizedBox(height: 24),
          _sectionHeader('About'),
          _settingsGroup([
            _tile('Version', '1.0.0', Icons.info_outline),
            _tile('Privacy Policy', '', Icons.shield_outlined),
            _tile('Terms of Service', '', Icons.description_outlined),
          ]),

          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton(
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) context.go('/login');
              },
              child: const Text('Sign Out', style: TextStyle(color: AppColors.destructive, fontSize: 17, fontWeight: FontWeight.w400)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(left: 32, bottom: 6),
    child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, color: AppColors.label3, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
  );

  Widget _settingsGroup(List<Widget> tiles) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        for (int i = 0; i < tiles.length; i++) ...[
          tiles[i],
          if (i < tiles.length - 1) const Divider(height: 0, indent: 52),
        ],
      ]),
    ),
  );

  Widget _tile(String label, String value, IconData icon, {VoidCallback? onTap, Color? color}) => ListTile(
    leading: Icon(icon, color: color ?? AppColors.label3, size: 20),
    title: Text(label, style: TextStyle(fontSize: 15, color: color ?? AppColors.label)),
    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
      if (value.isNotEmpty) Text(value, style: const TextStyle(fontSize: 15, color: AppColors.label3)),
      const SizedBox(width: 4),
      const Icon(Icons.chevron_right, color: AppColors.label3, size: 18),
    ]),
    onTap: onTap ?? () {},
  );
}
