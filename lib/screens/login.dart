import 'package:flutter/material.dart';
import 'estoque.dart';
import 'vitrine.dart';
import '../services/auth_service.dart';

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

      // Navegar para estoque
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => Estoque(empresa: cnpj)),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro de login: $e')),
      );
      setState(() => isLoading = false);
    }
  }

  // Método para navegar sem retorno
  void _navigateTo(BuildContext context, Widget page) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => page),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 200,
                height: 200,
              ),
              const SizedBox(height: 20),

              // Campo de CNPJ
              SizedBox(
                width: 300,
                child: TextField(
                  controller: cnpjController,
                  decoration: InputDecoration(
                    labelText: 'CNPJ',
                    labelStyle: const TextStyle(color: Color(0xFF0093FF)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF0093FF),
                        width: 2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.blue,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // Campo de Senha
              SizedBox(
                width: 300,
                child: TextField(
                  controller: senhaController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'SENHA',
                    labelStyle: const TextStyle(color: Color(0xFF0093FF)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF0093FF),
                        width: 2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.blue,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Botão de login
              ElevatedButton(
                onPressed: isLoading ? null : loginEmpresa,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0093FF),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('ENTRAR', style: TextStyle(fontSize: 16)),
              ),

              const SizedBox(height: 202),

              // Acesso como cliente
              TextButton(
                onPressed: () => _navigateTo(context, const Vitrine()),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0093FF),
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text('Acessar como cliente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}