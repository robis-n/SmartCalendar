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
  List<Map<String, dynamic>> _challenges = [];
  bool _loading = true;
  String get _myId => Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final fs = await SupabaseService.getFriendships();
    final cs = await SupabaseService.getChallenges();
    setState(() {
      _friendships = fs;
      _challenges = cs;
      _loading = false;
    });
  }

  // ── Helpers ────────────────────────────────────────────

  List<Map<String, dynamic>> get _accepted =>
      _friendships.where((f) => f['status'] == 'accepted').toList();

  List<Map<String, dynamic>> get _incoming => _friendships
      .where((f) => f['status'] == 'pending' && f['addressee_id'] == _myId)
      .toList();

  List<Map<String, dynamic>> get _sent => _friendships
      .where((f) => f['status'] == 'pending' && f['requester_id'] == _myId)
      .toList();

  String _friendEmail(Map<String, dynamic> f) {
    if (f['requester_id'] == _myId) {
      return (f['addressee'] as Map?)?['email'] ?? '?';
    }
    return (f['requester'] as Map?)?['email'] ?? '?';
  }

  String _friendId(Map<String, dynamic> f) {
    if (f['requester_id'] == _myId) {
      return (f['addressee'] as Map?)?['id'] ?? '';
    }
    return (f['requester'] as Map?)?['id'] ?? '';
  }

  String _challengePartnerEmail(Map<String, dynamic> c) {
    if (c['creator_id'] == _myId) {
      return (c['partner'] as Map?)?['email'] ?? '?';
    }
    return (c['creator'] as Map?)?['email'] ?? '?';
  }

  // ── Dialogs ────────────────────────────────────────────

  void _showAddFriendDialog() {
    final ctrl = TextEditingController();
    bool loading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: const Text('Add Friend'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
              'Enter your friend\'s email address to send a request.',
              style: TextStyle(fontSize: 14, color: AppColors.label3),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      final email = ctrl.text.trim();
                      if (email.isEmpty) return;
                      setS(() => loading = true);
                      try {
                        final user = await SupabaseService.searchUserByEmail(email);
                        if (user == null) {
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            _snack('No user found with that email.', error: true);
                          }
                          return;
                        }
                        await SupabaseService.sendFriendRequest(user['id']);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          _snack('Friend request sent to $email!');
                        }
                        _load();
                      } catch (e) {
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          _snack(
                            e.toString().contains('unique')
                                ? 'Already friends or request pending.'
                                : 'Error: $e',
                            error: true,
                          );
                        }
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send Request'),
            ),
          ],
        );
      }),
    );
  }

  void _showChallengeDialog(Map<String, dynamic> friend) {
    final ctrl = TextEditingController();
    bool loading = false;
    final partnerEmail = _friendEmail(friend);
    final partnerId = _friendId(friend);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: const Text('Start Challenge'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'Challenge with $partnerEmail',
              style: const TextStyle(fontSize: 14, color: AppColors.label3),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Challenge goal',
                hintText: 'e.g. Exercise every day for 30 days',
                prefixIcon: Icon(Icons.emoji_events_outlined),
              ),
              maxLines: 2,
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      final title = ctrl.text.trim();
                      if (title.isEmpty) return;
                      setS(() => loading = true);
                      try {
                        await SupabaseService.createChallenge(
                          partnerId: partnerId,
                          title: title,
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          _snack('Challenge started!');
                        }
                        _load();
                      } catch (e) {
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          _snack('Error: $e', error: true);
                        }
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Start'),
            ),
          ],
        );
      }),
    );
  }

  void _confirmRemove(Map<String, dynamic> f) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text('Remove ${_friendEmail(f)} from your friends?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SupabaseService.declineFriendRequest(f['id']);
              _load();
            },
            child: const Text('Remove', style: TextStyle(color: AppColors.destructive)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.destructive : AppColors.success,
    ));
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg2,
      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: AppColors.bg,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined, color: AppColors.accent),
            onPressed: _showAddFriendDialog,
            tooltip: 'Add Friend',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Incoming requests ───────────────────
                  if (_incoming.isNotEmpty) ...[
                    _sectionHeader('Friend Requests', badge: _incoming.length),
                    const SizedBox(height: 8),
                    _card(children: [
                      for (int i = 0; i < _incoming.length; i++) ...[
                        if (i > 0) const Divider(height: 0, indent: 52),
                        _requestTile(_incoming[i]),
                      ],
                    ]),
                    const SizedBox(height: 20),
                  ],

                  // ── Accepted friends ────────────────────
                  _sectionHeader('Friends', badge: _accepted.length),
                  const SizedBox(height: 8),
                  if (_accepted.isEmpty)
                    _emptyState(
                      icon: Icons.people_outline,
                      label: 'No friends yet',
                      sub: 'Tap + above to invite someone',
                    )
                  else
                    _card(children: [
                      for (int i = 0; i < _accepted.length; i++) ...[
                        if (i > 0) const Divider(height: 0, indent: 52),
                        _friendTile(_accepted[i]),
                      ],
                    ]),
                  const SizedBox(height: 20),

                  // ── Sent requests ───────────────────────
                  if (_sent.isNotEmpty) ...[
                    _sectionHeader('Pending Sent'),
                    const SizedBox(height: 8),
                    _card(children: [
                      for (int i = 0; i < _sent.length; i++) ...[
                        if (i > 0) const Divider(height: 0, indent: 52),
                        _sentTile(_sent[i]),
                      ],
                    ]),
                    const SizedBox(height: 20),
                  ],

                  // ── Active challenges ───────────────────
                  _sectionHeader('Active Challenges', badge: _challenges.length),
                  const SizedBox(height: 8),
                  if (_challenges.isEmpty)
                    _emptyState(
                      icon: Icons.emoji_events_outlined,
                      label: 'No active challenges',
                      sub: 'Challenge a friend from the list above',
                    )
                  else
                    _card(children: [
                      for (int i = 0; i < _challenges.length; i++) ...[
                        if (i > 0) const Divider(height: 0, indent: 52),
                        _challengeTile(_challenges[i]),
                      ],
                    ]),
                  const SizedBox(height: 32),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddFriendDialog,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 2,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  // ── Tile widgets ───────────────────────────────────────

  Widget _requestTile(Map<String, dynamic> f) {
    final email = _friendEmail(f);
    return ListTile(
      leading: _avatar(email),
      title: Text(email, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: const Text('Wants to be your friend', style: TextStyle(fontSize: 13, color: AppColors.label3)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          icon: const Icon(Icons.close, color: AppColors.destructive, size: 20),
          onPressed: () async {
            await SupabaseService.declineFriendRequest(f['id']);
            _load();
          },
          tooltip: 'Decline',
        ),
        IconButton(
          icon: const Icon(Icons.check, color: AppColors.success, size: 20),
          onPressed: () async {
            await SupabaseService.acceptFriendRequest(f['id']);
            _snack('You\'re now friends with $email!');
            _load();
          },
          tooltip: 'Accept',
        ),
      ]),
    );
  }

  Widget _friendTile(Map<String, dynamic> f) {
    final email = _friendEmail(f);
    return ListTile(
      leading: _avatar(email, online: true),
      title: Text(email, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: const Text('Friend', style: TextStyle(fontSize: 13, color: AppColors.label3)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        TextButton(
          onPressed: () => _showChallengeDialog(f),
          child: const Text('Challenge'),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, size: 20, color: AppColors.label3),
          onPressed: () => _confirmRemove(f),
        ),
      ]),
    );
  }

  Widget _sentTile(Map<String, dynamic> f) {
    final email = _friendEmail(f);
    return ListTile(
      leading: _avatar(email),
      title: Text(email, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: const Text('Request sent', style: TextStyle(fontSize: 13, color: AppColors.label3)),
      trailing: TextButton(
        onPressed: () async {
          await SupabaseService.declineFriendRequest(f['id']);
          _load();
        },
        child: const Text('Cancel', style: TextStyle(color: AppColors.destructive)),
      ),
    );
  }

  Widget _challengeTile(Map<String, dynamic> c) {
    final partnerEmail = _challengePartnerEmail(c);
    final days = DateTime.now().difference(DateTime.parse(c['created_at'])).inDays;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.emoji_events, color: AppColors.warning, size: 20),
      ),
      title: Text(c['title'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text('with $partnerEmail · $days days in', style: const TextStyle(fontSize: 13, color: AppColors.label3)),
      trailing: IconButton(
        icon: const Icon(Icons.flag_outlined, size: 20, color: AppColors.label3),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Abandon Challenge?'),
              content: Text('Give up on "${c['title']}"?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Going')),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Abandon', style: TextStyle(color: AppColors.destructive)),
                ),
              ],
            ),
          );
          if (ok == true) {
            await SupabaseService.abandonChallenge(c['id']);
            _load();
          }
        },
        tooltip: 'Abandon',
      ),
    );
  }

  // ── Shared UI ──────────────────────────────────────────

  Widget _avatar(String email, {bool online = false}) {
    final letter = email.isNotEmpty ? email[0].toUpperCase() : '?';
    return Stack(children: [
      CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.accent.withValues(alpha: 0.15),
        child: Text(letter, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.accent)),
      ),
      if (online)
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.bg, width: 1.5),
            ),
          ),
        ),
    ]);
  }

  Widget _sectionHeader(String title, {int? badge}) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 0),
        child: Row(children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.label3,
              letterSpacing: 0.5,
            ),
          ),
          if (badge != null && badge > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$badge',
                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ]),
      );

  Widget _card({required List<Widget> children}) => Container(
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: children),
      );

  Widget _emptyState({required IconData icon, required String label, required String sub}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 40, color: AppColors.separator),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AppColors.label3, fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(color: AppColors.label3, fontSize: 13)),
        ]),
      );
}
