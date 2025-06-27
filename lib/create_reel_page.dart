import 'dart:io' as io;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

// Conditional import: real dart:html on web, stub everywhere else
import 'src/html_stub.dart'
if (dart.library.html) 'dart:html' as html;

class CreateReelPage extends StatefulWidget {
  const CreateReelPage({super.key});

  @override
  State<CreateReelPage> createState() => _CreateReelPageState();
}

class _CreateReelPageState extends State<CreateReelPage> {
  final _captionController = TextEditingController();
  final _uuid = const Uuid();

  io.File?   _videoFile;           // mobile / desktop
  Uint8List? _videoBytes;          // web
  String?    _blobUrl;             // web
  late VideoPlayerController _player;
  bool _initialised = false;
  bool _isUploading = false;

  @override
  void dispose() {
    _captionController.dispose();
    if (_initialised) {
      if (kIsWeb && _blobUrl != null) html.Url.revokeObjectUrl(_blobUrl!);
      _player.dispose();
    }
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: kIsWeb,
    );
    if (result == null) return;

    if (kIsWeb) {
      _videoBytes = result.files.single.bytes!;
      _blobUrl = html.Url.createObjectUrlFromBlob(
        html.Blob([_videoBytes!], 'video/mp4'),
      );
      _player = VideoPlayerController.network(_blobUrl!)
        ..initialize().then((_) {
          setState(() => _initialised = true);
          _player..setLooping(true)..play();
        });
    } else {
      _videoFile = io.File(result.files.single.path!);
      _player = VideoPlayerController.file(_videoFile!)
        ..initialize().then((_) {
          setState(() => _initialised = true);
          _player..setLooping(true)..play();
        });
    }
  }

  Future<void> _upload() async {
    if (_videoFile == null && _videoBytes == null) return;
    setState(() => _isUploading = true);

    final reelId = _uuid.v4();
    final storageRef = FirebaseStorage.instance.ref('reels/$reelId.mp4');

    try {
      final task = kIsWeb
          ? storageRef.putData(_videoBytes!)
          : storageRef.putFile(_videoFile!);
      await task.whenComplete(() {});
      final url = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance.collection('reels').doc(reelId).set({
        'id'       : reelId,
        'caption'  : _captionController.text.trim(),
        'videoUrl' : url,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Upload complete ✅')));

      // reset UI
      if (_initialised) {
        if (kIsWeb && _blobUrl != null) html.Url.revokeObjectUrl(_blobUrl!);
        _player.dispose();
      }
      _videoFile = null;
      _videoBytes = null;
      _blobUrl = null;
      _initialised = false;
      _captionController.clear();
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Reel')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_initialised)
              AspectRatio(
                aspectRatio: _player.value.aspectRatio,
                child: VideoPlayer(_player),
              )
            else
              Container(
                height: 200,
                color: Colors.grey.shade900,
                alignment: Alignment.center,
                child: const Text('No video selected'),
              ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.video_library),
              label: const Text('Pick a video'),
              onPressed: _isUploading ? null : _pickVideo,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Caption',
              ),
              enabled: !_isUploading,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: _isUploading
                  ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.cloud_upload),
              label: Text(_isUploading ? 'Uploading…' : 'Upload'),
              onPressed: (_videoFile == null && _videoBytes == null) || _isUploading
                  ? null
                  : _upload,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ],
        ),
      ),
    );
  }
}