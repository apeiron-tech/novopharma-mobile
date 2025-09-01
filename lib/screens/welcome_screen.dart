import 'dart:async';
import 'package:flutter/material.dart';
import 'package:novopharma/controllers/fab_visibility_provider.dart';
import 'package:novopharma/screens/auth_wrapper.dart';
import 'package:novopharma/theme.dart';
import 'package:provider/provider.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();

    // Hide the FAB as soon as this screen is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FabVisibilityProvider>(context, listen: false).hideFab();
    });

    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightModeColors.novoPharmaLightBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Image.asset('assets/images/logo.png'),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 255, 0, 0)),
            ),
          ],
        ),
      ),
    );
  }
}
