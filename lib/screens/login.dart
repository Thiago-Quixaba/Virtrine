import 'package:flutter/material.dart';
import 'utils.dart';
import 'vitrine.dart';

class Login extends StatelessWidget {
  const Login({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 200,
              height: 200,
            ),

            Container(
              width: 300,
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'CNPJ',
                  labelStyle: TextStyle(
                    color: Color(0xFF0093FF),
                  ),
                  filled: false, 
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Color(0xFF0093FF), 
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.blue,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            Container(
              width: 300,
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'SENHA',
                  labelStyle: TextStyle(
                    color: Color(0xFF0093FF),
                  ),
                  filled: false, 
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Color(0xFF0093FF), 
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.blue,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                // ação do botão
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0093FF),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20), 
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'ENTRAR',
                style: TextStyle(fontSize: 16),
              ),
            ),

            const SizedBox(height: 202),

            TextButton(
              onPressed: () => redirect(context, const Vitrine()),
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFF0093FF),
                padding: EdgeInsets.all(16),
              ),
              child: Text('Acessar como cliente'),
            )

          ],
        ),
      ),
    );
  }
}
