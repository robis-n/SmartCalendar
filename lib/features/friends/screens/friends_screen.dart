import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});
  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  List<Map<String, dynamic>> _friendships = [];
  List<Map<String, dynamic>> _challenges  = [];
  bool _loading = true;

  String get _myId => Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final fs = await SupabaseService.getFriendships();
    final cs = await SupabaseService.getChallenges();
    if (mounted) setState(() { _friendships = fs; _challenges = cs; _loading = false; });
  }

  // ── Helpers ────────────────────────────────────────────

  List<Map<String, dynamic>> get _accepted =>
      _friendships.where((f) => f['status'] == 'accepted').toList();

  List<Map<String, dynamic>> get _incoming =>
      _friendships.where((f) => f['status'] == 'pending' && f['addressee_id'] == _myId).toList();

  List<Map<String, dynamic>> get _sent =>
      _friendships.where((f) => f['status'] == 'pending' && f['requester_id'] == _myId).toList();

  String _email(Map<String, dynamic> f) {
    if (f['requester_id'] == _myId) return (f['addressee'] as Map?)?['email'] ?? '?';
    return (f['requester'] as Map?)?['email'] ?? '?';
  }

  String _id(Map<String, dynamic> f) {
    if (f['requester_id'] == _myId) return (f['addressee'] as Map?)?['id'] ?? '';
    return (f['requester'] as Map?)?['id'] ?? '';
  }

  String _partnerEmail(Map<String, dynamic> c) {
    if (c['creator_id'] == _myId) return (c['partner'] as Map?)?['email'] ?? '?';
    return (c['creator'] as Map?)?['email'] ?? '?';
  }

  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m),
          backgroundColor: error ? AppColors.destructive : null),
    );
  }

  // ── Dialogs ────────────────────────────────────────────

  void _addFriendDialog() {
    final ctrl = TextEditingController();
    bool loading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        title: const Text('Add Friend'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Email address'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: loading ? null : () async {
              final email = ctrl.text.trim();
              if (email.isEmpty) return;
              ss(() => loading = true);
              try {
                final user = await SupabaseService.searchUserByEmail(email);
                if (!ctx.mounted) return;
                if (user == null) {
                  Navigator.pop(ctx);
                  _snack('User not found.', error: true);
                  return;
                }
                await SupabaseService.sendFriendRequest(user['id']);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _snack('Request sent!');
                _load();
              } catch (e) {
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _snack(e.toString().contains('unique') ? 'Already friends or request pending.' : 'Error: $e', error: true);
              }
            },
            child: loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Send'),
          ),
        ],
      )),
    );
  }

  void _challengeDialog(Map<String, dynamic> f) {
    final ctrl = TextEditingController();
    bool loading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        title: Text('Challenge ${_email(f).split('@')[0]}'),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Goal',
            hintText: 'e.g. Exercise every day',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: loading ? null : () async {
              if (ctrl.text.trim().isEmpty) return;
              ss(() => loading = true);
              await SupabaseService.createChallenge(partnerId: _id(f), title: ctrl.text.trim());
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _snack('Challenge started!');
              _load();
            },
            child: const Text('Start'),
          ),
        ],
      )),
    );
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: _addFriendDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 1.5))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  // Incoming requests
                  if (_incoming.isNotEmpty) ...[
                    _header('Requests', badge: _incoming.length),
                    ..._incoming.map((f) => Column(children: [
                      ListTile(
                        leading: _avatar(_email(f)),
                        title: Text(_email(f), style: const TextStyle(fontSize: 15)),
                        subtitle: const Text('wants to connect', style: TextStyle(fontSize: 13, color: AppColors.label3)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          TextButton(
                            onPressed: () async { await SupabaseService.declineFriendRequest(f['id']); _load(); },
                            child: const Text('Decline', style: TextStyle(color: AppColors.label3)),
                          ),
                          FilledButton(
                            onPressed: () async {
                              await SupabaseService.acceptFriendRequest(f['id']);
                              _snack('Connected!');
                              _load();
                            },
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 32),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              textStyle: const TextStyle(fontSize: 13),
                            ),
                            child: const Text('Accept'),
                          ),
                        ]),
                      ),
                      const Divider(height: 1, indent: 56),
                    ])),
                  ],

                  // Friends
                  _header('Friends'),
                  if (_accepted.isEmpty)
                    _empty('No friends yet')
                  else ...[
                    ..._accepted.mapIndexed((i, f) => Column(children: [
                      ListTile(
                        leading: _avatar(_email(f)),
                        title: Text(_email(f), style: const TextStyle(fontSize: 15)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          TextButton(
                            onPressed: () => _challengeDialog(f),
                            child: const Text('Challenge'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_horiz, size: 20, color: AppColors.label3),
                            onPressed: () => showModalBottomSheet(
                              context: context,
                              builder: (ctx) => SafeArea(child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.person_remove_outlined, color: AppColors.destructive),
                                    title: const Text('Remove friend', style: TextStyle(color: AppColors.destructive)),
                                    onTap: () async { Navigator.pop(ctx); await SupabaseService.declineFriendRequest(f['id']); _load(); },
                                  ),
                                ],
                              )),
                            ),
                          ),
                        ]),
                      ),
                      if (i < _accepted.length - 1) const Divider(height: 1, indent: 56),
                    ])),
                  ],

                  // Sent requests
                  if (_sent.isNotEmpty) ...[
                    _header('Sent'),
                    ..._sent.map((f) => Column(children: [
                      ListTile(
                        leading: _avatar(_email(f)),
                        title: Text(_email(f), style: const TextStyle(fontSize: 15)),
                        subtitle: const Text('pending', style: TextStyle(fontSize: 13, color: AppColors.label3)),
                        trailing: TextButton(
                          onPressed: () async { await SupabaseService.declineFriendRequest(f['id']); _load(); },
                          child: const Text('Cancel', style: TextStyle(color: AppColors.label3)),
                        ),
                      ),
                      const Divider(height: 1, indent: 56),
                    ])),
                  ],

                  // Challenges
                  _header('Challenges'),
                  if (_challenges.isEmpty)
                    _empty('No active challenges')
                  else ...[
                    ..._challenges.mapIndexed((i, c) => Column(children: [
                      ListTile(
                        leading: Container(
                          width: 40, height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.emoji_events, size: 20, color: AppColors.warning),
                        ),
                        title: Text(c['title'] ?? '', style: const TextStyle(fontSize: 15)),
                        subtitle: Text(
                          'with ${_partnerEmail(c)} · ${DateTime.now().difference(DateTime.parse(c['created_at'])).inDays}d',
                          style: const TextStyle(fontSize: 13, color: AppColors.label3),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.flag_outlined, size: 18, color: AppColors.label3),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Abandon?'),
                                content: Text(c['title'] ?? ''),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep going')),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Abandon', style: TextStyle(color: AppColors.destructive)),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) { await SupabaseService.abandonChallenge(c['id']); _load(); }
                          },
                        ),
                      ),
                      if (i < _challenges.length - 1) const Divider(height: 1, indent: 56),
                    ])),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFriendDialog,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 1,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _avatar(String email) => CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.accent.withValues(alpha: 0.12),
        child: Text(
          email.isNotEmpty ? email[0].toUpperCase() : '?',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.accent),
        ),
      );

  Widget _header(String title, {int? badge}) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
        child: Row(children: [
          Text(title.toUpperCase(),
              style: const TextStyle(fontSize: 11, color: AppColors.label3,
                  fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          if (badge != null && badge > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
              child: Text('$badge',
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      );

  Widget _empty(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Text(label, style: const TextStyle(fontSize: 15, color: AppColors.label3)),
      );
}

// Helper extension
extension _IndexedMap<T> on Iterable<T> {
  Iterable<Widget> mapIndexed(Widget Function(int, T) fn) sync* {
    var i = 0;
    for (final e in this) { yield fn(i++, e); }
  }
}
