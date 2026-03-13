import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'recipe_detail_screen.dart';
import 'add_recipe_screen.dart';

class MyRecipesScreen extends StatelessWidget {
  const MyRecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFD4845A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Resep Saya',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('resep')
            .where('userId', isEqualTo: user!.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFD4845A)));
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('Belum ada resep', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Mulai tambahkan resep pertamamu!',
                      style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: data['fotoUrl'] != null && data['fotoUrl'].toString().isNotEmpty
                        ? Image.network(data['fotoUrl'],
                            width: 60, height: 60, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _placeholder())
                        : _placeholder(),
                  ),
                  title: Text(data['namaResep'] ?? '',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFFD4845A)),
                          const SizedBox(width: 4),
                          Text(data['waktuMasak'] ?? '',
                              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                          const SizedBox(width: 12),
                          const Icon(Icons.favorite_rounded, size: 12, color: Colors.redAccent),
                          const SizedBox(width: 4),
                          Text('${data['likes'] ?? 0}',
                              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        child: Row(
                          children: [
                            const Icon(Icons.visibility_outlined, color: Color(0xFFD4845A), size: 18),
                            const SizedBox(width: 8),
                            Text('Lihat', style: GoogleFonts.poppins(fontSize: 13)),
                          ],
                        ),
                        onTap: () => Future.delayed(Duration.zero, () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => RecipeDetailScreen(resepId: docId, data: data)))),
                      ),
                      PopupMenuItem(
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined, color: Colors.orange, size: 18),
                            const SizedBox(width: 8),
                            Text('Edit', style: GoogleFonts.poppins(fontSize: 13)),
                          ],
                        ),
                        onTap: () => Future.delayed(Duration.zero, () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => AddRecipeScreen(resepId: docId, existingData: data)))),
                      ),
                      PopupMenuItem(
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                            const SizedBox(width: 8),
                            Text('Hapus', style: GoogleFonts.poppins(fontSize: 13, color: Colors.redAccent)),
                          ],
                        ),
                        onTap: () => Future.delayed(Duration.zero, () => _confirmDelete(context, docId)),
                      ),
                    ],
                  ),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => RecipeDetailScreen(resepId: docId, data: data))),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFD4845A),
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddRecipeScreen())),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Tambah Resep',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 60,
      height: 60,
      color: const Color(0xFFF5F5F5),
      child: const Icon(Icons.restaurant_rounded, color: Color(0xFFD4845A), size: 28),
    );
  }

  void _confirmDelete(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Resep', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Yakin ingin menghapus resep ini?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('resep').doc(docId).delete();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Hapus', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}