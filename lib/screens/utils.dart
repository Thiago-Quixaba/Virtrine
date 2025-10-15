import 'package:flutter/material.dart';

void redirect(BuildContext context, Widget tela) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => tela),
  );
}