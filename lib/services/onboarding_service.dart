import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  const OnboardingService();

  static const _completedKey = 'onboarding_completed_v1';

  Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_completedKey) ?? false;
  }

  Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, true);
  }
}
