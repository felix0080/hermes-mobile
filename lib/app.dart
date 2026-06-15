import 'package:flutter/material.dart';
import 'screens/chat_screen.dart';
import 'screens/conversations_screen.dart';
import 'screens/settings_screen.dart';

class HermesApp extends StatelessWidget {
  const HermesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hermes Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: const ChatScreen(),
      routes: {
        '/conversations': (_) => const ConversationsScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}
