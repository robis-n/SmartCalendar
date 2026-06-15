class AppConstants {
  // NOTE: there are deliberately NO admin credentials here. Admin access is
  // granted server-side only (a user's `subscription_tier = 'admin'` row,
  // protected by a DB trigger that blocks any client-side tier change). The
  // admin signs in with their normal email + password like everyone else.
  // Never hardcode credentials in the app — they ship inside the binary.

  // Subscription tiers
  static const String tierFree = 'free';
  static const String tierPro = 'pro';
  static const String tierPremium = 'premium';
  static const String tierAdmin = 'admin'; // CEO / internal

  // Claude model (vision verification runs server-side in the verify-photo
  // Edge Function; override there with the ANTHROPIC_MODEL secret)
  static const String claudeModel = 'claude-opus-4-8';

  // Stripe price IDs (replace with real ones from Stripe dashboard)
  static const String stripePriceMonthlyPro = 'price_pro_monthly';
  static const String stripePriceMonthlyPremium = 'price_premium_monthly';
}
