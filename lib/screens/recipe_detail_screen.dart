import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isLiked = false;
  int _likeCount = 0;

  final _komentarController = TextEditingController();
  bool _isSendingKomentar = false;
  bool _showAllKomentar = false;
  static const int _komentarPreview = 5;

  static const Color primary    = Color(0xFFFF9900);
  static const Color brown      = Color(0xFF1A1A1A);
  static const Color bgColor    = Color(0xFFFAFAFA);
  static const Color textColor  = Color(0xFF1A1A1A);
  static const Color mutedColor = Color(0xFF888888);

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
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    if (user != null) {
      _checkSaved();
      _loadMyReaction();
      _saveLastViewed();
      _checkLike();
    }
  }

  @override
  void dispose() {
    _komentarController.dispose();
    super.dispose();
  }

  Future<void> _saveLastViewed() async {
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users').doc(user!.uid)
          .collection('lastViewed').doc(widget.resepId)
          .set({
        'resepId':     widget.resepId,
        'namaResep':   widget.data['namaResep'] ?? '',
        'namaPembuat': widget.data['namaPembuat'] ?? '',
        'fotoUrl':     widget.data['fotoUrl'] ?? '',
        'viewedAt':    Timestamp.now(),
      });
    } catch (_) {}
  }

  Future<void> _checkSaved() async {
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(user!.uid)
        .collection('savedResep').doc(widget.resepId).get();
    if (mounted) setState(() => _isSaved = doc.exists);
  }

  Future<void> _checkLike() async {
    final doc = await FirebaseFirestore.instance
        .collection('resep').doc(widget.resepId)
        .collection('likes').doc(user!.uid).get();
    final resepDoc = await FirebaseFirestore.instance
        .collection('resep').doc(widget.resepId).get();
    if (mounted) {
      setState(() {
        _isLiked = doc.exists;
        _likeCount = (resepDoc.data()?['likes'] ?? 0) as int;
      });
    }
  }

  Future<void> _toggleLike() async {
    if (user == null) { _showLoginDialog(); return; }
    final likeRef = FirebaseFirestore.instance
        .collection('resep').doc(widget.resepId)
        .collection('likes').doc(user!.uid);
    final resepRef = FirebaseFirestore.instance
        .collection('resep').doc(widget.resepId);
    if (_isLiked) {
      await likeRef.delete();
      await resepRef.update({'likes': FieldValue.increment(-1)});
      if (mounted) setState(() { _isLiked = false; _likeCount--; });
    } else {
      await likeRef.set({'userId': user!.uid, 'likedAt': Timestamp.now()});
      await resepRef.update({'likes': FieldValue.increment(1)});
      if (mounted) setState(() { _isLiked = true; _likeCount++; });
    }
  }

  Future<void> _loadMyReaction() async {
    final doc = await FirebaseFirestore.instance
        .collection('resep').doc(widget.resepId)
        .collection('reactions').doc(user!.uid).get();
    if (mounted && doc.exists) setState(() => _myReaction = doc.data()?['emoji']);
  }

  Future<void> _toggleSave() async {
    if (user == null) { _showLoginDialog(); return; }
    final ref = FirebaseFirestore.instance
        .collection('users').doc(user!.uid)
        .collection('savedResep').doc(widget.resepId);
    if (_isSaved) {
      await ref.delete();
    } else {
      await ref.set({'resepId': widget.resepId, 'savedAt': Timestamp.now()});
    }
    if (mounted) setState(() => _isSaved = !_isSaved);
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
      if (mounted) setState(() => _myReaction = null);
    } else {
      await ref.set({
        'userId': user!.uid, 'nama': nama,
        'emoji': emoji, 'label': label,
        'reactedAt': Timestamp.now()
      });
      if (mounted) setState(() => _myReaction = emoji);
    }
  }

  Future<void> _kirimKomentar() async {
    if (user == null) { _showLoginDialog(); return; }
    final isi = _komentarController.text.trim();
    if (isi.isEmpty) return;
    setState(() => _isSendingKomentar = true);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(user!.uid).get();
      final nama    = userDoc.data()?['nama'] ?? 'Anonim';
      final fotoUrl = userDoc.data()?['fotoUrl'] ?? '';
      await FirebaseFirestore.instance
          .collection('resep').doc(widget.resepId)
          .collection('komentar').add({
        'userId':    user!.uid,
        'nama':      nama,
        'fotoUrl':   fotoUrl,
        'isi':       isi,
        'createdAt': Timestamp.now(),
      });
      _komentarController.clear();
      // Kalau kirim komentar baru, tampilkan semua supaya komentar sendiri kelihatan
      if (mounted) setState(() => _showAllKomentar = true);

      // Kirim notifikasi ke pemilik resep (kalau bukan diri sendiri)
      final resepOwnerId = widget.data['userId']?.toString() ?? '';
      if (resepOwnerId.isNotEmpty && resepOwnerId != user!.uid) {
        final namaResep = widget.data['namaResep']?.toString() ?? 'resep';
        final preview   = isi.length > 50 ? '${isi.substring(0, 50)}...' : isi;
        await FirebaseFirestore.instance
            .collection('users').doc(resepOwnerId)
            .collection('notifikasi').add({
          'tipe':       'komentar',
          'dari':       nama,
          'fromUserId': user!.uid,
          'resepId':    widget.resepId,
          'namaResep':  namaResep,
          'fotoResep':  widget.data['fotoUrl']?.toString() ?? '',
          'preview':    preview,
          'isRead':     false,
          'createdAt':  Timestamp.now(),
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isSendingKomentar = false);
  }

  Future<void> _hapusKomentar(String komentarId) async {
    await FirebaseFirestore.instance
        .collection('resep').doc(widget.resepId)
        .collection('komentar').doc(komentarId).delete();
  }

  void _konfirmasiHapusKomentar(String komentarId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Komentar?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Komentar ini akan dihapus permanen.', style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.poppins(color: Colors.grey))),
          TextButton(
            onPressed: () { Navigator.pop(context); _hapusKomentar(komentarId); },
            child: Text('Hapus', style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _bukaProfilKomentar(String userId, String nama) {
    if (user == null) { _showLoginDialog(); return; }
    // Jangan buka profil sendiri
    if (userId == user!.uid) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PublicProfileScreen(userId: userId, nama: nama)));
  }

  String _formatWaktu(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1)  return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24)   return '${diff.inHours}j';
    if (diff.inDays < 7)     return '${diff.inDays}h';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _showReactionsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (context, _) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('resep').doc(widget.resepId)
                  .collection('reactions').snapshots(),
              builder: (context, snapshot) {
                final reactions = snapshot.data?.docs ?? [];
                final Map<String, int> counts = {};
                for (final r in reactions) {
                  final e = (r.data() as Map<String, dynamic>)['emoji'] as String?;
                  if (e != null) counts[e] = (counts[e] ?? 0) + 1;
                }
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('Semua  ', style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 14, color: brown,
                        decoration: TextDecoration.underline,
                        decorationColor: primary, decorationThickness: 2)),
                    ...counts.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Row(children: [
                        Text(e.key, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        Text('${e.value}', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey)),
                      ]))),
                  ]),
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey[200]),
                  const SizedBox(height: 16),
                  if (reactions.isEmpty)
                    Center(child: Text('Belum ada tanggapan.',
                        style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)))
                  else
                    ...reactions.map((r) {
                      final rData = r.data() as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(children: [
                          CircleAvatar(radius: 20, backgroundColor: const Color(0xFFF5F5F5),
                            child: Text(rData['emoji'] ?? '😊', style: const TextStyle(fontSize: 18))),
                          const SizedBox(width: 12),
                          Expanded(child: Text(rData['nama'] ?? 'Anonim',
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: textColor))),
                        ]),
                      );
                    }),
                ]);
              },
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.grey[200]),
            const SizedBox(height: 16),
            Text('Beri tanggapan',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _emojis.map((e) {
                final isSelected = _myReaction == e['emoji'];
                return GestureDetector(
                  onTap: () { _reactEmoji(e['emoji']!, e['label']!); Navigator.pop(context); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? primary.withOpacity(0.15) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isSelected ? primary : Colors.transparent, width: 1.5)),
                    child: Column(children: [
                      Text(e['emoji']!, style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 2),
                      Text(e['label']!, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ]),
        ),
      ),
    );
  }

  void _showLoginDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Login Diperlukan', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      content: Text('Kamu harus login untuk melakukan ini.', style: GoogleFonts.poppins()),
      actions: [TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Tutup', style: GoogleFonts.poppins(color: Colors.grey)))],
    ));
  }

  Widget _buildBahanList(String bahan) {
    final lines = bahan.split('\n').where((l) => l.trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(lines.length, (i) => Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(lines[i].trim(),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 14, color: textColor, height: 1.4)),
        ),
        _DashedDivider(),
      ])),
    );
  }

  Widget _buildLangkahList(String langkah) {
    final lines = langkah.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final langkahFoto = (widget.data['langkahFoto'] as List<dynamic>?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines.length, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 28, height: 28,
            decoration: const BoxDecoration(color: textColor, shape: BoxShape.circle),
            child: Center(child: Text('${i + 1}',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(lines[i].trim(),
                style: GoogleFonts.poppins(fontSize: 14, color: textColor, height: 1.5))),
            if (i < langkahFoto.length && langkahFoto[i].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(langkahFoto[i].toString(),
                  width: 100, height: 100, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ],
          ])),
        ]))));
  }

  Widget _buildKomentarSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('resep').doc(widget.resepId)
          .collection('komentar')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        final allDocs = snapshot.data?.docs ?? [];
        final total   = allDocs.length;
        final tampil  = _showAllKomentar ? allDocs : allDocs.take(_komentarPreview).toList();
        final sisanya = total - _komentarPreview;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Text('Komentar',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20)),
              child: Text('$total',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: primary)),
            ),
          ]),
          const SizedBox(height: 16),

          // Kosong
          if (allDocs.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 40, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text('Belum ada komentar.\nJadi yang pertama!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey, height: 1.5)),
                ]),
              ),
            )
          else ...[
            // List komentar
            ...tampil.map((doc) => _buildKomentarItem(doc)),

            // Tombol lihat semua / sembunyikan
            if (total > _komentarPreview)
              GestureDetector(
                onTap: () => setState(() => _showAllKomentar = !_showAllKomentar),
                child: Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(
                      _showAllKomentar
                          ? 'Sembunyikan komentar'
                          : 'Lihat $sisanya komentar lainnya',
                      style: GoogleFonts.poppins(
                        fontSize: 13, color: primary, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    Icon(
                      _showAllKomentar
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: primary, size: 18),
                  ]),
                ),
              ),
          ],
        ]);
      },
    );
  }

  Widget _buildKomentarItem(QueryDocumentSnapshot doc) {
    final d        = doc.data() as Map<String, dynamic>;
    final isOwn    = d['userId'] == user?.uid;
    final userId   = d['userId']?.toString() ?? '';
    final fotoUrl  = d['fotoUrl']?.toString() ?? '';
    final isi      = d['isi']?.toString() ?? '';
    final namaUser = d['nama']?.toString() ?? 'Anonim';
    final createdAt = d['createdAt'] as Timestamp?;
    final waktu    = createdAt != null ? _formatWaktu(createdAt.toDate()) : '';

    return GestureDetector(
      onLongPress: isOwn ? () => _konfirmasiHapusKomentar(doc.id) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Avatar — klik ke profil
          GestureDetector(
            onTap: () => _bukaProfilKomentar(userId, namaUser),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFF0F0F0),
              backgroundImage: fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
              child: fotoUrl.isEmpty
                  ? Text(namaUser.isNotEmpty ? namaUser[0].toUpperCase() : '?',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: primary))
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              // Nama — klik ke profil
              GestureDetector(
                onTap: () => _bukaProfilKomentar(userId, namaUser),
                child: Text(namaUser,
                  style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600, color: textColor,
                    decoration: isOwn ? TextDecoration.none : TextDecoration.none)),
              ),
              const SizedBox(width: 6),
              Text(waktu, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
              if (isOwn) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4)),
                  child: Text('Kamu',
                    style: GoogleFonts.poppins(fontSize: 10, color: primary, fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isOwn ? primary.withOpacity(0.08) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: isOwn ? const Radius.circular(12) : Radius.zero,
                  topRight: const Radius.circular(12),
                  bottomLeft: const Radius.circular(12),
                  bottomRight: const Radius.circular(12),
                ),
                border: Border.all(
                  color: isOwn ? primary.withOpacity(0.2) : Colors.grey.withOpacity(0.15))),
              child: Text(isi,
                style: GoogleFonts.poppins(fontSize: 13, color: textColor, height: 1.4)),
            ),
            if (isOwn)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Tekan lama untuk hapus',
                  style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[400])),
              ),
          ])),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final divColor    = Colors.grey[200]!;
    final data        = widget.data;
    final fotoUrl     = data['fotoUrl']?.toString() ?? '';
    final deskripsi   = data['deskripsi']?.toString() ?? '';
    final isOwnRecipe = user != null && user!.uid == (data['userId']?.toString() ?? '');

    return Scaffold(
      backgroundColor: bgColor,
      bottomNavigationBar: isOwnRecipe
          ? Container(
              color: Colors.white,
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.lock_outline_rounded, color: mutedColor, size: 14),
                const SizedBox(width: 6),
                Text('Kamu tidak bisa mengomentari resepmu sendiri',
                    style: GoogleFonts.poppins(fontSize: 12, color: mutedColor)),
              ]))
          : Container(
              color: Colors.white,
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 10,
                bottom: MediaQuery.of(context).viewInsets.bottom + 10),
              child: Row(children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFF0F0F0),
                  child: const Icon(Icons.person, color: primary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(24)),
                    child: TextField(
                      controller: _komentarController,
                      style: GoogleFonts.poppins(fontSize: 13, color: textColor),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onTap: () {
                        if (user == null) {
                          _showLoginDialog();
                          _komentarController.clear();
                        }
                      },
                      decoration: InputDecoration(
                        hintText: user != null ? 'Tulis komentar...' : 'Login untuk berkomentar',
                        hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isSendingKomentar ? null : _kirimKomentar,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: primary, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                        color: primary.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]),
                    child: _isSendingKomentar
                        ? const Padding(padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ]),
            ),

      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: _CircleIcon(icon: Icons.arrow_back_ios_rounded, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: _CircleIcon(
                icon: _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: _isSaved ? primary : Colors.white),
              onPressed: _toggleSave,
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: fotoUrl.isNotEmpty
                ? Image.network(fotoUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _photoPlaceholder())
                : _photoPlaceholder(),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              Text(data['namaResep'] ?? '',
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),

              if (deskripsi.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(deskripsi,
                  style: GoogleFonts.poppins(fontSize: 14, color: mutedColor, height: 1.6)),
              ],

              const SizedBox(height: 16),

              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users').doc(data['userId'] ?? '').get(),
                builder: (context, snapshot) {
                  final uData = snapshot.data?.data() as Map<String, dynamic>?;
                  final foto  = uData?['fotoUrl'] as String?;
                  return GestureDetector(
                    onTap: () {
                      if (user == null) { _showLoginDialog(); return; }
                      if (data['userId'] != null) {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => PublicProfileScreen(
                              userId: data['userId'], nama: data['namaPembuat'] ?? '')));
                      }
                    },
                    child: Row(children: [
                      CircleAvatar(radius: 18, backgroundColor: const Color(0xFFF5F5F5),
                        backgroundImage: (foto != null && foto.isNotEmpty) ? NetworkImage(foto) : null,
                        child: (foto == null || foto.isEmpty)
                            ? const Icon(Icons.person, color: primary, size: 18) : null),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(data['namaPembuat'] ?? '',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                        if (data['waktuMasak'] != null)
                          Row(children: [
                            const Icon(Icons.access_time_rounded, size: 11, color: mutedColor),
                            const SizedBox(width: 3),
                            Text(data['waktuMasak'],
                              style: GoogleFonts.poppins(fontSize: 11, color: mutedColor)),
                          ]),
                      ])),
                    ]),
                  );
                },
              ),

              const SizedBox(height: 20),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('resep').doc(widget.resepId)
                    .collection('reactions').snapshots(),
                builder: (context, snapshot) {
                  final reactions = snapshot.data?.docs ?? [];
                  final Map<String, int> counts = {};
                  for (final r in reactions) {
                    final e = (r.data() as Map<String, dynamic>)['emoji'] as String?;
                    if (e != null) counts[e] = (counts[e] ?? 0) + 1;
                  }
                  if (counts.isEmpty && _myReaction == null) return const SizedBox.shrink();
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 8, children: counts.entries.map((e) => GestureDetector(
                      onTap: _showReactionsModal,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _myReaction == e.key ? primary.withOpacity(0.15) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _myReaction == e.key ? primary : Colors.transparent)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(e.key, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          Text('${e.value}',
                            style: GoogleFonts.poppins(fontSize: 12, color: mutedColor)),
                        ])),
                    )).toList()),
                    const SizedBox(height: 8),
                  ]);
                },
              ),

              const SizedBox(height: 4),

              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showReactionsModal,
                    icon: Text(_myReaction ?? '😊', style: const TextStyle(fontSize: 16)),
                    label: Text(_myReaction != null ? 'Tanggapanmu' : 'Beri Tanggapan',
                      style: GoogleFonts.poppins(fontSize: 13, color: textColor)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: divColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _toggleLike,
                  icon: Icon(
                    _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: _isLiked ? Colors.redAccent : textColor, size: 18),
                  label: Text('$_likeCount',
                    style: GoogleFonts.poppins(fontSize: 13, color: textColor)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _isLiked ? Colors.redAccent : divColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14)),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _toggleSave,
                  icon: Icon(
                    _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: _isSaved ? primary : textColor, size: 18),
                  label: Text(_isSaved ? 'Tersimpan' : 'Simpan',
                    style: GoogleFonts.poppins(fontSize: 13, color: textColor)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _isSaved ? primary : divColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14)),
                ),
              ]),

              const SizedBox(height: 24),
              Divider(color: divColor, height: 1),
              const SizedBox(height: 24),

              Text('Bahan-bahan',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 4),
              _buildBahanList(data['bahan'] ?? ''),

              const SizedBox(height: 24),
              Divider(color: divColor, height: 1),
              const SizedBox(height: 24),

              Text('Langkah',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 16),
              _buildLangkahList(data['langkah'] ?? ''),

              const SizedBox(height: 24),
              Divider(color: divColor, height: 1),
              const SizedBox(height: 24),

              _buildKomentarSection(),

              const SizedBox(height: 32),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _photoPlaceholder() => Container(
    color: const Color(0xFFF5F5F5),
    child: const Center(child: Icon(Icons.restaurant_rounded, color: primary, size: 80)));
}

class _DashedDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const dashWidth = 6.0;
      const dashSpace = 4.0;
      final count = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
      return Row(children: List.generate(count, (_) => Padding(
        padding: const EdgeInsets.only(right: dashSpace),
        child: Container(width: dashWidth, height: 1, color: Colors.grey[300]))));
    });
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const _CircleIcon({required this.icon, this.color = Colors.white, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: size));
  }
}