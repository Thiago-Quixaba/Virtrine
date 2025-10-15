import 'package:flutter/material.dart';

main(){
  runApp(Container(
    child: Center(
      child:  Text('Hello, World!', 
        textDirection: TextDirection.ltr, 
        style: TextStyle(color: Colors.black, fontSize: 20.0)
        ),
      ),
    ));
}