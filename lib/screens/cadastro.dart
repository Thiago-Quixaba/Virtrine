import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'estoque.dart';
import 'utils.dart';
import 'vitrine.dart';

class CadastroEmpresa extends StatefulWidget {
  const CadastroEmpresa({super.key});

  @override
  State<CadastroEmpresa> createState() => _CadastroEmpresaState();
}

class _CadastroEmpresaState extends State<CadastroEmpresa> {
  final supabase = Supabase.instance.client;

  final TextEditingController nomeController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController cnpjController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();

  bool isLoading = false;

  Future<void> cadastrarEmpresa() async {
    final nome = nomeController.text.trim();
    final email = emailController.text.trim();
    final cnpj = cnpjController.text.trim();
    final senha = senhaController.text.trim();

    if (nome.isEmpty || email.isEmpty || cnpj.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos!')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Verifica se já existe empresa com esse CNPJ
      final existente = await supabase
          .from('empresas')
          .select()
          .eq('cnpj', cnpj)
          .maybeSingle();

      if (existente != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CNPJ já cadastrado.')),
        );
      } else {
        // Faz a inserção no Supabase
        await supabase.from('empresas').insert({
          'name': nome,
          'email': email,
          'cnpj': cnpj,
          'password': senha,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bem-vindo(a), $nome! Cadastro concluído.')),
        );

        // Redireciona para a vitrine após o cadastro
        redirect(context, Estoque(empresa: cnpj));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao cadastrar: $e')),
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

              // Campo nome
              Container(
                width: 300,
                child: TextField(
                  controller: nomeController,
                  decoration: InputDecoration(
                    labelText: 'NOME DA EMPRESA',
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

              // Campo email
              Container(
                width: 300,
                child: TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'E-MAIL',
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

              // Campo CNPJ
              Container(
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

              // Campo senha
              Container(
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

              ElevatedButton(
                onPressed: isLoading ? null : cadastrarEmpresa,
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
                    : const Text('CADASTRAR',
                        style: TextStyle(fontSize: 16)),
              ),

              const SizedBox(height: 20),

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
