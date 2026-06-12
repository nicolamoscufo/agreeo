/// Outbound links used by the Settings "About & Support" section.
///
/// IMPORTANT: replace these placeholder URLs with the real hosted pages before
/// publishing. Both the App Store and Google Play **require** a reachable
/// Privacy Policy URL, and a support contact must be published for apps with
/// user-generated content (App Store Guideline 1.2).
class AppLinks {
  const AppLinks._();

  static const String privacyPolicy = 'https://agreeo.app/privacy';
  static const String termsOfService = 'https://agreeo.app/terms';

  /// Address used by "Contact support" (opens the mail client).
  static const String supportEmail = 'support@agreeo.app';

  /// Store listing opened by "Rate Agreeo". Swap for the real App Store /
  /// Play Store URL once the app is published.
  static const String storeListing = 'https://agreeo.app';
}
