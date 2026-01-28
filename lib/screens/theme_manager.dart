// Importa os widgets e classes do Material Design
import 'package:flutter/material.dart';

// Importa o SharedPreferences para salvar dados localmente (tema claro/escuro)
import 'package:shared_preferences/shared_preferences.dart';

// Classe responsável por gerenciar o tema da aplicação
// ChangeNotifier permite avisar a interface quando algo mudar
class ThemeManager with ChangeNotifier {

  // Chave usada para salvar o tema no SharedPreferences
  static const String themeKey = 'isDarkMode';

  // Variável privada que guarda se o tema é escuro ou não
  bool _isDarkMode = false;

  // Getter público para acessar o estado do tema
  bool get isDarkMode => _isDarkMode;

  // Cor principal do aplicativo (usada em botões, destaques, etc.)
  Color get primaryColor => const Color(0xFF0093FF);

  // Versão mais escura da cor principal
  Color get primaryColorDark => const Color(0xFF0066CC);

  // Construtor da classe
  // Executa ao criar o ThemeManager
  ThemeManager() {
    _loadTheme(); // Carrega o tema salvo
  }

  // Método assíncrono para carregar o tema salvo no celular
  Future<void> _loadTheme() async {
    // Obtém a instância do SharedPreferences
    final prefs = await SharedPreferences.getInstance();

    // Lê o valor salvo (se não existir, usa false = tema claro)
    _isDarkMode = prefs.getBool(themeKey) ?? false;

    // Notifica a interface que o estado mudou
    notifyListeners();
  }

  // Método para alternar entre tema claro e escuro
  Future<void> toggleTheme() async {
    // Inverte o valor atual do tema
    _isDarkMode = !_isDarkMode;

    // Obtém a instância do SharedPreferences
    final prefs = await SharedPreferences.getInstance();

    // Salva a nova preferência do tema
    await prefs.setBool(themeKey, _isDarkMode);

    // Atualiza a interface
    notifyListeners();
  }

  // ====================== TEMA CLARO ======================
  ThemeData get lightTheme => ThemeData(
        // Define o brilho do tema como claro
        brightness: Brightness.light,

        // Define a cor principal
        primaryColor: primaryColor,

        // Define a versão escura da cor principal
        primaryColorDark: primaryColorDark,

        // Cor de fundo das telas (Scaffold)
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),

        // Cor de fundo dos cards
        cardColor: Colors.white,

        // Cor de fundo de diálogos
        dialogBackgroundColor: Colors.white,

        // Configuração da AppBar (barra superior)
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8F9FA), // mesma cor do fundo
          foregroundColor: Color(0xFF333333), // cor dos ícones e texto
          elevation: 0, // remove sombra
        ),

        // Estilos de texto
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF333333)), // texto principal
          bodyMedium: TextStyle(color: Color(0xFF666666)), // texto secundário
          bodySmall: TextStyle(color: Color(0xFF999999)), // texto auxiliar
        ),

        // Cor das linhas divisórias
        dividerColor: const Color(0xFFE0E0E0),

        // Esquema de cores usado pelo Material
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0093FF), // cor primária
          secondary: Color(0xFF2E7D32), // cor secundária
          surface: Colors.white, // superfícies (cards, sheets)
          background: Color(0xFFF8F9FA), // fundo geral
          error: Colors.red, // cor de erro
          onPrimary: Colors.white, // texto sobre primary
          onSecondary: Colors.white,
          onSurface: Color(0xFF333333),
          onBackground: Color(0xFF333333),
          onError: Colors.white,
        ),
      );

  // ====================== TEMA ESCURO ======================
  ThemeData get darkTheme => ThemeData(
        // Define o brilho do tema como escuro
        brightness: Brightness.dark,

        // Cor principal
        primaryColor: primaryColor,

        // Versão escura da cor principal
        primaryColorDark: primaryColorDark,

        // Fundo das telas
        scaffoldBackgroundColor: const Color(0xFF121212),

        // Fundo dos cards
        cardColor: const Color(0xFF121212),

        // Fundo dos diálogos
        dialogBackgroundColor: const Color(0xFF1E1E1E),

        // Configuração da AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212), // igual ao fundo
          foregroundColor: Colors.white, // texto branco
          elevation: 0, // sem sombra
        ),

        // Estilos de texto no modo escuro
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Color(0xFFB0B0B0)),
          bodySmall: TextStyle(color: Color(0xFF888888)),
        ),

        // Cor das divisórias
        dividerColor: const Color(0xFF333333),

        // Esquema de cores do modo escuro
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0093FF),
          secondary: Color(0xFF4CAF50),
          surface: Color(0xFF1E1E1E),
          background: Color(0xFF121212),
          error: Colors.red,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.white,
          onBackground: Colors.white,
          onError: Colors.white,
        ),
      );

  // ============ CORES PARA USO DIRETO ============
  // Texto principal
  Color get textPrimary =>
      _isDarkMode ? Colors.white : const Color(0xFF333333);

  // Texto secundário
  Color get textSecondary =>
      _isDarkMode ? const Color(0xFFB0B0B0) : const Color(0xFF666666);

  // Texto auxiliar
  Color get textTertiary =>
      _isDarkMode ? const Color(0xFF888888) : const Color(0xFF999999);

  // Cor de bordas
  Color get borderColor =>
      _isDarkMode ? const Color(0xFF333333) : const Color(0xFFE0E0E0);

  // Cor de sucesso
  Color get successColor =>
      _isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32);

  // Cor de aviso
  Color get warningColor =>
      _isDarkMode ? const Color(0xFFFFB74D) : const Color(0xFFF57C00);

  // Cor de fundo geral
  Color get scaffoldBgColor =>
      _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA);

  // Cor de fundo dos cards
  Color get cardBgColor =>
      _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

  // Cor de fundo dos diálogos
  Color get dialogBgColor =>
      _isDarkMode ? const Color(0xFF121212) : Colors.white;

  // Fundo de campos de input
  Color get inputBgColor =>
      _isDarkMode ? const Color(0xFF2D2D2D) : Colors.white;

  // Borda dos campos de input
  Color get inputBorderColor =>
      _isDarkMode ? const Color(0xFF444444) : const Color(0xFFE0E0E0);
}
