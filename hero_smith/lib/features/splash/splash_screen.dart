import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Expanded(
              flex: 2,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(48.0),
                  child: Image.asset(
                    'data/images/logo/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            // Loading indicator
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32.0),
              child: CircularProgressIndicator(
                color: Colors.indigo,
              ),
            ),
            // Powered by Draw Steel image with flame glow effect
            Padding(
              padding: const EdgeInsets.only(bottom: 48.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    // Outer orange glow (flame effect)
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.4),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                    // Inner yellow/gold glow
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.3),
                      blurRadius: 25,
                      spreadRadius: 5,
                    ),
                    // Core red glow
                    BoxShadow(
                      color: Colors.deepOrange.withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'data/images/loading_screen/powered_by_draw_steel_verticle.webp',
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
