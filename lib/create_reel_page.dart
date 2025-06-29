import 'dart:io' as io;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'package:ai_reels/view_reels_page.dart';
// Import AuthService and LoginPage for logout functionality
import 'package:ai_reels/auth_service.dart';
import 'package:ai_reels/login_page.dart';

// Conditional import: real dart:html on web, stub everywhere else
import 'src/html_stub.dart' if (dart.library.html) 'dart:html' as html;

class CreateReelPage extends StatefulWidget {
  const CreateReelPage({super.key});

  @override
  State<CreateReelPage> createState() => _CreateReelPageState();
}

class _CreateReelPageState extends State<CreateReelPage> {
  final _captionController = TextEditingController();
  final _uuid = const Uuid();
  final AuthService _authService = AuthService(); // Instantiate AuthService

  io.File? _videoFile; // mobile / desktop
  Uint8List? _videoBytes; // web
  String? _blobUrl; // web
  late VideoPlayerController _player;
  bool _initialised = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void dispose() {
    _captionController.dispose();
    if (_initialised) {
      if (kIsWeb && _blobUrl != null) {
        // It's good practice to check if html is available, though kIsWeb usually covers this.
        // However, the conditional import handles the html object not being available on other platforms.
        html.Url.revokeObjectUrl(_blobUrl!);
      }
      _player.dispose();
    }
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: kIsWeb, // For web, we need the bytes directly
    );
    if (result == null) return; // User canceled the picker

    // Clear previous video resources if any
    if (_initialised) {
      if (kIsWeb && _blobUrl != null) {
        html.Url.revokeObjectUrl(_blobUrl!);
        _blobUrl = null;
      }
      _player.dispose();
      _initialised = false;
    }
    _videoFile = null;
    _videoBytes = null;
    setState(() {}); // Update UI to remove old video if any

    if (kIsWeb) {
      _videoBytes = result.files.single.bytes!;
      _blobUrl = html.Url.createObjectUrlFromBlob(
        html.Blob([_videoBytes!], 'video/mp4'),
      );
      _player = VideoPlayerController.networkUrl(Uri.parse(_blobUrl!))
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() => _initialised = true);
          _player
            ..setLooping(true)
            ..play();
        });
    } else {
      // Mobile or Desktop
      _videoFile = io.File(result.files.single.path!);
      _player = VideoPlayerController.file(_videoFile!)
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() => _initialised = true);
          _player
            ..setLooping(true)
            ..play();
        });
    }
  }

  Future<void> _upload() async {
    if (_videoFile == null && _videoBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a video first!')));
      }
      return;
    }

    // Check if user is logged in
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('You must be logged in to upload a reel.')));
        // Optionally navigate to login page
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
              (Route<dynamic> route) => false,
        );
      }
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    final reelId = _uuid.v4();
    final storageRef = FirebaseStorage.instance.ref('reels/$reelId.mp4');
    UploadTask uploadTask;

    try {
      if (kIsWeb) {
        uploadTask = storageRef.putData(
            _videoBytes!, SettableMetadata(contentType: 'video/mp4'));
      } else {
        uploadTask = storageRef.putFile(_videoFile!);
      }

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (mounted) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
        }
      });

      await uploadTask; // Wait for upload to finish (whenComplete is also fine)
      final url = await storageRef.getDownloadURL();

      // Save reel metadata to Firestore
      await FirebaseFirestore.instance.collection('reels').doc(reelId).set({
        'id': reelId,
        'caption': _captionController.text.trim(),
        'videoUrl': url,
        'createdAt': FieldValue.serverTimestamp(),
        'uploaderId': currentUser.uid, // ADDED: Store the uploader's ID
        // 'likes': 0, // Optional: for like functionality
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reel uploaded successfully! ✅')));

      // Reset UI after successful upload
      if (_initialised) {
        if (kIsWeb && _blobUrl != null) {
          html.Url.revokeObjectUrl(_blobUrl!);
        }
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
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  Future<void> _logout() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
            (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Reel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt_rounded),
            tooltip: 'View All Reels',
            onPressed: () {
              if (mounted) {
                // Navigate to ViewReelsPage. Consider if pushReplacement or just push is better.
                // If this page is always accessed from ViewReelsPage, Navigator.pop(context) might be simpler.
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const ViewReelsPage()),
                );
              }
            },
          ),
          IconButton( // Logout button
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_initialised)
              AspectRatio(
                aspectRatio: _player.value.aspectRatio,
                child: VideoPlayer(_player),
              )
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.video_library_outlined,
                        size: 48, color: Colors.grey.shade500),
                    const SizedBox(height: 8),
                    const Text('No video selected',
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.video_library),
              label: const Text('Pick Video'),
              onPressed: _isUploading ? null : _pickVideo,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Caption',
                hintText: 'Enter your caption here...',
              ),
              enabled: !_isUploading,
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            if (_isUploading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _uploadProgress > 0 && _uploadProgress < 1
                          ? _uploadProgress
                          : null, // Indeterminate if 0 or 1
                      backgroundColor: Colors.grey.shade700,
                      valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                    ),
                    const SizedBox(height: 4),
                    Text(
                        'Uploading... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ElevatedButton.icon(
              icon: _isUploading
                  ? const SizedBox.shrink()
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(_isUploading ? 'PLEASE WAIT' : 'Upload Reel'),
              onPressed: (_videoFile == null && _videoBytes == null) ||
                  _isUploading
                  ? null
                  : _upload,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isUploading ? Colors.grey : Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}