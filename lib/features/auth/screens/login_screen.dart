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
      body: Stack(children: [
        // ── Decorative background elements ───────────────────
        Positioned(top: -80, right: -80, child: _orb(280, const Color(0xFFD4AF7A), 0.04)),
        Positioned(top: 160, left: -100, child: _orb(240, const Color(0xFF7C5CFC), 0.05)),
        Positioned(bottom: 180, right: -60, child: _orb(200, const Color(0xFFD4AF7A), 0.03)),

        SafeArea(
          child: Column(children: [
            // ── Hero section ────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top label
                    Row(children: [
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'SMARTCALENDAR',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: AppColors.accent, letterSpacing: 2.0,
                        ),
                      ),
                    ]),

                    const Spacer(),

                    // Editorial headline
                    const Text(
                      'Build\nhabits.',
                      style: TextStyle(
                        fontSize: 52, fontWeight: FontWeight.w900,
                        color: AppColors.label, height: 1.0,
                        letterSpacing: -2.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Prove it.',
                      style: TextStyle(
                        fontSize: 52, fontWeight: FontWeight.w900,
                        color: AppColors.accent, height: 1.0,
                        letterSpacing: -2.5,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Feature bullets — editorial style
                    _bullet('01', 'Photo-verified accountability'),
                    const SizedBox(height: 10),
                    _bullet('02', 'AI-powered scheduling'),
                    const SizedBox(height: 10),
                    _bullet('03', 'Social challenges with friends'),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // ── Dark form card ───────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(top: BorderSide(color: AppColors.separator, width: 1)),
              ),
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Handle
                Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppColors.separator,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Email field
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontSize: 15, color: AppColors.label),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.mail_outline_rounded,
                        color: AppColors.label3, size: 20),
                    filled: true,
                    fillColor: AppColors.bg2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.separator),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.separator),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Password field
                TextField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _signIn(),
                  style: const TextStyle(fontSize: 15, color: AppColors.label),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        color: AppColors.label3, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.label3, size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    filled: true,
                    fillColor: AppColors.bg2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.separator),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.separator),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Sign In button — gold glow
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE8C890), Color(0xFFB08040)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4AF7A).withValues(alpha: 0.40),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: FilledButton(
                      onPressed: _loading ? null : _signIn,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _loading
                          ? SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2,
                                  color: AppColors.bg),
                            )
                          : const Text('Sign In',
                              style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700,
                                color: AppColors.bg, letterSpacing: 0.5,
                              )),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Create account
                TextButton(
                  onPressed: _loading ? null : _signUp,
                  child: RichText(
                    text: TextSpan(children: [
                      TextSpan(text: "Don't have an account? ",
                          style: TextStyle(color: AppColors.label3, fontSize: 14)),
                      const TextSpan(text: 'Sign Up',
                          style: TextStyle(color: AppColors.accent, fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _bullet(String num, String text) => Row(children: [
    Text(num,
      style: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700,
        color: AppColors.accent, letterSpacing: 0.5,
      )),
    const SizedBox(width: 12),
    Container(width: 1, height: 14, color: AppColors.separator),
    const SizedBox(width: 12),
    Text(text,
      style: const TextStyle(
        fontSize: 14, color: AppColors.label2,
        fontWeight: FontWeight.w400,
      )),
  ]);

  Widget _orb(double size, Color color, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: opacity),
    ),
  );
}
