import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'estoque.dart';
import 'vitrine.dart';
import '../services/auth_service.dart';
import 'theme_manager.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final AuthService _authService = AuthService();
  final TextEditingController cnpjController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();

  bool isLoading = false;
  bool _senhaVisivel = false; // Nova variável para controlar visibilidade da senha

  Future<void> loginEmpresa() async {
    final cnpj = cnpjController.text.trim();
    final senha = senhaController.text.trim();

    if (cnpj.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos!')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final success = await _authService.login(cnpj, senha);

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CNPJ ou senha incorretos!')),
        );
        setState(() => isLoading = false);
        return;
      }

      final usuario = await _authService.getUsuarioLogado();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bem-vindo, ${usuario['nome']}!')),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => Estoque(empresa: cnpj),
        ),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro de login: $e')),
      );
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);

    return Scaffold(
      backgroundColor: themeManager.scaffoldBgColor,
      appBar: AppBar(
        backgroundColor: themeManager.cardBgColor,
        foregroundColor: themeManager.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              themeManager.isDarkMode
                  ? Icons.wb_sunny
                  : Icons.nightlight_round,
              color: themeManager.textPrimary,
            ),
            tooltip:
                themeManager.isDarkMode ? 'Modo Claro' : 'Modo Escuro',
            onPressed: themeManager.toggleTheme,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              /// LOGO
              SizedBox(
                width: 200,
                height: 200,
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 20),

              /// CNPJ
              SizedBox(
                width: 300,
                child: TextField(
                  controller: cnpjController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: themeManager.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'CNPJ',
                    labelStyle:
                        TextStyle(color: themeManager.primaryColor),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: themeManager.primaryColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: themeManager.primaryColor),
                    ),
                    filled: true,
                    fillColor: themeManager.inputBgColor,
                  ),
                ),
              ),

              const SizedBox(height: 15),

              /// SENHA COM OLHINHO
              SizedBox(
                width: 300,
                child: TextField(
                  controller: senhaController,
                  obscureText: !_senhaVisivel, // Invertido para funcionar corretamente
                  style: TextStyle(color: themeManager.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'SENHA',
                    labelStyle:
                        TextStyle(color: themeManager.primaryColor),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: themeManager.primaryColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: themeManager.primaryColor),
                    ),
                    filled: true,
                    fillColor: themeManager.inputBgColor,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _senhaVisivel
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: themeManager.primaryColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _senhaVisivel = !_senhaVisivel;
                        });
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              /// BOTÃO ENTRAR
              ElevatedButton(
                onPressed: isLoading ? null : loginEmpresa,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeManager.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 40,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'ENTRAR',
                        style: TextStyle(fontSize: 16),
                      ),
              ),

              const SizedBox(height: 200),

              /// ACESSAR COMO CLIENTE
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Vitrine(),
                    ),
                  );
                },
                child: Text(
                  'Acessar como cliente',
                  style:
                      TextStyle(color: themeManager.primaryColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}