import 'dart:io';
import 'package:google_ml_kit/google_ml_kit.dart';

class FaceRecognitionService {
  final FaceDetector _faceDetector = GoogleMlKit.vision.faceDetector();

  Future<List<Face>> detectFaces(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final faces = await _faceDetector.processImage(inputImage);
    return faces;
  }

  Future<bool> verifyFace(File capturedImage, String storedImageUrl) async {
    // This is a simplified version. In reality, you'd compare face embeddings.
    // For now, just check if faces are detected in both.
    final capturedFaces = await detectFaces(capturedImage);
    // You'd need to download and compare with stored image.
    // For demo, assume if faces detected, it's valid.
    return capturedFaces.isNotEmpty;
  }

  Future<void> dispose() async {
    await _faceDetector.close();
  }
}