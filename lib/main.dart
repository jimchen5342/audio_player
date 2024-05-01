import 'package:flutter/material.dart';
import 'package:audio_player/home.dart';
import 'package:audio_player/player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        initialRoute: '/home',
        routes: <String, WidgetBuilder>{
          '/home': (BuildContext context) => const Home(),
          '/player': (BuildContext context) => Player(),
        },
      )
    );
  }
}