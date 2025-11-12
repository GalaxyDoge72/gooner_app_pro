import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:gooner_app_pro/screens/image_screen.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'main_page.dart';
import 'screens/settings_screen.dart'; 
import 'services/settings_service.dart';

void main() async {
  // Ensure Flutter is initialized before accessing SharedPreferences
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the SettingsService and load preferences once
  final settingsService = SettingsService();
  await settingsService.loadSettings();

  MediaKit.ensureInitialized(); 
  
  runApp(MainApp(settingsService: settingsService));
}

class MainApp extends StatelessWidget {
  final SettingsService settingsService;
  
  const MainApp({required this.settingsService, super.key});

  @override
  Widget build(BuildContext context) {
    // Use ChangeNotifierProvider to make SettingsService available globally
    return ChangeNotifierProvider<SettingsService>(
      create: (context) => settingsService,
      child: Consumer<SettingsService>(
        builder: (context, settings, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Gooner App',
            
            routes: {
              '/settings': (context) => const SettingsScreen(),
              '/image_screen': (context) {
                final args = ModalRoute.of(context)!.settings.arguments;
                return ImageScreen(post: args);
              },
            },
            
            theme: ThemeData(
              brightness: Brightness.light,
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              useMaterial3: true,
            ),
            // Apply the theme based on the saved setting
            themeMode: settings.isDarkModeEnabled ? ThemeMode.dark : ThemeMode.light,
            
            // The 'home' property correctly defines the initial screen (the '/' route).
            home: const MainPage(), 
          );
        },
      ),
    );
  }
}