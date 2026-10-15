/// Build-time, environment specific configuration.
///
/// Every value is injected with `--dart-define` so that nothing environment
/// specific (including the Reown project id) is committed to source control.
///
/// ```sh
/// flutter run \
///   --dart-define=APP_ENV=development \
///   --dart-define=PROJECT_ID_DEV=xxxx \
///   --dart-define=PROJECT_ID_PROD=yyyy
/// ```
enum AppEnvironment { development, production }

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.projectId,
    required this.appName,
    required this.appDescription,
    required this.websiteUrl,
    required this.iconUrl,
    required this.nativeRedirectUrl,
    required this.universalRedirectUrl,
    required this.linkModeEnabled,
    required this.enableAnalytics,
  });

  final AppEnvironment environment;

  /// Public Reown project id. Not a secret, but still supplied at build time.
  final String projectId;

  final String appName;
  final String appDescription;
  final String websiteUrl;
  final String iconUrl;

  /// Deep link the wallet uses to return to this application
  /// (must match the native `CFBundleURLSchemes` / `intent-filter` scheme).
  final String nativeRedirectUrl;

  /// Universal link used for Link Mode. Only used when [linkModeEnabled].
  final String universalRedirectUrl;

  final bool linkModeEnabled;

  final bool enableAnalytics;

  bool get isProduction => environment == AppEnvironment.production;

  /// A connection can only be started when a project id is available.
  bool get isConfigured => projectId.isNotEmpty;

  static AppConfig fromEnvironment() {
    const rawEnvironment = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );
    const genericProjectId = String.fromEnvironment('PROJECT_ID');
    const developmentProjectId = String.fromEnvironment('PROJECT_ID_DEV');
    const productionProjectId = String.fromEnvironment('PROJECT_ID_PROD');

    final isProduction = rawEnvironment.toLowerCase() == 'production';
    final environment = isProduction
        ? AppEnvironment.production
        : AppEnvironment.development;

    final resolvedProjectId = switch ((isProduction, productionProjectId, developmentProjectId)) {
      (true, final prod, _) when prod.isNotEmpty => prod,
      (false, _, final dev) when dev.isNotEmpty => dev,
      _ => genericProjectId,
    };

    const configuredUrl = String.fromEnvironment('APP_URL');
    const configuredIconUrl = String.fromEnvironment('APP_ICON_URL');
    final fallbackUrl = isProduction
        ? 'https://metaownconnect.app'
        : 'https://dev.metaownconnect.app';
    final websiteUrl = configuredUrl.isNotEmpty ? configuredUrl : fallbackUrl;

    const scheme = String.fromEnvironment(
      'REDIRECT_SCHEME',
      defaultValue: 'metaownconnect',
    );

    return AppConfig(
      environment: environment,
      projectId: resolvedProjectId,
      appName: const String.fromEnvironment(
        'APP_NAME',
        defaultValue: 'MetaOwn Connect',
      ),
      appDescription: const String.fromEnvironment(
        'APP_DESCRIPTION',
        defaultValue: 'Connect your wallet to MetaOwn Connect.',
      ),
      websiteUrl: websiteUrl,
      iconUrl: configuredIconUrl.isNotEmpty
          ? configuredIconUrl
          : '$websiteUrl/logo.png',
      nativeRedirectUrl: '$scheme://',
      universalRedirectUrl: '$websiteUrl/wallet',
      linkModeEnabled: const bool.fromEnvironment('LINK_MODE'),
      enableAnalytics: const bool.fromEnvironment('ENABLE_ANALYTICS'),
    );
  }
}
