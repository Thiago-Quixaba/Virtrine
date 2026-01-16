import 'package:flutter/material.dart'; // ADICIONE ESTE IMPORT
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final supabase = Supabase.instance.client;

  // Chaves para SharedPreferences
  static const String _cnpjKey = 'empresa_cnpj';
  static const String _nomeKey = 'empresa_nome';
  static const String _isLoggedInKey = 'is_logged_in';

  // Verificar se está logado
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  // Fazer login
  Future<bool> login(String cnpj, String senha) async {
    try {
      final response = await supabase
          .from('empresas')
          .select()
          .eq('cnpj', cnpj)
          .maybeSingle();

      if (response == null) {
        return false;
      }

      if (response['password'] != senha) {
        return false;
      }

      // Salvar dados de sessão
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cnpjKey, cnpj);
      await prefs.setString(_nomeKey, response['name'] ?? 'Empresa');
      await prefs.setBool(_isLoggedInKey, true);

      return true;
    } catch (e) {
      debugPrint('Erro no login: $e');
      return false;
    }
  }

  // Fazer logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cnpjKey);
    await prefs.remove(_nomeKey);
    await prefs.remove(_isLoggedInKey);
  }

  // Obter dados do usuário logado
  Future<Map<String, String>> getUsuarioLogado() async {
    final prefs = await SharedPreferences.getInstance();
    final cnpj = prefs.getString(_cnpjKey);
    final nome = prefs.getString(_nomeKey);

    return {
      'cnpj': cnpj ?? '',
      'nome': nome ?? '',
    };
  }
}