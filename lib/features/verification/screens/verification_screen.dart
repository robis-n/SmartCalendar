import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../../../services/claude_service.dart';
import '../../../services/supabase_service.dart';

class VerificationScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  const VerificationScreen({super.key, required this.taskId, required this.taskTitle});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  XFile? _photo;
  Uint8List? _photoBytes; // used on web
  bool _loading = false;
  Map<String, dynamic>? _result;
  int _attempts = 0;
  static const int maxAttempts = 3;

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    setState(() {
      _photo = photo;
      _photoBytes = bytes;
      _result = null;
    });
  }

  Future<void> _verify() async {
    if (_photo == null || _photoBytes == null) return;
    if (_attempts >= maxAttempts) {
      _markFailed();
      return;
    }
    setState(() => _loading = true);
    try {
      // Resize to save tokens
      final decoded = img.decodeImage(_photoBytes!);
      final resized = decoded != null ? img.copyResize(decoded, width: 512) : null;
      final Uint8List finalBytes = resized != null
          ? Uint8List.fromList(img.encodeJpg(resized, quality: 80))
          : _photoBytes!;

      final base64Image = base64Encode(finalBytes);
      final result = await ClaudeService().verifyPhoto(
        taskTitle: widget.taskTitle,
        base64Image: base64Image,
        mediaType: 'image/jpeg',
      );

      setState(() { _result = result; _attempts++; });

      if (result['verified'] == true) {
        final url = await SupabaseService.uploadVerificationPhoto(widget.taskId, finalBytes, 'jpg');
        await SupabaseService.saveVerification({
          'task_id': widget.taskId,
          'photo_url': url,
          'ai_verified': true,
          'ai_confidence': result['confidence'],
          'ai_feedback': result['feedback'],
        });
        await SupabaseService.updateTaskStatus(widget.taskId, 'verified');
        if (mounted) Navigator.of(context).pop(true);
      } else if (_attempts >= maxAttempts) {
        await _markFailed();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markFailed() async {
    await SupabaseService.updateTaskStatus(widget.taskId, 'failed');
    if (mounted) Navigator.of(context).pop(false);
  }

  Color get _resultColor {
    if (_result == null) return Colors.grey;
    return _result!['verified'] == true ? Colors.green : Colors.red;
  }

  Widget _buildPhotoPreview() {
    if (_photoBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.memory(_photoBytes!, fit: BoxFit.cover),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo_outlined, size: 64, color: Colors.white38),
          SizedBox(height: 12),
          Text('Tap below to take a photo', style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                const Icon(Icons.camera_alt_rounded, size: 48, color: Color(0xFF6C63FF)),
                const SizedBox(height: 12),
                const Text('Prove It!', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(widget.taskTitle, style: const TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text('Attempt ${_attempts + 1} / $maxAttempts', style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                const SizedBox(height: 32),

                Expanded(child: _buildPhotoPreview()),

                if (_result != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _resultColor.withValues(alpha:0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _resultColor.withValues(alpha:0.5)),
                    ),
                    child: Row(children: [
                      Icon(_result!['verified'] == true ? Icons.check_circle : Icons.cancel, color: _resultColor),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_result!['feedback'] ?? '', style: TextStyle(color: _resultColor))),
                      Text('${((_result!['confidence'] ?? 0) * 100).round()}%', style: TextStyle(color: _resultColor, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ],

                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _takePhoto,
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      label: Text(kIsWeb ? 'Upload Photo' : 'Take Photo', style: const TextStyle(color: Colors.white)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white38), padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: (_loading || _photoBytes == null) ? null : _verify,
                      icon: _loading
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.verified),
                      label: Text(_loading ? 'Verifying...' : 'Verify'),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
