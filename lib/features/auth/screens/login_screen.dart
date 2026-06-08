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
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      if (_email.text.trim() == AppConstants.ceoEmail &&
          _password.text.trim() == AppConstants.ceoPassword) {
        await _ceoLogin();
        return;
      }
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
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
        'id': uid,
        'email': AppConstants.ceoEmail,
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
      _snack('Check your email to confirm your account.');
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),

              // Title
              const Text(
                'SmartCalendar',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.5),
              ),
              const SizedBox(height: 6),
              const Text(
                'Stay accountable.',
                style: TextStyle(fontSize: 16, color: AppColors.label3),
              ),

              const Spacer(),

              // Email
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),

              // Password
              TextField(
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _signIn(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.label3,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Sign in
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _signIn,
                  child: _loading
                      ? const SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Sign In'),
                ),
              ),
              const SizedBox(height: 10),

              // Create account
              Center(
                child: TextButton(
                  onPressed: _loading ? null : _signUp,
                  child: const Text('Create Account'),
                ),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
