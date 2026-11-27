import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:smartcard_flutter/main.dart';

class LottieLoader extends StatelessWidget {
  final double size;
  const LottieLoader({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Center(
        child: SizedBox(
          width: size,
          height: size,
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              Theme.of(context).brightness == Brightness.light 
                  ? Colors.red 
                  : Colors.white,
              BlendMode.srcATop,
            ),
            child: globalLottieComposition != null
                ? Lottie(
                    composition: globalLottieComposition,
                    fit: BoxFit.contain,
                    repeat: true,
                    animate: true,
                  )
                : Lottie.asset(
                    'assets/lottie/loading_loop.json',
                    fit: BoxFit.contain,
                    repeat: true,
                    animate: true,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Lottie error: $error');
                      return const CircularProgressIndicator(color: Colors.redAccent);
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
