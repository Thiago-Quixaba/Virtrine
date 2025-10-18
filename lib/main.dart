import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login.dart';
import 'screens/cadastro.dart';
import 'screens/vitrine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialização do Supabase
  await Supabase.initialize(
    url: 'https://nfpglyasksxhiqytpfpr.supabase.co',   // Substitua pela URL do seu projeto
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5mcGdseWFza3N4aGlxeXRwZnByIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk5MDgwNjQsImV4cCI6MjA3NTQ4NDA2NH0.l10wKGFtsginOlvsgDA9Bi8uLKyHWS0765jmqPeLZF8',   // Substitua pela ANON KEY do Supabase
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const Login(),
    );
  }
}
