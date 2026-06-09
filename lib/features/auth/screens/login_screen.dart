import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email    = TextEditingController();
  final _password = TextEditingController();
  bool _loading  = false;
  bool _obscure  = true;
  bool _isSignUp = false;

  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }

  void _submit() => _isSignUp ? _signUp() : _signIn();

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      if (_email.text.trim() == AppConstants.ceoEmail &&
          _password.text.trim() == AppConstants.ceoPassword) {
        await _ceoLogin(); return;
      }
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(), password: _password.text.trim());
      if (mounted) context.go('/dashboard');
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ceoLogin() async {
    try {
      await Supabase.instance.client.auth
          .signInWithPassword(email: AppConstants.ceoEmail, password: AppConstants.ceoPassword);
    } catch (_) {
      await Supabase.instance.client.auth
          .signUp(email: AppConstants.ceoEmail, password: AppConstants.ceoPassword);
      await Future.delayed(const Duration(milliseconds: 800));
      await Supabase.instance.client.auth
          .signInWithPassword(email: AppConstants.ceoEmail, password: AppConstants.ceoPassword);
    }
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      await SupabaseService.upsertUserProfile({
        'id': uid, 'email': AppConstants.ceoEmail,
        'subscription_tier': AppConstants.tierAdmin,
      });
    }
    if (mounted) context.go('/dashboard');
  }

  Future<void> _signUp() async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth
          .signUp(email: _email.text.trim(), password: _password.text.trim());
      _snack('Check your email to confirm your account ✉️');
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: _Entrance(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Brand
                Container(width: 12, height: 12,
                  decoration: BoxDecoration(color: AppColors.label, shape: BoxShape.circle)),
                const SizedBox(height: 16),
                Text('SMARTCALENDAR',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800,
                    color: AppColors.label3, letterSpacing: 3,
                  )),
                const SizedBox(height: 36),

                // Animated title
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(a),
                      child: c,
                    ),
                  ),
                  child: Text(
                    _isSignUp ? 'Create\naccount.' : 'Welcome\nback.',
                    key: ValueKey(_isSignUp),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 44, fontWeight: FontWeight.w800,
                      color: AppColors.label, height: 1.02, letterSpacing: -2,
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // Fields
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textAlign: TextAlign.center,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(fontSize: 16, color: AppColors.label),
                  decoration: const InputDecoration(hintText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: _obscure,
                  textAlign: TextAlign.center,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  style: TextStyle(fontSize: 16, color: AppColors.label),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.label3, size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // Submit
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _loading
                          ? SizedBox(
                              key: const ValueKey('load'),
                              width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.bg),
                            )
                          : Text(_isSignUp ? 'Create account' : 'Sign in',
                              key: ValueKey(_isSignUp)),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Mode toggle
                GestureDetector(
                  onTap: _loading ? null : () => setState(() => _isSignUp = !_isSignUp),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: RichText(
                      key: ValueKey(_isSignUp),
                      text: TextSpan(children: [
                        TextSpan(
                          text: _isSignUp ? 'Have an account?  ' : 'New here?  ',
                          style: TextStyle(color: AppColors.label3, fontSize: 15),
                        ),
                        TextSpan(
                          text: _isSignUp ? 'Sign in' : 'Create one',
                          style: TextStyle(color: AppColors.label, fontSize: 15,
                              fontWeight: FontWeight.w700),
                        ),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gentle fade + rise on first appear — silky entrance.
class _Entrance extends StatefulWidget {
  final Widget child;
  const _Entrance({required this.child});
  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650))..forward();
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
      begin: const Offset(0, 0.06), end: Offset.zero)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _fade, child: SlideTransition(position: _slide, child: widget.child));
}
