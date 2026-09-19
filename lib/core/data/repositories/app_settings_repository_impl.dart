import 'package:openreader/core/domain/models/theme_mode_enum.dart';
import 'package:openreader/core/domain/repositories/app_settings_repository.dart';
import 'package:openreader/core/presentation/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// None of these values are sensitive (theme choice, locale, an onboarding
/// flag), so this reads/writes plain SharedPreferences directly rather than
/// going through the Keystore-backed `SharedPreference` cache wrapper
/// (lib/core/data/cache/preference/shared_preference.dart, despite its name,
/// wraps FlutterSecureStorage). That wrapper's Android-Keystore cipher
/// migration was verified to hang the app's cold-start bootstrap indefinitely
/// on a real emulator (see FEATURE-OPENREADER-P5/tasks/TASK-013.md) — routing
/// non-sensitive settings around it removes that hang from the splash path.
///
/// ODF-P6-03: every method here catches and logs rather than lets a
/// `SharedPreferences` failure escape as an unhandled exception - most
/// importantly for [setOnboardingComplete], awaited with no guard on either
/// side by `OnboardingController.allowAccess()` on the app's single most
/// critical first-run path. Falls back to a safe default on read failures
/// and silently no-ops (after logging) on write failures rather than
/// crashing; a write failure here means a preference doesn't stick (e.g.
/// onboarding re-shows next launch), which is a recoverable UX papercut, not
/// a crash. Kept as plain `Future<T>` rather than migrating to the
/// `ResultFuture`/`Failure` pattern the other repositories use - that would
/// also require updating every caller (`OnboardingController`,
/// `ThemeController`, `LocaleController`, `SettingsController`) to handle
/// `Either`, a larger change than this fix's actual goal of not crashing.
class AppSettingsRepositoryImpl implements AppSettingsRepository {
  static const String _themeKey = 'app_settings:theme_mode';
  static const String _localeKey = 'app_settings:locale';
  static const String _onboardingCompleteKey = 'app_settings:onboarding_complete';

  @override
  Future<AppThemeMode> getThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_themeKey);
      if (value == null) {
        return AppThemeMode.system;
      }
      return AppThemeMode.fromString(value);
    } catch (e) {
      return AppThemeMode.system;
    }
  }

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, mode.toStringValue());
    } catch (e) {
      AppLogger.error('Failed to save theme mode', e);
    }
  }

  @override
  Future<String?> getLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_localeKey);
    } catch (e) {
      AppLogger.error('Failed to read locale', e);
      return null;
    }
  }

  @override
  Future<void> setLocale(String locale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, locale);
    } catch (e) {
      AppLogger.error('Failed to save locale', e);
    }
  }

  @override
  Future<bool> hasCompletedOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_onboardingCompleteKey) ?? false;
    } catch (e) {
      AppLogger.error('Failed to read onboarding-complete flag', e);
      return false;
    }
  }

  @override
  Future<void> setOnboardingComplete(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingCompleteKey, value);
    } catch (e) {
      AppLogger.error('Failed to save onboarding-complete flag', e);
    }
  }

  @override
  Future<void> clearSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_themeKey);
      await prefs.remove(_localeKey);
      await prefs.remove(_onboardingCompleteKey);
    } catch (e) {
      AppLogger.error('Failed to clear app settings', e);
    }
  }
}
