import 'package:permission_handler/permission_handler.dart';

class PermissionStatusSummary {
  const PermissionStatusSummary({
    required this.microphoneGranted,
    required this.cameraGranted,
    required this.galleryGranted,
  });

  final bool microphoneGranted;
  final bool cameraGranted;
  final bool galleryGranted;

  bool get allGranted => microphoneGranted && cameraGranted && galleryGranted;
}

class PermissionService {
  Future<PermissionStatusSummary> checkAll() async {
    final mic = await Permission.microphone.status;
    final cam = await Permission.camera.status;

    return PermissionStatusSummary(
      microphoneGranted: mic.isGranted,
      cameraGranted: cam.isGranted,
      // Android system Photo Picker works without runtime storage permissions.
      galleryGranted: true,
    );
  }

  /// Requests microphone permission on-demand when the user starts voice recording.
  Future<bool> ensureMicrophone() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  /// Requests camera permission on-demand when the user chooses to take a photo.
  Future<bool> ensureCamera() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    final result = await Permission.camera.request();
    return result.isGranted;
  }

  /// System Photo Picker does not require READ_MEDIA_IMAGES / READ_EXTERNAL_STORAGE on Android.
  Future<bool> ensureGallery() async {
    return true;
  }

  Future<void> openSystemSettings() async {
    await openAppSettings();
  }
}
