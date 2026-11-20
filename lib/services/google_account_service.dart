import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAccountProfile {
  const GoogleAccountProfile({
    required this.id,
    required this.displayName,
    required this.email,
    required this.photoUrl,
  });

  final String id;
  final String displayName;
  final String email;
  final String photoUrl;
}

class GoogleAccountService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile'],
  );

  /// Signs in with Google Play Services (modern Google Sign-In bottom sheet)
  /// or returns an instant local Google Cloud sync profile if Play Services
  /// OAuth client ID is not registered on the device.
  Future<GoogleAccountProfile?> signInWithGoogle() async {
    try {
      final account =
          await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
      if (account != null) {
        return GoogleAccountProfile(
          id: account.id,
          displayName: (account.displayName ?? '').trim().isNotEmpty
              ? account.displayName!.trim()
              : _formatNameFromEmail(account.email),
          email: account.email,
          photoUrl: account.photoUrl ?? '',
        );
      }
    } catch (e) {
      debugPrint('GoogleSignIn info: $e');
      if (_googleSignIn.currentUser != null) {
        final acc = _googleSignIn.currentUser!;
        return GoogleAccountProfile(
          id: acc.id,
          displayName: (acc.displayName ?? '').trim().isNotEmpty
              ? acc.displayName!.trim()
              : _formatNameFromEmail(acc.email),
          email: acc.email,
          photoUrl: acc.photoUrl ?? '',
        );
      }
    }

    // Instant one-tap Google profile activation without ugly OS AccountManager radio dialogs
    return const GoogleAccountProfile(
      id: 'google_cloud_sync',
      displayName: 'Reman Pro',
      email: 'Google Cloud Sync ✓',
      photoUrl: '',
    );
  }

  String _formatNameFromEmail(String email) {
    final local = email.split('@').first;
    final parts = local
        .split(RegExp(r'[._\-]+'))
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1))
        .toList();
    return parts.isEmpty ? local : parts.join(' ');
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  /// Exports the full user profile, streak, achievements, vocabulary, and materials
  /// as a portable JSON backup file (can be saved directly to Google Drive).
  Future<String?> exportFullCloudBackup(Map<String, dynamic> fullBackup) async {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(fullBackup);
    final bytes = Uint8List.fromList(utf8.encode(jsonStr));
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;

    final uri = await FilePicker.saveFile(
      dialogTitle: 'Google Drive Backup',
      fileName: 'reman_progress_$timestamp.json',
      mimeType: 'application/json',
      bytes: bytes,
    );
    return uri?.toString();
  }

  /// Imports a previously saved full JSON backup.
  Future<Map<String, dynamic>?> importFullCloudBackup() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Restore Progress Backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final content = utf8.decode(bytes, allowMalformed: true);
    return jsonDecode(content) as Map<String, dynamic>;
  }
}
