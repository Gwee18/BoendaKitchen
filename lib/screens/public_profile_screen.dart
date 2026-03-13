import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'recipe_detail_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  final String nama;
  const PublicProfileScreen({super.key, required this.userId, required this.nama});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  bool _isFollowing    = false;
  int  _followersCount = 0;
  int  _followingCount = 0;
  String? _fotoUrl;

  static const Color primary = Color(0xFFFF9900);
  static const Color brown   = Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
    if (mounted) setState(() => _fotoUrl = userDoc.data()?['fotoUrl'] as String?);

    if (currentUser != null) {
      final doc = await FirebaseFirestore.instance.collection('users')
          .doc(widget.userId).collection('followers').doc(currentUser!.uid).get();
      if (mounted) setState(() => _isFollowing = doc.exists);
    }

    final followers = await FirebaseFirestore.instance.collection('users').doc(widget.userId).collection('followers').count().get();
    final following = await FirebaseFirestore.instance.collection('users').doc(widget.userId).collection('following').count().get();
    if (mounted) {
      setState(() {
        _followersCount = followers.count ?? 0;
        _followingCount = following.count ?? 0;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (currentUser == null) return;
    final followersRef = FirebaseFirestore.instance.collection('users').doc(widget.userId).collection('followers').doc(currentUser!.uid);
    final followingRef = FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('following').doc(widget.userId);
    if (_isFollowing) {
      await followersRef.delete();
      await followingRef.delete();
      if (mounted) setState(() { _isFollowing = false; _followersCount--; });
    } else {
      final currentUserDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      final currentNama = currentUserDoc.data()?['nama'] ?? 'Anonim';
      await followersRef.set({'userId': currentUser!.uid, 'nama': currentNama, 'followedAt': Timestamp.now()});
      await followingRef.set({'userId': widget.userId, 'nama': widget.nama, 'followedAt': Timestamp.now()});
      if (mounted) setState(() { _isFollowing = true; _followersCount++; });
    }
  }

  void _viewFullPhoto() {
    final hasPhoto = _fotoUrl != null && _fotoUrl!.isNotEmpty;
    if (!hasPhoto) return;
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                _fotoUrl!,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const SizedBox(
                        width: 60, height: 60,
                        child: CircularProgressIndicator(color: primary)),
              ),
            ),
          ),
          Positioned(top: 0, right: 0,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor     = const Color(0xFFFAFAFA);
    final cardColor   = Colors.white;
    final textColor   = const Color(0xFF1A1A1A);
    final mutedColor  = const Color(0xFF999999);
    final divColor    = const Color(0xFFE0E0E0);
    final isOwnProfile = currentUser?.uid == widget.userId;

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: cardColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded, color: textColor, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(widget.nama, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor, fontSize: 16)),
          centerTitle: false,
        ),

        SliverToBoxAdapter(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header profil
            Container(
              color: bgColor,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  GestureDetector(
                    onLongPress: _viewFullPhoto,
                    child: CircleAvatar(
                      radius: 34,
                      backgroundColor: const Color(0xFFFAFAFA),
                      backgroundImage: (_fotoUrl != null && _fotoUrl!.isNotEmpty) ? NetworkImage(_fotoUrl!) : null,
                      child: (_fotoUrl == null || _fotoUrl!.isEmpty) ? const Icon(Icons.person, color: primary, size: 36) : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.nama, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                  ])),
                ]),

                const SizedBox(height: 20),

                // Stats
                Row(children: [
                  _StatItem(count: _followersCount, label: 'Pengikut', textColor: textColor, mutedColor: mutedColor),
                  _StatDivider(color: divColor),
                  _StatItem(count: _followingCount, label: 'Mengikuti', textColor: textColor, mutedColor: mutedColor),
                  _StatDivider(color: divColor),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('resep').where('userId', isEqualTo: widget.userId).snapshots(),
                    builder: (_, snap) => _StatItem(
                      count: snap.data?.docs.length ?? 0, label: 'Resep',
                      textColor: textColor, mutedColor: mutedColor),
                  ),
                ]),

                const SizedBox(height: 20),

                // Tombol Ikuti / Berhenti Mengikuti
                if (!isOwnProfile && currentUser != null)
                  SizedBox(
                    width: double.infinity, height: 46,
                    child: _isFollowing
                        ? OutlinedButton(
                            onPressed: _toggleFollow,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: mutedColor,
                              side: const BorderSide(color: Color(0xFFCCCCCC)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text('Berhenti Mengikuti',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: mutedColor)),
                          )
                        : ElevatedButton(
                            onPressed: _toggleFollow,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text('Ikuti',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                          ),
                  ),
              ]),
            ),

            const SizedBox(height: 12),

            Container(color: bgColor, padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Resep', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: textColor))),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('resep')
                  .where('userId', isEqualTo: widget.userId).orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator(color: primary)));
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Padding(padding: const EdgeInsets.all(32),
                  child: Center(child: Column(children: [
                    Icon(Icons.restaurant_outlined, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text('Belum ada resep', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14)),
                  ])));
                }

                return Container(
                  color: cardColor,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.78),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final fotoUrl     = data['fotoUrl']?.toString() ?? '';
                      final namaResep   = data['namaResep']?.toString() ?? '';
                      final namaPembuat = data['namaPembuat']?.toString() ?? '';
                      return GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => RecipeDetailScreen(resepId: docs[index].id, data: data))),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                child: fotoUrl.isNotEmpty
                                    ? Image.network(fotoUrl, width: double.infinity, fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => _placeholder())
                                    : _placeholder(),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(namaResep, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(namaPembuat, style: GoogleFonts.poppins(fontSize: 10, color: mutedColor), overflow: TextOverflow.ellipsis),
                              ]),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
          ]),
        ),
      ]),
    );
  }

  Widget _placeholder() => Container(color: const Color(0xFFF5F5F5),
    child: const Center(child: Icon(Icons.restaurant_rounded, color: primary, size: 32)));
}

class _StatItem extends StatelessWidget {
  final int count;
  final String label;
  final Color textColor;
  final Color mutedColor;
  const _StatItem({required this.count, required this.label, required this.textColor, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(children: [
      Text('$count', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.poppins(fontSize: 12, color: mutedColor)),
    ]));
  }
}

class _StatDivider extends StatelessWidget {
  final Color color;
  const _StatDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: color, margin: const EdgeInsets.symmetric(horizontal: 8));
  }
}