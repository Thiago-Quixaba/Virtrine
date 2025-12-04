import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/utils.dart';
import 'estoque.dart';
import 'vitrine.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final supabase = Supabase.instance.client;
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
      // Consulta a tabela 'empresas'
      final response = await supabase
          .from('empresas')
          .select()
          .eq('cnpj', cnpj)
          .maybeSingle();

      if (response == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Empresa não encontrada.')),
        );
      } else if (response['password'] != senha) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Senha incorreta.')),
        );
      } else {
        // ✅ Login bem-sucedido → redireciona para o estoque
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bem-vindo, ${response['name']}!')),
        );

        // Passa o nome da empresa para a tela Estoque
        redirect(context, Estoque(empresa: response['cnpj']));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro de login: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
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
                onPressed: () => redirect(context, const Vitrine()),
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
