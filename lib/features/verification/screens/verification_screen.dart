import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/local_verification_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/supabase_service.dart';

class VerificationScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  const VerificationScreen({super.key, required this.taskId, required this.taskTitle});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  XFile?    _photo;
  bool      _loading   = false;
  Map<String, dynamic>? _result;
  int       _attempts  = 0;
  static const _maxAttempts = 3;

  final _verifier = LocalVerificationService();

  // ── Photo capture ──────────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (photo == null || !mounted) return;
    setState(() { _photo = photo; _result = null; });
  }

  // ── Verify ─────────────────────────────────────────────────────────────────

  Future<void> _verify() async {
    if (_photo == null) return;
    if (_attempts >= _maxAttempts) { await _markFailed(); return; }

    setState(() => _loading = true);
    try {
      final result = await _verifier.verifyPhoto(
        taskTitle: widget.taskTitle,
        imagePath: _photo!.path,
      );

      if (!mounted) return;
      setState(() { _result = result; _attempts++; });

      if (result['verified'] == true) {
        await _onVerified();
      } else if (_attempts >= _maxAttempts) {
        await _markFailed();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onVerified() async {
    await NotificationService().cancelTaskNotifications(widget.taskId);
    // Upload photo to Supabase storage
    final bytes = await _photo!.readAsBytes();
    try {
      final url = await SupabaseService.uploadVerificationPhoto(widget.taskId, bytes, 'jpg');
      await SupabaseService.saveVerification({
        'task_id':        widget.taskId,
        'photo_url':      url,
        'ai_verified':    true,
        'ai_confidence':  _result?['confidence'],
        'ai_feedback':    _result?['feedback'],
      });
    } catch (_) {
      // Upload failure should not block marking the task done
    }
    await SupabaseService.updateTaskStatus(widget.taskId, 'verified');
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _markFailed() async {
    await NotificationService().cancelTaskNotifications(widget.taskId);
    await SupabaseService.updateTaskStatus(widget.taskId, 'failed');
    if (mounted) Navigator.of(context).pop(false);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final verified  = _result?['verified'] == true;
    final failed    = _result != null && !verified;
    final resultColor = Colors.white;
    final attemptsLeft = _maxAttempts - _attempts;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // Close button
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ),

                // Header
                const Icon(Icons.camera_alt_rounded, size: 40, color: Colors.white),
                const SizedBox(height: 10),
                const Text('Verify Task',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(widget.taskTitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  _attempts == 0
                      ? 'Take a photo to prove completion'
                      : 'Attempt $_attempts / $_maxAttempts  ($attemptsLeft left)',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),
                const SizedBox(height: 20),

                // Photo preview
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _photo == null
                        ? _emptyPhoto()
                        : kIsWeb
                            ? FutureBuilder<dynamic>(
                                future: _photo!.readAsBytes(),
                                builder: (ctx, snap) {
                                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                                  return Image.memory(snap.data!, fit: BoxFit.cover);
                                },
                              )
                            : Image.file(File(_photo!.path), fit: BoxFit.cover,
                                errorBuilder: (ctx, err, st) => _emptyPhoto()),
                  ),
                ),

                // Result banner
                if (_result != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: resultColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: resultColor.withValues(alpha: 0.4)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(verified ? Icons.check_circle : Icons.cancel,
                            color: resultColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _result!['feedback'] ?? '',
                            style: TextStyle(color: resultColor, fontSize: 14,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          '${((_result!['confidence'] as num? ?? 0) * 100).round()}%',
                          style: TextStyle(
                              color: resultColor, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ]),
                      if ((_result!['labels'] as String? ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Detected: ${_result!['labels']}',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ]),
                  ),
                ],

                const SizedBox(height: 16),

                // Buttons
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _pickPhoto,
                      icon: Icon(kIsWeb ? Icons.upload : Icons.camera_alt,
                          color: Colors.white70, size: 18),
                      label: Text(kIsWeb ? 'Upload' : 'Camera',
                          style: const TextStyle(color: Colors.white70)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: (_loading || _photo == null) ? null : _verify,
                      icon: _loading
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.verified, size: 18),
                      label: Text(_loading ? 'Checking…' : 'Verify'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ]),

                // Failed: give up option
                if (failed && attemptsLeft == 0)
                  TextButton(
                    onPressed: _markFailed,
                    child: const Text('Mark as Failed',
                        style: TextStyle(color: Colors.white38)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyPhoto() => Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_a_photo_outlined, size: 56, color: Colors.white24),
          SizedBox(height: 12),
          Text('Tap Camera to take a photo',
              style: TextStyle(color: Colors.white30, fontSize: 14)),
        ]),
      );
}
