import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/note.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final service = NoteService();
  await service.loadNotes();

  runApp(
    ChangeNotifierProvider<NoteService>.value(
      value: service,
      child: const UnmaskerApp(),
    ),
  );
}

class UnmaskerApp extends StatelessWidget {
  const UnmaskerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unmasker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFD54F),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'SamsungOne',
        appBarTheme: const AppBarTheme(
          surfaceTintColor: Colors.transparent,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFD54F),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
