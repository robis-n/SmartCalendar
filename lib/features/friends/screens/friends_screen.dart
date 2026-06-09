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
  List<Map<String, dynamic>> _suggestions = [];
  bool _loading = true;

  String get _myId => Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final fs   = await SupabaseService.getFriendships();
    final cs   = await SupabaseService.getChallenges();
    final sug  = await SupabaseService.getFriendSuggestions(limit: 6);
    if (mounted) {
      setState(() {
        _friendships = fs; _challenges = cs; _suggestions = sug; _loading = false;
      });
    }
  }

  // ── Selectors ──────────────────────────────────────────

  List<Map<String, dynamic>> get _accepted =>
      _friendships.where((f) => f['status'] == 'accepted').toList();
  List<Map<String, dynamic>> get _incoming =>
      _friendships.where((f) => f['status'] == 'pending' && f['addressee_id'] == _myId).toList();
  List<Map<String, dynamic>> get _sent =>
      _friendships.where((f) => f['status'] == 'pending' && f['requester_id'] == _myId).toList();

  // Returns the other user record (with id, username, email) for a friendship.
  Map<String, dynamic> _other(Map<String, dynamic> f) {
    final r = f['requester_id'] == _myId ? f['addressee'] : f['requester'];
    return Map<String, dynamic>.from((r as Map?) ?? {});
  }

  String _handle(Map<String, dynamic> u) {
    final un = u['username'] as String?;
    if (un != null && un.isNotEmpty) return '@$un';
    final em = u['email'] as String?;
    return em ?? '?';
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // ── Dialogs ────────────────────────────────────────────

  void _addFriendDialog({String? prefill}) {
    final ctrl = TextEditingController(text: prefill);
    bool loading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        title: const Text('Add friend'),
        content: TextField(
          controller: ctrl, autocorrect: false, autofocus: true,
          decoration: const InputDecoration(labelText: 'Username or email'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(80, 44)),
            onPressed: loading ? null : () async {
              final q = ctrl.text.trim();
              if (q.isEmpty) return;
              ss(() => loading = true);
              try {
                final user = await SupabaseService.searchUserByHandle(q);
                if (!ctx.mounted) return;
                if (user == null) {
                  Navigator.pop(ctx);
                  _snack('No one matches "$q"');
                  return;
                }
                await SupabaseService.sendFriendRequest(user['id']);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _snack('Request sent');
                _load();
              } catch (e) {
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _snack(e.toString().contains('unique')
                    ? 'Already friends or request pending'
                    : 'Error: $e');
              }
            },
            child: loading
                ? SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                : const Text('Send'),
          ),
        ],
      )),
    );
  }

  void _challengeDialog(Map<String, dynamic> f) {
    final other = _other(f);
    final ctrl  = TextEditingController();
    bool loading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        title: Text('Challenge ${_handle(other)}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: ctrl, autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Goal', hintText: 'e.g. Run every day',
            ),
          ),
          const SizedBox(height: 10),
          Text('Both of you must mark it done. Either can nudge.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.label3, fontSize: 13)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(80, 44)),
            onPressed: loading ? null : () async {
              if (ctrl.text.trim().isEmpty) return;
              ss(() => loading = true);
              await SupabaseService.createChallenge(
                  partnerId: other['id'], title: ctrl.text.trim());
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _snack('Challenge started');
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
    final total = _accepted.length;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 20, 14),
            child: Row(children: [
              _IconBtn(icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 14),
              Text('Friends',
                style: TextStyle(
                  fontSize: 30, fontWeight: FontWeight.w800,
                  color: AppColors.label, letterSpacing: -1.2,
                )),
              const Spacer(),
              _IconBtn(icon: Icons.person_add_alt_1_rounded,
                  filled: true, onTap: () => _addFriendDialog()),
            ]),
          ),
        ),

        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.label))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.label, backgroundColor: AppColors.card,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    children: [
                      // Friend count, subtle
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 14),
                        child: Text(
                          total == 0 ? 'No friends yet' : '$total friend${total == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 15, color: AppColors.label3,
                              fontWeight: FontWeight.w500),
                        ),
                      ),

                      if (_incoming.isNotEmpty) ...[
                        _sectionLabel('Requests', badge: _incoming.length),
                        const SizedBox(height: 10),
                        _card(children: _incoming
                            .mapIndexed((i, f) => _requestTile(f, i, _incoming.length))
                            .toList()),
                        const SizedBox(height: 22),
                      ],

                      _sectionLabel('Friends'),
                      const SizedBox(height: 10),
                      if (_accepted.isEmpty)
                        _emptyCard('No friends yet — add someone you know')
                      else
                        _card(children: _accepted
                            .mapIndexed((i, f) => _friendTile(f, i, _accepted.length))
                            .toList()),
                      const SizedBox(height: 22),

                      _sectionLabel('Challenges'),
                      const SizedBox(height: 10),
                      if (_challenges.isEmpty)
                        _emptyCard('No active challenges')
                      else
                        Column(children: _challenges
                            .map((c) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _challengeTile(c)))
                            .toList()),
                      const SizedBox(height: 22),

                      if (_suggestions.isNotEmpty) ...[
                        _sectionLabel('You might know'),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8,
                          children: _suggestions.map(_suggestionChip).toList()),
                        const SizedBox(height: 22),
                      ],

                      if (_sent.isNotEmpty) ...[
                        _sectionLabel('Sent'),
                        const SizedBox(height: 10),
                        _card(children: _sent
                            .mapIndexed((i, f) => _sentTile(f, i, _sent.length))
                            .toList()),
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
      style: TextStyle(fontSize: 12, color: AppColors.label3,
          fontWeight: FontWeight.w800, letterSpacing: 1.5)),
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
    child: Center(child: Text(text, style: TextStyle(fontSize: 15, color: AppColors.label3))),
  );

  // ── Tiles ─────────────────────────────────────────────

  Widget _requestTile(Map<String, dynamic> f, int i, int total) {
    final u = _other(f);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          _avatar(u),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_handle(u), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.label)),
              const SizedBox(height: 2),
              Text('wants to connect', style: TextStyle(fontSize: 13, color: AppColors.label3)),
            ],
          )),
          const SizedBox(width: 8),
          _pillButton(label: 'Decline', filled: false,
              onTap: () async { await SupabaseService.declineFriendRequest(f['id']); _load(); }),
          const SizedBox(width: 6),
          _pillButton(label: 'Accept', filled: true,
              onTap: () async {
                await SupabaseService.acceptFriendRequest(f['id']);
                _snack('Connected');
                _load();
              }),
        ]),
      ),
      if (i < total - 1) _hairline(),
    ]);
  }

  Widget _friendTile(Map<String, dynamic> f, int i, int total) {
    final u = _other(f);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          _avatar(u),
          const SizedBox(width: 12),
          Expanded(child: Text(_handle(u), maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.label))),
          _pillButton(label: 'Challenge', filled: false,
              onTap: () => _challengeDialog(f)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              backgroundColor: AppColors.card,
              builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(
                  leading: Icon(Icons.person_remove_outlined, color: AppColors.label),
                  title: Text('Remove friend', style: TextStyle(color: AppColors.label)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await SupabaseService.declineFriendRequest(f['id']);
                    _load();
                  },
                ),
              ])),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.more_horiz, size: 22, color: AppColors.label3),
            ),
          ),
        ]),
      ),
      if (i < total - 1) _hairline(),
    ]);
  }

  Widget _challengeTile(Map<String, dynamic> c) {
    final isCreator = c['creator_id'] == _myId;
    final partner   = Map<String, dynamic>.from(
        (isCreator ? c['partner'] : c['creator']) as Map);
    final mineDone  = (isCreator ? c['creator_done'] : c['partner_done']) == true;
    final theirDone = (isCreator ? c['partner_done'] : c['creator_done']) == true;
    final allDone   = mineDone && theirDone;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.separator, width: 0.5),
        boxShadow: cardShadow,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(allDone ? Icons.emoji_events_rounded : Icons.flag_outlined,
              size: 22, color: AppColors.label),
          const SizedBox(width: 12),
          Expanded(child: Text(c['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                color: AppColors.label, letterSpacing: -0.3))),
        ]),
        const SizedBox(height: 14),

        // Per-side status — me + them. Tap mine to mark/un-mark.
        Row(children: [
          Expanded(child: _sideStatus(label: 'You', done: mineDone,
              onTap: mineDone ? null : () async {
                await SupabaseService.markChallengeSideDone(c);
                _load();
              })),
          const SizedBox(width: 10),
          Expanded(child: _sideStatus(label: _handle(partner), done: theirDone)),
        ]),

        if (allDone) ...[
          const SizedBox(height: 14),
          Center(child: Text('Both of you did it. Nice.',
              style: TextStyle(fontSize: 14, color: AppColors.label2,
                  fontWeight: FontWeight.w500))),
        ] else ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: _pillButton(label: 'Nudge', filled: false,
                  onTap: () async {
                    final err = await SupabaseService.nudgeChallengePartner(c);
                    _snack(err ?? 'Nudge sent');
                  }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _pillButton(label: 'Drop', filled: false,
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Abandon challenge?'),
                        content: Text(c['title'] ?? ''),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Keep going')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true),
                              child: Text('Abandon',
                                  style: TextStyle(color: AppColors.label,
                                      fontWeight: FontWeight.w700))),
                        ],
                      ),
                    );
                    if (ok == true) { await SupabaseService.abandonChallenge(c['id']); _load(); }
                  }),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _sideStatus({required String label, required bool done, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: done ? AppColors.label : AppColors.bg2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(mainAxisSize: MainAxisSize.max, children: [
          Icon(done ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
              size: 18, color: done ? AppColors.bg : AppColors.label3),
          const SizedBox(width: 8),
          Flexible(child: Text(label,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: done ? AppColors.bg : AppColors.label,
              ))),
        ]),
      ),
    );
  }

  Widget _sentTile(Map<String, dynamic> f, int i, int total) {
    final u = _other(f);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          _avatar(u),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_handle(u), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.label)),
              const SizedBox(height: 2),
              Text('Awaiting reply', style: TextStyle(fontSize: 13, color: AppColors.label3)),
            ],
          )),
          _pillButton(label: 'Cancel', filled: false,
              onTap: () async { await SupabaseService.declineFriendRequest(f['id']); _load(); }),
        ]),
      ),
      if (i < total - 1) _hairline(),
    ]);
  }

  Widget _suggestionChip(Map<String, dynamic> u) {
    final h = _handle(u);
    return GestureDetector(
      onTap: () async {
        try {
          await SupabaseService.sendFriendRequest(u['id']);
          _snack('Request sent to $h');
          _load();
        } catch (_) { _snack('Could not send request'); }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.separator, width: 0.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _avatar(u, size: 24),
          const SizedBox(width: 8),
          Text(h, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.label)),
          const SizedBox(width: 6),
          Icon(Icons.add_rounded, size: 16, color: AppColors.label3),
        ]),
      ),
    );
  }

  // ── Atoms ─────────────────────────────────────────────

  Widget _avatar(Map<String, dynamic> u, {double size = 44}) {
    final h = _handle(u);
    final c = h.replaceFirst('@', '');
    final letter = c.isNotEmpty ? c[0].toUpperCase() : '?';
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: AppColors.label,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(letter,
          style: TextStyle(fontSize: size * 0.38,
              fontWeight: FontWeight.w700, color: AppColors.bg)),
    );
  }

  Widget _pillButton({required String label, required bool filled, VoidCallback? onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: filled ? AppColors.label : AppColors.bg2,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(child: Text(label,
              style: TextStyle(fontSize: 13,
                  color: filled ? AppColors.bg : AppColors.label,
                  fontWeight: FontWeight.w600))),
        ),
      );

  Widget _hairline() => Container(height: 0.5, color: AppColors.separator,
      margin: const EdgeInsets.only(left: 68, right: 16));
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, this.filled = false, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42, height: 42,
      decoration: BoxDecoration(
        color: filled ? AppColors.label : AppColors.bg2,
        shape: BoxShape.circle,
        border: filled ? null : Border.all(color: AppColors.separator, width: 0.8),
      ),
      child: Icon(icon, size: filled ? 19 : 16,
          color: filled ? AppColors.bg : AppColors.label),
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
