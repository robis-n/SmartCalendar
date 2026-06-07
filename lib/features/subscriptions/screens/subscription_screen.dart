import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/supabase_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String _currentTier = AppConstants.tierFree;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTier();
  }

  Future<void> _loadTier() async {
    final profile = await SupabaseService.getUserProfile();
    setState(() {
      _currentTier = profile?['subscription_tier'] ?? AppConstants.tierFree;
      _loading = false;
    });
  }

  Widget _planCard({
    required String tier,
    required String price,
    required String period,
    required List<String> features,
    required Color color,
    required bool recommended,
  }) {
    final isCurrent = _currentTier == tier;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCurrent ? color : Colors.grey.shade300, width: isCurrent ? 2 : 1),
        color: isCurrent ? color.withOpacity(0.05) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(tier.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
              if (recommended) ...[
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)), child: const Text('BEST', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
              ],
              const Spacer(),
              if (isCurrent) Icon(Icons.check_circle, color: color),
            ]),
            const SizedBox(height: 4),
            Text(price, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            Text(period, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ...features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Icon(Icons.check, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text(f, style: const TextStyle(fontSize: 13))),
              ]),
            )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: isCurrent
                ? OutlinedButton(onPressed: null, child: const Text('Current Plan'))
                : FilledButton(
                    onPressed: () => _subscribe(tier),
                    style: FilledButton.styleFrom(backgroundColor: color),
                    child: Text('Upgrade to ${tier.toUpperCase()}'),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _subscribe(String tier) async {
    // In production: launch Stripe checkout URL
    // For now: show Stripe integration info
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Stripe Integration'),
        content: Text('To activate $tier plan, connect your Stripe account and replace price IDs in AppConstants.\n\nStripe Publishable Key: configured in .env'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final isAdmin = _currentTier == AppConstants.tierAdmin;

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAdmin) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF3F3D9F)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(children: [
                  Icon(Icons.star, color: Colors.amber),
                  SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CEO Admin Access', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('All features unlocked', style: TextStyle(color: Colors.white70)),
                    ],
                  )),
                ]),
              ),
              const SizedBox(height: 24),
            ],
            Text('Choose your plan', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _planCard(
              tier: 'free', price: '\$0', period: 'forever',
              features: ['10 tasks/month', '1 calendar integration', 'Basic scheduling', 'Limited AI suggestions'],
              color: Colors.grey, recommended: false,
            ),
            _planCard(
              tier: 'pro', price: '\$5', period: 'per month',
              features: ['Unlimited tasks', 'All calendar integrations', 'AI smart scheduling', 'Photo verification', 'Full analytics'],
              color: const Color(0xFF6C63FF), recommended: true,
            ),
            _planCard(
              tier: 'premium', price: '\$10', period: 'per month',
              features: ['Everything in Pro', 'Friends & challenges', 'Priority AI processing', 'Advanced analytics', 'Early access to features'],
              color: Colors.orange, recommended: false,
            ),
          ],
        ),
      ),
    );
  }
}
