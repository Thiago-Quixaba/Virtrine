import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager with ChangeNotifier {
  static const String themeKey = 'isDarkMode';
  
  bool _isDarkMode = false;
  
  bool get isDarkMode => _isDarkMode;
  
  Color get primaryColor => const Color(0xFF0093FF);
  Color get primaryColorDark => const Color(0xFF0066CC);
  
  ThemeManager() {
    _loadTheme();
  }
  
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(themeKey) ?? false;
    notifyListeners();
  }
  
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(themeKey, _isDarkMode);
    notifyListeners();
  }
  
  ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color(0xFF0093FF),
    primaryColorDark: const Color(0xFF0066CC),
    scaffoldBackgroundColor: const Color(0xFFF8F9FA),
    cardColor: const Color(0xFFF8F9FA), 
    dialogBackgroundColor: Colors.white,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF333333)),
      bodyMedium: TextStyle(color: Color(0xFF666666)),
      bodySmall: TextStyle(color: Color(0xFF999999)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF8F9FA), 
      foregroundColor: Color(0xFF333333),
      elevation: 0,
      scrolledUnderElevation: 0, 
      surfaceTintColor: Colors.transparent, // Prevenir efeito de transparência
    ),
    dividerColor: const Color(0xFF0093FF),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF0093FF),
      secondary: Color(0xFF2E7D32),
      surface: Color(0xFFF8F9FA),
      background: Color(0xFFF8F9FA),
      error: Colors.red,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFF333333),
      onBackground: Color(0xFF333333),
      onError: Colors.white,
      surfaceTint: Colors.transparent, // Adicionado para prevenir efeito de transparência
    ),
    useMaterial3: true, // Adicionado para suporte a Material 3
  );
  
  ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF0093FF),
    primaryColorDark: const Color(0xFF0066CC),
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: const Color(0xFF121212), 
    dialogBackgroundColor: const Color(0xFF1E1E1E),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFFFFFFFF)),
      bodyMedium: TextStyle(color: Color(0xFFB0B0B0)),
      bodySmall: TextStyle(color: Color(0xFF888888)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF121212), 
      foregroundColor: Colors.white,
      elevation: 0, 
      scrolledUnderElevation: 0, 
      surfaceTintColor: Colors.transparent, // Prevenir efeito de transparência
    ),
    dividerColor: const Color(0xFF0093FF),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF0093FF),
      secondary: Color(0xFF4CAF50),
      surface: Color(0xFF121212), 
      background: Color(0xFF121212),
      error: Colors.red,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
      onBackground: Colors.white,
      onError: Colors.white,
      surfaceTint: Colors.transparent, // Adicionado para prevenir efeito de transparência
    ),
    useMaterial3: true, // Adicionado para suporte a Material 3
  );
  
  // Cores específicas para uso direto
  Color get textPrimary => _isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF333333);
  Color get textSecondary => _isDarkMode ? const Color(0xFFB0B0B0) : const Color(0xFF666666);
  Color get textTertiary => _isDarkMode ? const Color(0xFF888888) : const Color(0xFF999999);
  Color get borderColor => _isDarkMode ? const Color(0xFF333333) : const Color.fromARGB(255, 224, 224, 224);
  Color get successColor => _isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32);
  Color get warningColor => _isDarkMode ? const Color(0xFFFFB74D) : const Color(0xFFF57C00);
  Color get scaffoldBgColor => _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
  Color get cardBgColor => _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA); 
  Color get dialogBgColor => _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get inputBgColor => _isDarkMode ? const Color(0xFF2D2D2D) : Colors.white;
  Color get inputBorderColor => _isDarkMode ? const Color(0xFF444444) : const Color(0xFFE0E0E0);
}