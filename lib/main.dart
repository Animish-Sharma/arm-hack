import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_translator/providers/translator_provider.dart';
import 'package:speech_translator/screens/home_screen.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterGemma.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TranslatorProvider(),
      child: MaterialApp(
        title: 'Voice Translator',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF6366F1),
          scaffoldBackgroundColor: const Color(0xFF111827),
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFF6366F1),
            secondary: const Color(0xFF8B5CF6),
            surface: const Color(0xFF1F2937),
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
