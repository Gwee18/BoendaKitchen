import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'public_profile_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String resepId;
  final Map<String, dynamic> data;

  const RecipeDetailScreen({super.key, required this.resepId, required this.data});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isSaved = false;
  String? _myReaction;

  final List<Map<String, String>> _emojis = [
    {'emoji': '😋', 'label': 'Lezat'},
    {'emoji': '🔥', 'label': 'Keren'},
    {'emoji': '👍', 'label': 'Bagus'},
    {'emoji': '❤️', 'label': 'Favorit'},
    {'emoji': '😮', 'label': 'Wow'},
  ];

  @override
  void initState() {
    super.initState();
    if (user != null) {
      _checkSaved();
      _loadMyReaction();
    }
  }

  Future<void> _checkSaved() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('savedResep')
        .doc(widget.resepId)
        .get();
    if (mounted) setState(() => _isSaved = doc.exists);
  }

  Future<void> _loadMyReaction() async {
    final doc = await FirebaseFirestore.instance
        .collection('resep').doc(widget.resepId)
        .collection('reactions').doc(user!.uid).get();
    if (mounted && doc.exists) {
      setState(() => _myReaction = doc.data()?['emoji']);
    }
  }

  Future<void> _toggleSave() async {
    if (user == null) { _showLoginDialog(); return; }
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('savedResep')
        .doc(widget.resepId);
    if (_isSaved) {
      await ref.delete();
    } else {
      await ref.set({
        'resepId': widget.resepId,
        'savedAt': Timestamp.now(),
      });
    }
    setState(() => _isSaved = !_isSaved);
  }

  Future<void> _reactEmoji(String emoji, String label) async {
    if (user == null) { _showLoginDialog(); return; }
    final ref = FirebaseFirestore.instance
        .collection('resep').doc(widget.resepId)
        .collection('reactions').doc(user!.uid);
    final userDoc = await FirebaseFirestore.instance
        .collection('users').doc(user!.uid).get();
    final nama = userDoc.data()?['nama'] ?? 'Anonim';

    if (_myReaction == emoji) {
      await ref.delete();
      setState(() => _myReaction = null);
    } else {
      await ref.set({
        'userId': user!.uid,
        'nama': nama,
        'emoji': emoji,
        'label': label,
        'reactedAt': Timestamp.now(),
      });
      setState(() => _myReaction = emoji);
    }
  }

  void _showReactionsModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Tanggapan',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _emojis.map((e) {
                final isSelected = _myReaction == e['emoji'];
                return GestureDetector(
                  onTap: () {
                    _reactEmoji(e['emoji']!, e['label']!);
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFD4845A).withOpacity(0.15)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFD4845A) : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(e['emoji']!, style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 2),
                        Text(e['label']!,
                            style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text('Siapa yang bereaksi',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('resep').doc(widget.resepId)
                  .collection('reactions').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Belum ada tanggapan.',
                        style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
                  );
                }
                final reactions = snapshot.data!.docs;
                return Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: reactions.map((r) {
                    final rData = r.data() as Map<String, dynamic>;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8F3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFD4845A).withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(rData['emoji'] ?? '', style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 5),
                          Text(rData['nama'] ?? '',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Login Diperlukan',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Kamu harus login untuk melakukan ini.',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tutup', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildBahanList(String bahan) {
    final lines = bahan.split('\n').where((l) => l.trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFFD4845A).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 13, color: Color(0xFFD4845A)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(line.trim(),
                  style: GoogleFonts.poppins(fontSize: 14, height: 1.5)),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildLangkahList(String langkah) {
    final lines = langkah.split('\n').where((l) => l.trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines.length, (i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFD4845A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text('${i + 1}',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(lines[i].trim(),
                  style: GoogleFonts.poppins(fontSize: 14, height: 1.5)),
            ),
          ],
        ),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xFFD4845A),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: _isSaved ? Colors.amber : Colors.white,
                    size: 20,
                  ),
                ),
                onPressed: _toggleSave,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: data['fotoUrl'] != null && data['fotoUrl'].toString().isNotEmpty
                  ? Image.network(data['fotoUrl'], fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xFFF5F5F5),
                        child: const Icon(Icons.restaurant_rounded,
                            color: Color(0xFFD4845A), size: 80),
                      ))
                  : Container(
                      color: const Color(0xFFF5F5F5),
                      child: const Icon(Icons.restaurant_rounded,
                          color: Color(0xFFD4845A), size: 80),
                    ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['namaResep'] ?? '',
                      style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (data['userId'] != null && data['userId'].toString().isNotEmpty) {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => PublicProfileScreen(
                                userId: data['userId'],
                                nama: data['namaPembuat'] ?? '',
                              ),
                            ));
                          }
                        },
                        child: Row(
                          children: [
                            FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(data['userId'] ?? '')
                                  .get(),
                              builder: (context, snapshot) {
                                final userData = snapshot.data?.data() as Map<String, dynamic>?;
                                final fotoUrl = userData?['fotoUrl'] as String?;
                                return Container(
                                  width: 30, height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFD4845A), width: 1.5),
                                    image: fotoUrl != null && fotoUrl.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(fotoUrl),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                    color: const Color(0xFFF5F5F5),
                                  ),
                                  child: fotoUrl == null || fotoUrl.isEmpty
                                      ? const Icon(Icons.person, color: Color(0xFFD4845A), size: 16)
                                      : null,
                                );
                              },
                            ),
                            const SizedBox(width: 6),
                            Text(
                              data['namaPembuat'] ?? '',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFFD4845A),
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8F3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFFD4845A)),
                            const SizedBox(width: 4),
                            Text(data['waktuMasak'] ?? '',
                                style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFD4845A))),
                          ],
                        ),
                      ),

                      const Spacer(),

                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('resep').doc(widget.resepId)
                            .collection('reactions').snapshots(),
                        builder: (context, snapshot) {
                          final count = snapshot.data?.docs.length ?? 0;
                          return GestureDetector(
                            onTap: _showReactionsModal,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _myReaction != null
                                    ? const Color(0xFFD4845A).withOpacity(0.1)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _myReaction != null
                                      ? const Color(0xFFD4845A).withOpacity(0.3)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    _myReaction ?? '😊',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  if (count > 0) ...[
                                    const SizedBox(width: 4),
                                    Text('$count',
                                        style: GoogleFonts.poppins(
                                            fontSize: 12, color: Colors.grey[600])),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4845A).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.kitchen_outlined,
                            color: Color(0xFFD4845A), size: 18),
                      ),
                      const SizedBox(width: 8),
                      Text('Bahan-bahan',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildBahanList(data['bahan'] ?? ''),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4845A).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.format_list_numbered_rounded,
                            color: Color(0xFFD4845A), size: 18),
                      ),
                      const SizedBox(width: 8),
                      Text('Langkah Memasak',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildLangkahList(data['langkah'] ?? ''),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}