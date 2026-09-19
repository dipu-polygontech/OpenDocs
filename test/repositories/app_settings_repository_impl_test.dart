import 'package:openreader/core/data/repositories/app_settings_repository_impl.dart';
import 'package:openreader/core/domain/models/theme_mode_enum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ODF-P6-03: this repository previously had zero test coverage anywhere in
/// the codebase. Covers the normal round-trip behavior; the try/catch safe
/// defaults on a genuine `SharedPreferences` failure aren't exercised here
/// since the plugin's own test mock doesn't expose a way to make individual
/// calls throw - see the class's own doc comment for why those paths exist.
void main() {
  late AppSettingsRepositoryImpl repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = AppSettingsRepositoryImpl();
  });

  test('theme mode defaults to system and round-trips', () async {
    expect(await repository.getThemeMode(), AppThemeMode.system);
    await repository.setThemeMode(AppThemeMode.dark);
    expect(await repository.getThemeMode(), AppThemeMode.dark);
  });

  test('locale defaults to null and round-trips', () async {
    expect(await repository.getLocale(), isNull);
    await repository.setLocale('bn');
    expect(await repository.getLocale(), 'bn');
  });

  test('onboarding-complete flag defaults to false and round-trips', () async {
    expect(await repository.hasCompletedOnboarding(), isFalse);
    await repository.setOnboardingComplete(true);
    expect(await repository.hasCompletedOnboarding(), isTrue);
  });

  test('clearSettings resets every stored value to its default', () async {
    await repository.setThemeMode(AppThemeMode.dark);
    await repository.setLocale('bn');
    await repository.setOnboardingComplete(true);

    await repository.clearSettings();

    expect(await repository.getThemeMode(), AppThemeMode.system);
    expect(await repository.getLocale(), isNull);
    expect(await repository.hasCompletedOnboarding(), isFalse);
  });
}
