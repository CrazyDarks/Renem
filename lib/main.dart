import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_shell.dart';
import 'state/app_controller.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [SystemUiOverlay.top],
  );
  runApp(const LanguageMaApp());
}

class LanguageMaApp extends StatefulWidget {
  const LanguageMaApp({super.key});

  @override
  State<LanguageMaApp> createState() => _LanguageMaAppState();
}

class _LanguageMaAppState extends State<LanguageMaApp>
    with WidgetsBindingObserver {
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AppController()..initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [SystemUiOverlay.top],
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.tts.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: _controller,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return MaterialApp(
            title: 'Reman',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: _controller.settings.themeMode,
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              final clampedScaler = mq.textScaler.clamp(
                minScaleFactor: 0.90,
                maxScaleFactor: 1.15,
              );
              return MediaQuery(
                data: mq.copyWith(textScaler: clampedScaler),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: _controller.initialized
                ? const HomeShell()
                : const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
          );
        },
      ),
    );
  }
}
