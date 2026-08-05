import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';

class CraveApp extends StatelessWidget {
  const CraveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crave',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _ThemePreviewScreen(),
    );
  }
}

/// Temporary placeholder screen — proves the theme is wired correctly
/// (text, buttons, colors all pulling from AppTheme, not inline values).
/// Gets replaced by real go_router routing in Phase 3.
class _ThemePreviewScreen extends StatelessWidget {
  const _ThemePreviewScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crave')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Theme wired up',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Colors, fonts, and spacing are all pulling from AppTheme now — nothing hardcoded.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Primary Button'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Secondary Button'),
            ),
            const SizedBox(height: 24),
            const TextField(
              decoration: InputDecoration(hintText: 'Text field test'),
            ),
          ],
        ),
      ),
    );
  }
}
