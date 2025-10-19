import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:lottie/lottie.dart';

class ErrorPage extends StatelessWidget {
  final WebResourceError errorDetails;

  const ErrorPage({super.key, required this.errorDetails});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * .12),
            Lottie.asset("assets/animations/lot_error.json"),
            SizedBox(height: MediaQuery.of(context).size.height * .07),
            const Text(
              "OOOPS..",
              style: TextStyle(fontSize: 44, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * .05),
            Text(
              errorDetails.type.toString().replaceAll('_', " "),
              style: const TextStyle(fontSize: 16),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * .02),
            Text(
              kDebugMode
                  ? errorDetails.description.toString().replaceAll('_', " ")
                  : "You have an error.",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: const CircleBorder(),
                fixedSize: const Size(80, 80),
              ),
              onPressed: () {
                Navigator.of(context).pushReplacementNamed('/');
              },
              child: Center(
                child: Icon(Icons.refresh, size: 50, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
