import 'package:flutter/material.dart';

class Vitrine extends StatelessWidget {
  const Vitrine({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                  Image.asset(
                      'assets/images/logo.png',
                      width: 100,
                      height: 100,
                  ),
              ],
            ),
            const SizedBox(height: 400),
          ],
        ),
      ),
    );
  }
}