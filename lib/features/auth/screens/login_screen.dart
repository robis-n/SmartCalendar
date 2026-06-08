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
  final _email = TextEditingController();
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
      if (_email.text.trim() == AppConstants.ceoEmail && _password.text.trim() == AppConstants.ceoPassword) {
        await _ceoLogin();
        return;
      }
      await Supabase.instance.client.auth.signInWithPassword(email: _email.text.trim(), password: _password.text.trim());
      if (mounted) context.go('/dashboard');
    } catch (e) {
      _err(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ceoLogin() async {
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: AppConstants.ceoEmail, password: AppConstants.ceoPassword);
    } catch (_) {
      await Supabase.instance.client.auth.signUp(email: AppConstants.ceoEmail, password: AppConstants.ceoPassword);
      await Future.delayed(const Duration(milliseconds: 800));
      await Supabase.instance.client.auth.signInWithPassword(email: AppConstants.ceoEmail, password: AppConstants.ceoPassword);
    }
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      await SupabaseService.upsertUserProfile({'id': uid, 'email': AppConstants.ceoEmail, 'subscription_tier': AppConstants.tierAdmin});
    }
    if (mounted) context.go('/dashboard');
  }

  Future<void> _signUp() async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signUp(email: _email.text.trim(), password: _password.text.trim());
      _info('Check your email to confirm your account.');
    } catch (e) {
      _err(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: AppColors.destructive));
  void _info(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg2,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              // Logo + title
              const Icon(Icons.calendar_month_rounded, size: 48, color: AppColors.accent),
              const SizedBox(height: 12),
              const Text('SmartCalendar', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
              const SizedBox(height: 6),
              const Text('Stay accountable. Get things done.', style: TextStyle(fontSize: 17, color: AppColors.label3)),
              const Spacer(),
              // Fields
              TextField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.label3),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _signIn,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Sign In'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _loading ? null : _signUp,
                child: const Text('Create Account'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
