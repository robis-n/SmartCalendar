import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/notification_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/verification_service.dart';

/// Minimalist photo verification — pure ink+paper, single primary action,
/// no decorative gradients. Sits over the ROOT navigator so it covers the
/// bottom nav (pushed via rootNavigator: true).
class VerificationScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  final String? taskDescription;
  const VerificationScreen({
    super.key,
    required this.taskId,
    required this.taskTitle,
    this.taskDescription,
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  XFile?               _photo;
  bool                 _loading  = false;
  Map<String, dynamic>? _result;
  int                  _attempts = 0;
  static const _maxAttempts = 3;

  // Claude vision via Edge Function when available, on-device ML otherwise.
  final _verifier = VerificationService();

  Future<void> _pickPhoto() async {
    final photo = await ImagePicker().pickImage(
      source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
      maxWidth: 800, maxHeight: 800, imageQuality: 85,
    );
    if (photo == null || !mounted) return;
    setState(() { _photo = photo; _result = null; });
  }

  Future<void> _verify() async {
    if (_photo == null) return;
    if (_attempts >= _maxAttempts) { await _markFailed(); return; }

    setState(() => _loading = true);
    try {
      final bytes = await _photo!.readAsBytes();
      final result = await _verifier.verifyPhoto(
        taskTitle: widget.taskTitle,
        taskDescription: widget.taskDescription,
        imagePath: _photo!.path,
        imageBytes: bytes,
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onVerified() async {
    await NotificationService().cancelTaskNotifications(widget.taskId);
    final bytes = await _photo!.readAsBytes();
    try {
      final url = await SupabaseService.uploadVerificationPhoto(widget.taskId, bytes, 'jpg');
      await SupabaseService.saveVerification({
        'task_id':       widget.taskId,
        'photo_url':     url,
        'ai_verified':   true,
        'ai_confidence': _result?['confidence'],
        'ai_feedback':   _result?['feedback'],
      });
    } catch (_) { /* upload failure shouldn't block completion */ }
    await SupabaseService.updateTaskStatus(widget.taskId, 'verified');
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _markFailed() async {
    await NotificationService().cancelTaskNotifications(widget.taskId);
    await SupabaseService.updateTaskStatus(widget.taskId, 'failed');
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final verified  = _result?['verified'] == true;
    final failed    = _result != null && !verified;
    final attemptsLeft = _maxAttempts - _attempts;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // ── Top bar — close only ─────────────────────────
            Row(children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(null),
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.bg2,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.separator, width: 0.8),
                  ),
                  child: Icon(Icons.close_rounded, size: 18, color: AppColors.label),
                ),
              ),
              const Spacer(),
              if (_attempts > 0)
                Text('Attempt $_attempts / $_maxAttempts',
                    style: TextStyle(color: AppColors.label3, fontSize: 13,
                        fontWeight: FontWeight.w600, letterSpacing: 0.4)),
            ]),

            const SizedBox(height: 28),

            // ── Title — centred, big, personal ───────────────
            Text('Prove it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 44, fontWeight: FontWeight.w800,
                color: AppColors.label, letterSpacing: -2, height: 1.0,
              )),
            const SizedBox(height: 10),
            Text(widget.taskTitle,
              textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16, color: AppColors.label3, fontWeight: FontWeight.w500,
              )),

            const SizedBox(height: 22),

            // ── Photo frame ──────────────────────────────────
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: _photo == null ? _emptyFrame() : _photoFrame(),
              ),
            ),

            // ── Result strip (only after a try) ──────────────
            if (_result != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.bg2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.separator, width: 0.8),
                ),
                child: Row(children: [
                  Icon(verified ? Icons.check_rounded : Icons.close_rounded,
                      size: 20, color: AppColors.label),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_result!['feedback'] ?? '',
                      style: TextStyle(color: AppColors.label, fontSize: 14,
                          fontWeight: FontWeight.w500))),
                  Text('${((_result!['confidence'] as num? ?? 0) * 100).round()}%',
                      style: TextStyle(color: AppColors.label3, fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ],

            const SizedBox(height: 16),

            // ── Primary action — one button does the right thing ──
            FilledButton(
              onPressed: _loading
                  ? null
                  : (_photo == null
                      ? _pickPhoto
                      : _verify),
              child: _loading
                  ? SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.bg))
                  : Text(_photo == null
                      ? (kIsWeb ? 'Upload photo' : 'Take photo')
                      : 'Verify'),
            ),
            if (_photo != null && !_loading) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _pickPhoto,
                child: Center(child: Text('Retake',
                    style: TextStyle(fontSize: 14, color: AppColors.label3,
                        fontWeight: FontWeight.w600))),
              ),
            ],

            // Bail-out for the very stuck — only after max attempts.
            if (failed && attemptsLeft == 0) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _markFailed,
                child: Center(child: Text('Give up',
                    style: TextStyle(fontSize: 14, color: AppColors.label3))),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _emptyFrame() => Container(
    decoration: BoxDecoration(
      color: AppColors.bg2,
      border: Border.all(color: AppColors.separator, width: 0.8),
    ),
    alignment: Alignment.center,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.photo_camera_outlined, size: 48, color: AppColors.label3),
      const SizedBox(height: 12),
      Text(kIsWeb ? 'Pick a photo to verify' : 'Snap proof to verify',
          style: TextStyle(fontSize: 15, color: AppColors.label3)),
    ]),
  );

  Widget _photoFrame() => kIsWeb
      ? FutureBuilder<dynamic>(
          future: _photo!.readAsBytes(),
          builder: (ctx, snap) => snap.hasData
              ? Image.memory(snap.data!, fit: BoxFit.cover)
              : Center(child: CircularProgressIndicator(color: AppColors.label)),
        )
      : Image.file(File(_photo!.path), fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _emptyFrame());
}
