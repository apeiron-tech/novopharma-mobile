import 'dart:async';
import 'package:flutter/material.dart';
import 'package:novopharma/screens/auth_wrapper.dart';
import 'package:novopharma/design/design.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();

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
    return const Scaffold(
      backgroundColor: AppColors.ink,
      body: AuroraBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandLogo(height: 52),
              SizedBox(height: 32),
              CapsuleLoader(size: 52, left: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
