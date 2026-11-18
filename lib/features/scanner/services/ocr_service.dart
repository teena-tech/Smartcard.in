import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> recognizeTextFromPath(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      debugPrint('OCR Service error processing $imagePath: $e');
      return '';
    }
  }

  Future<RecognizedText?> recognizeTextBlocksFromPath(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      return await _textRecognizer.processImage(inputImage);
    } catch (e) {
      debugPrint('OCR Service error reading text blocks: $e');
      return null;
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}
