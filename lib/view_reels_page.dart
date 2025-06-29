// lib/view_reels_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ai_reels/create_reel_page.dart';
import 'package:ai_reels/auth_service.dart'; // Import AuthService
import 'package:ai_reels/login_page.dart'; // For navigation after logout

class ViewReelsPage extends StatefulWidget {
  const ViewReelsPage({super.key});

  @override
  State<ViewReelsPage> createState() => _ViewReelsPageState();
}

class _ViewReelsPageState extends State<ViewReelsPage> {
  final AuthService _authService = AuthService(); // Instantiate AuthService

  Future<void> _logout() async {
    await _authService.signOut();
    if (mounted) {
      // Navigate to login page and remove all previous routes
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
        title: const Text('View Reels'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout, // Call logout method
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reels')
        // You might want to filter reels by user ID here if they are user-specific
        // .where('uploaderId', isEqualTo: _authService.currentUser?.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            // Check if the current user has uploaded anything if filtering by uploaderId
            // String message = _authService.currentUser?.uid != null
            //     ? 'No reels found. Create one!'
            //     : 'Login to see or create reels.'; // Example message if not logged in (shouldn't happen here due to main.dart logic)
            return const Center(child: Text('No reels found. Create one!'));
          }
          final reels = snapshot.data!.docs;
          return ListView.builder(
            itemCount: reels.length,
            itemBuilder: (context, index) {
              final reelData = reels[index].data() as Map<String, dynamic>;
              final String caption = reelData['caption'] ?? 'No caption';
              final String videoUrl = reelData['videoUrl'] ?? '';
              return Card(
                margin:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caption,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Video URL: $videoUrl',
                        style:
                        TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            // Consider pushReplacement if you don't want view reels page in backstack from create page
            context,
            MaterialPageRoute(builder: (context) => const CreateReelPage()),
          );
        },
        tooltip: 'Create a new Reel',
        child: const Icon(Icons.add_a_photo_outlined),
      ),
    );
  }
}