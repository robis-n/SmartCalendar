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
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
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
    final totalFriends = _accepted.length;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        // ── Editorial Header ──────────────────────────────
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('FRIENDS',
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppColors.accent, letterSpacing: 2.0,
                )),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Text(totalFriends == 0 ? 'No friends yet' : '$totalFriends friend${totalFriends == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w900,
                    color: AppColors.label, letterSpacing: -1,
                  )),
                const Spacer(),
                GestureDetector(
                  onTap: _addFriendDialog,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.person_add_outlined, color: AppColors.accent, size: 18),
                  ),
                ),
              ]),
            ]),
          ),
        ),

        // ── Body ──────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.accent))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.accent,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                    children: [
                      // Incoming requests
                      if (_incoming.isNotEmpty) ...[
                        _sectionLabel('Requests', badge: _incoming.length),
                        const SizedBox(height: 8),
                        _card(children: _incoming.mapIndexed((i, f) => _requestTile(f, i, _incoming.length)).toList()),
                        const SizedBox(height: 16),
                      ],

                      // Friends
                      _sectionLabel('Friends'),
                      const SizedBox(height: 8),
                      if (_accepted.isEmpty)
                        _emptyCard('No friends yet — tap + to add one')
                      else
                        _card(children: _accepted.mapIndexed((i, f) => _friendTile(f, i, _accepted.length)).toList()),
                      const SizedBox(height: 16),

                      // Challenges
                      _sectionLabel('Challenges'),
                      const SizedBox(height: 8),
                      if (_challenges.isEmpty)
                        _emptyCard('No active challenges')
                      else
                        _card(children: _challenges.mapIndexed((i, c) => _challengeTile(c, i, _challenges.length)).toList()),
                      const SizedBox(height: 16),

                      // Sent requests
                      if (_sent.isNotEmpty) ...[
                        _sectionLabel('Sent'),
                        const SizedBox(height: 8),
                        _card(children: _sent.mapIndexed((i, f) => _sentTile(f, i, _sent.length)).toList()),
                      ],
                    ],
                  ),
                ),
        ),
      ]),
    );
  }

  // ── Section helpers ───────────────────────────────────

  Widget _sectionLabel(String title, {int? badge}) => Row(children: [
    Text(title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11, color: AppColors.label3,
        fontWeight: FontWeight.w700, letterSpacing: 0.8,
      )),
    if (badge != null && badge > 0) ...[
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
        child: Text('$badge',
          style: const TextStyle(fontSize: 10, color: AppColors.bg, fontWeight: FontWeight.w700)),
      ),
    ],
  ]);

  Widget _card({required List<Widget> children}) => Container(
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      boxShadow: cardShadow,
    ),
    clipBehavior: Clip.hardEdge,
    child: Column(children: children),
  );

  Widget _emptyCard(String text) => Container(
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      boxShadow: cardShadow,
    ),
    padding: const EdgeInsets.all(20),
    child: Center(
      child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.label3)),
    ),
  );

  Widget _requestTile(Map<String, dynamic> f, int i, int total) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        _avatar(_email(f)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_email(f), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.label)),
          const SizedBox(height: 2),
          const Text('wants to connect', style: TextStyle(fontSize: 12, color: AppColors.label3)),
        ])),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () async { await SupabaseService.declineFriendRequest(f['id']); _load(); },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Decline', style: TextStyle(fontSize: 12, color: AppColors.label2, fontWeight: FontWeight.w500)),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () async {
            await SupabaseService.acceptFriendRequest(f['id']);
            _snack('Connected!');
            _load();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Accept', style: TextStyle(fontSize: 12, color: AppColors.bg, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    ),
    if (i < total - 1) const Divider(height: 1, indent: 68, endIndent: 16),
  ]);

  Widget _friendTile(Map<String, dynamic> f, int i, int total) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        _avatar(_email(f)),
        const SizedBox(width: 12),
        Expanded(child: Text(_email(f),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.label))),
        GestureDetector(
          onTap: () => _challengeDialog(f),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Challenge',
              style: TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context,
            builder: (ctx) => SafeArea(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.person_remove_outlined, color: AppColors.destructive),
                  title: const Text('Remove friend', style: TextStyle(color: AppColors.destructive)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await SupabaseService.declineFriendRequest(f['id']);
                    _load();
                  },
                ),
              ],
            )),
          ),
          child: const Icon(Icons.more_horiz, size: 20, color: AppColors.label3),
        ),
      ]),
    ),
    if (i < total - 1) const Divider(height: 1, indent: 68, endIndent: 16),
  ]);

  Widget _challengeTile(Map<String, dynamic> c, int i, int total) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.emoji_events, size: 20, color: AppColors.warning),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c['title'] ?? '',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.label)),
          const SizedBox(height: 2),
          Text(
            'with ${_partnerEmail(c)} · ${DateTime.now().difference(DateTime.parse(c['created_at'])).inDays}d',
            style: const TextStyle(fontSize: 12, color: AppColors.label3),
          ),
        ])),
        GestureDetector(
          onTap: () async {
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
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.destructiveBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.flag_outlined, size: 16, color: AppColors.destructive),
          ),
        ),
      ]),
    ),
    if (i < total - 1) const Divider(height: 1, indent: 68, endIndent: 16),
  ]);

  Widget _sentTile(Map<String, dynamic> f, int i, int total) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        _avatar(_email(f)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_email(f),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.label)),
          const SizedBox(height: 2),
          const Text('pending', style: TextStyle(fontSize: 12, color: AppColors.label3)),
        ])),
        GestureDetector(
          onTap: () async { await SupabaseService.declineFriendRequest(f['id']); _load(); },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 12, color: AppColors.label2)),
          ),
        ),
      ]),
    ),
    if (i < total - 1) const Divider(height: 1, indent: 68, endIndent: 16),
  ]);

  Widget _avatar(String email) => CircleAvatar(
    radius: 20,
    backgroundColor: AppColors.accent,
    child: Text(
      email.isNotEmpty ? email[0].toUpperCase() : '?',
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.bg),
    ),
  );
}

// Helper extension
extension _IndexedMap<T> on Iterable<T> {
  Iterable<Widget> mapIndexed(Widget Function(int, T) fn) sync* {
    var i = 0;
    for (final e in this) { yield fn(i++, e); }
  }
}
