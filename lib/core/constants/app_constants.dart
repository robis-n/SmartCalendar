class AppConstants {
  // CEO Admin credentials — full access to all features
  static const String ceoEmail = 'ceo@smartcalendar.app';
  static const String ceoPassword = 'Sm@rtC4l#R0bis2026!';
  static const String ceoUsername = 'robis_ceo';

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
