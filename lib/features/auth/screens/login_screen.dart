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
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }

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
        child: Column(children: [
          // ── Hero section ────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.label,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'SMARTCALENDAR',
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800,
                        color: AppColors.label, letterSpacing: 2.5,
                      ),
                    ),
                  ]),

                  const Spacer(),

                  Text(
                    'Build\nhabits.',
                    style: TextStyle(
                      fontSize: 60, fontWeight: FontWeight.w800,
                      color: AppColors.label, height: 1.0,
                      letterSpacing: -3,
                    ),
                  ),
                  Text(
                    'Prove it.',
                    style: TextStyle(
                      fontSize: 60, fontWeight: FontWeight.w800,
                      color: AppColors.label3, height: 1.0,
                      letterSpacing: -3,
                    ),
                  ),

                  const SizedBox(height: 36),

                  _bullet('01', 'Photo-verified accountability'),
                  const SizedBox(height: 12),
                  _bullet('02', 'AI-powered scheduling'),
                  const SizedBox(height: 12),
                  _bullet('03', 'Social challenges with friends'),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // ── Form card ───────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(top: BorderSide(color: AppColors.separator, width: 1)),
            ),
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 40, height: 5,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: AppColors.separator,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                style: TextStyle(fontSize: 16, color: AppColors.label),
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline_rounded,
                      color: AppColors.label3, size: 20),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _signIn(),
                style: TextStyle(fontSize: 16, color: AppColors.label),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline_rounded,
                      color: AppColors.label3, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.label3, size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              FilledButton(
                onPressed: _loading ? null : _signIn,
                child: _loading
                    ? SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg),
                      )
                    : const Text('Sign in'),
              ),
              const SizedBox(height: 8),

              TextButton(
                onPressed: _loading ? null : _signUp,
                child: RichText(
                  text: TextSpan(children: [
                    TextSpan(text: "Don't have an account?  ",
                        style: TextStyle(color: AppColors.label3, fontSize: 15)),
                    TextSpan(text: 'Sign up',
                        style: TextStyle(color: AppColors.label, fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _bullet(String num, String text) => Row(children: [
    Text(num,
      style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w800,
        color: AppColors.label, letterSpacing: 0.5,
      )),
    const SizedBox(width: 12),
    Container(width: 1, height: 14, color: AppColors.separator),
    const SizedBox(width: 12),
    Text(text,
      style: TextStyle(
        fontSize: 15, color: AppColors.label2,
        fontWeight: FontWeight.w400,
      )),
  ]);
}
