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

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // ── Dialogs ────────────────────────────────────────────

  void _addFriendDialog() {
    final ctrl = TextEditingController();
    bool loading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        title: const Text('Add friend'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Email address'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(80, 44)),
            onPressed: loading ? null : () async {
              final email = ctrl.text.trim();
              if (email.isEmpty) return;
              ss(() => loading = true);
              try {
                final user = await SupabaseService.searchUserByEmail(email);
                if (!ctx.mounted) return;
                if (user == null) {
                  Navigator.pop(ctx);
                  _snack('User not found.');
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
                _snack(e.toString().contains('unique') ? 'Already friends or request pending.' : 'Error: $e');
              }
            },
            child: loading
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
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
            style: FilledButton.styleFrom(minimumSize: const Size(80, 44)),
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
        // ── Header ────────────────────────────────────────
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.bg2,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.separator, width: 0.8),
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.label),
                  ),
                ),
                const SizedBox(width: 14),
                Text('Friends',
                  style: TextStyle(
                    fontSize: 30, fontWeight: FontWeight.w800,
                    color: AppColors.label, letterSpacing: -1.2,
                  )),
                const Spacer(),
                GestureDetector(
                  onTap: _addFriendDialog,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.label,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person_add_alt_1_rounded, color: AppColors.bg, size: 20),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              Text(
                totalFriends == 0 ? 'No friends yet' : '$totalFriends friend${totalFriends == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 15, color: AppColors.label3, fontWeight: FontWeight.w500),
              ),
            ]),
          ),
        ),

        // ── Body ──────────────────────────────────────────
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.label))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.label,
                  backgroundColor: AppColors.card,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    children: [
                      if (_incoming.isNotEmpty) ...[
                        _sectionLabel('Requests', badge: _incoming.length),
                        const SizedBox(height: 10),
                        _card(children: _incoming.mapIndexed((i, f) => _requestTile(f, i, _incoming.length)).toList()),
                        const SizedBox(height: 18),
                      ],

                      _sectionLabel('Friends'),
                      const SizedBox(height: 10),
                      if (_accepted.isEmpty)
                        _emptyCard('No friends yet — tap + to add one')
                      else
                        _card(children: _accepted.mapIndexed((i, f) => _friendTile(f, i, _accepted.length)).toList()),
                      const SizedBox(height: 18),

                      _sectionLabel('Challenges'),
                      const SizedBox(height: 10),
                      if (_challenges.isEmpty)
                        _emptyCard('No active challenges')
                      else
                        _card(children: _challenges.mapIndexed((i, c) => _challengeTile(c, i, _challenges.length)).toList()),
                      const SizedBox(height: 18),

                      if (_sent.isNotEmpty) ...[
                        _sectionLabel('Sent'),
                        const SizedBox(height: 10),
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
      style: TextStyle(
        fontSize: 12, color: AppColors.label3,
        fontWeight: FontWeight.w800, letterSpacing: 1.5,
      )),
    if (badge != null && badge > 0) ...[
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: AppColors.label, borderRadius: BorderRadius.circular(10)),
        child: Text('$badge',
          style: TextStyle(fontSize: 11, color: AppColors.bg, fontWeight: FontWeight.w700)),
      ),
    ],
  ]);

  Widget _card({required List<Widget> children}) => Container(
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.separator, width: 0.5),
      boxShadow: cardShadow,
    ),
    clipBehavior: Clip.hardEdge,
    child: Column(children: children),
  );

  Widget _emptyCard(String text) => Container(
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.separator, width: 0.5),
      boxShadow: cardShadow,
    ),
    padding: const EdgeInsets.all(22),
    child: Center(
      child: Text(text, style: TextStyle(fontSize: 15, color: AppColors.label3)),
    ),
  );

  Widget _requestTile(Map<String, dynamic> f, int i, int total) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        _avatar(_email(f)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_email(f), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.label)),
          const SizedBox(height: 2),
          Text('wants to connect', style: TextStyle(fontSize: 13, color: AppColors.label3)),
        ])),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () async { await SupabaseService.declineFriendRequest(f['id']); _load(); },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Decline', style: TextStyle(fontSize: 13, color: AppColors.label2, fontWeight: FontWeight.w500)),
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
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.label,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Accept', style: TextStyle(fontSize: 13, color: AppColors.bg, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    ),
    if (i < total - 1) Container(height: 0.5, color: AppColors.separator,
        margin: const EdgeInsets.only(left: 68, right: 16)),
  ]);

  Widget _friendTile(Map<String, dynamic> f, int i, int total) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        _avatar(_email(f)),
        const SizedBox(width: 12),
        Expanded(child: Text(_email(f), maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.label))),
        GestureDetector(
          onTap: () => _challengeDialog(f),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Challenge',
              style: TextStyle(fontSize: 13, color: AppColors.label, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context,
            backgroundColor: AppColors.card,
            builder: (ctx) => SafeArea(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.person_remove_outlined, color: AppColors.label),
                  title: Text('Remove friend', style: TextStyle(color: AppColors.label)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await SupabaseService.declineFriendRequest(f['id']);
                    _load();
                  },
                ),
              ],
            )),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(Icons.more_horiz, size: 22, color: AppColors.label3),
          ),
        ),
      ]),
    ),
    if (i < total - 1) Container(height: 0.5, color: AppColors.separator,
        margin: const EdgeInsets.only(left: 68, right: 16)),
  ]);

  Widget _challengeTile(Map<String, dynamic> c, int i, int total) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.bg2,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.emoji_events_outlined, size: 22, color: AppColors.label),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.label)),
          const SizedBox(height: 2),
          Text(
            'with ${_partnerEmail(c)} · ${DateTime.now().difference(DateTime.parse(c['created_at'])).inDays}d',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: AppColors.label3),
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
                    child: Text('Abandon', style: TextStyle(color: AppColors.label, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );
            if (ok == true) { await SupabaseService.abandonChallenge(c['id']); _load(); }
          },
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(Icons.flag_outlined, size: 20, color: AppColors.label3),
          ),
        ),
      ]),
    ),
    if (i < total - 1) Container(height: 0.5, color: AppColors.separator,
        margin: const EdgeInsets.only(left: 68, right: 16)),
  ]);

  Widget _sentTile(Map<String, dynamic> f, int i, int total) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        _avatar(_email(f)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_email(f), maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.label)),
          const SizedBox(height: 2),
          Text('Awaiting reply', style: TextStyle(fontSize: 13, color: AppColors.label3)),
        ])),
        GestureDetector(
          onTap: () async { await SupabaseService.declineFriendRequest(f['id']); _load(); },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Cancel', style: TextStyle(fontSize: 13, color: AppColors.label2)),
          ),
        ),
      ]),
    ),
    if (i < total - 1) Container(height: 0.5, color: AppColors.separator,
        margin: const EdgeInsets.only(left: 68, right: 16)),
  ]);

  Widget _avatar(String email) => CircleAvatar(
    radius: 22,
    backgroundColor: AppColors.label,
    child: Text(
      email.isNotEmpty ? email[0].toUpperCase() : '?',
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.bg),
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
