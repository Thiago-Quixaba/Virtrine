import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// ---- FUNÇÃO DE NAVEGAÇÃO  ----
void redirect(BuildContext context, Widget tela) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => tela),
  );
}

/// ---- NOVA FUNÇÃO DE UPLOAD PARA IMGBB ----
class Utils {
  static const String imgbbKey = "42262867f069117f21effd58bd64371a";

  static Future<String?> uploadImageToImgBB(File imageFile) async {
    final url = Uri.parse("https://api.imgbb.com/1/upload?key=$imgbbKey");

    final request = http.MultipartRequest("POST", url);

    request.files.add(await http.MultipartFile.fromPath(
      "image",
      imageFile.path,
    ));

    final response = await request.send();
    final responseData = await http.Response.fromStream(response);

    if (response.statusCode == 200) {
      final data = jsonDecode(responseData.body);
      return data["data"]["url"];
    } else {
      print("Erro no ImgBB: ${responseData.body}");
      return null;
    }
  }
}
