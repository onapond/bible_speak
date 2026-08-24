import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

import 'config/app_config.dart';
import 'firebase_options_dev.dart' as development;
import 'firebase_options_prod.dart' as production;

/// Firebase options selected by the explicit APP_ENV build definition.
///
/// Local builds default to the isolated development project. A production
/// build must pass `--dart-define=APP_ENV=production` through the guarded
/// release scripts.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => AppConfig.isProduction
      ? production.DefaultFirebaseOptions.currentPlatform
      : development.DefaultFirebaseOptions.currentPlatform;
}
