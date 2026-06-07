import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg2,
      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: AppColors.bg,
        actions: [
          IconButton(icon: const Icon(Icons.person_add_outlined, color: AppColors.accent), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Invite section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Accountability Partners', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text('Invite friends to keep each other accountable on shared goals.', style: TextStyle(fontSize: 14, color: AppColors.label3)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {},
                  child: const Text('Invite a Friend'),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          const Text('Active Challenges', style: TextStyle(fontSize: 13, color: AppColors.label3, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
            child: const Column(children: [
              Icon(Icons.people_outline, size: 40, color: AppColors.label3),
              SizedBox(height: 8),
              Text('No active challenges', style: TextStyle(color: AppColors.label3, fontSize: 15)),
              SizedBox(height: 4),
              Text('Invite friends to start one', style: TextStyle(color: AppColors.label3, fontSize: 13)),
            ]),
          ),
        ],
      ),
    );
  }
}
