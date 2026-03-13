import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:convert';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isSaving  = false;
  Uint8List? _imageBytes;
  String? _fotoUrl;
  String? _email;
  int _followersCount = 0;
  int _followingCount = 0;
  int _resepCount     = 0;

  static const Color primary      = Color(0xFFFF9900);
  static const Color brown        = Color(0xFF1A1A1A);
  static const Color bgColor      = Color(0xFFFAFAFA);
  static const Color cardColor    = Colors.white;
  static const Color surfaceColor = Color(0xFFEEEBE7);
  static const Color textColor    = Color(0xFF1A1A1A);
  static const Color mutedColor   = Color(0xFF999999);
  static const Color divColor     = Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      _nameController.text = data['nama'] ?? '';
      _email   = data['email'] ?? user.email ?? '';
      _fotoUrl = data['fotoUrl'];
    }
    final followers = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('followers').get();
    final following = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('following').get();
    final resep     = await FirebaseFirestore.instance.collection('resep').where('userId', isEqualTo: user.uid).get();
    if (mounted) {
      setState(() {
        _followersCount = followers.docs.length;
        _followingCount = following.docs.length;
        _resepCount     = resep.docs.length;
        _isLoading      = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _imageBytes = bytes);
    }
  }

  void _viewFullPhoto() {
    final hasPhoto = _imageBytes != null || (_fotoUrl != null && _fotoUrl!.isNotEmpty);
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
              child: _imageBytes != null
                  ? Image.memory(_imageBytes!, fit: BoxFit.contain)
                  : Image.network(_fotoUrl!, fit: BoxFit.contain,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : const SizedBox(width: 60, height: 60,
                              child: CircularProgressIndicator(color: primary))),
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

  Future<String?> _uploadToCloudinary(Uint8List imageBytes) async {
    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/dyo6a32zm/image/upload');
      final request = http.MultipartRequest('POST', uri);
      request.fields['upload_preset'] = 'boenda_kitchen';
      request.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: 'profile.jpg'));
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['secure_url'];
      }
      return null;
    } catch (e) { return null; }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnackbar('Nama tidak boleh kosong!', isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      String? newFotoUrl = _fotoUrl;
      if (_imageBytes != null) newFotoUrl = await _uploadToCloudinary(_imageBytes!);
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'nama': _nameController.text.trim(),
        'fotoUrl': ?newFotoUrl,
      });
      if (mounted) {
        setState(() => _fotoUrl = newFotoUrl);
        _showSnackbar('Profil berhasil diperbarui!', isError: false);
      }
    } catch (e) {
      _showSnackbar('Gagal menyimpan: ${e.toString()}', isError: true);
    }
    if (mounted) setState(() => _isSaving = false);
  }

  void _showSnackbar(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Profil Saya', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor, fontSize: 16)),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Header profil
                Container(
                  color: cardColor,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      GestureDetector(
                        onTap: _pickImage,
                        onLongPress: _viewFullPhoto,
                        child: Stack(children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundColor: const Color(0xFFF5F5F5),
                            backgroundImage: _imageBytes != null
                                ? MemoryImage(_imageBytes!)
                                : (_fotoUrl != null && _fotoUrl!.isNotEmpty ? NetworkImage(_fotoUrl!) as ImageProvider : null),
                            child: (_imageBytes == null && (_fotoUrl == null || _fotoUrl!.isEmpty))
                                ? const Icon(Icons.person, color: primary, size: 36) : null,
                          ),
                          Positioned(bottom: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: primary, shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt_rounded, color: brown, size: 13))),
                        ]),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_nameController.text.isNotEmpty ? _nameController.text : 'Nama belum diisi',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 2),
                        Text(_email ?? '', style: GoogleFonts.poppins(fontSize: 12, color: mutedColor)),
                        const SizedBox(height: 4),
                        Text('Tekan lama foto untuk melihat full',
                          style: GoogleFonts.poppins(fontSize: 10, color: Color(0xFFBBBBBB))),
                      ])),
                    ]),

                    const SizedBox(height: 20),

                    Row(children: [
                      _StatItem(count: _followersCount, label: 'Pengikut'),
                      _StatDivider(),
                      _StatItem(count: _followingCount, label: 'Mengikuti'),
                      _StatDivider(),
                      _StatItem(count: _resepCount, label: 'Resep'),
                    ]),
                  ]),
                ),

                const SizedBox(height: 12),

                Container(
                  color: cardColor,
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Edit Profil', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 20),

                    Text('Nama', style: GoogleFonts.poppins(fontSize: 13, color: mutedColor, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(10)),
                      child: TextField(
                        controller: _nameController,
                        style: GoogleFonts.poppins(fontSize: 14, color: textColor),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          suffixIcon: const Icon(Icons.edit_outlined, color: mutedColor, size: 18)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text('Email', style: GoogleFonts.poppins(fontSize: 13, color: mutedColor, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      child: Row(children: [
                        Expanded(child: Text(_email ?? '', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]))),
                        Icon(Icons.lock_outline_rounded, color: Colors.grey[400], size: 16),
                      ]),
                    ),

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary, foregroundColor: brown,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0),
                        child: _isSaving
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(color: brown, strokeWidth: 2))
                            : Text('Simpan Perubahan', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 40),
              ]),
            ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final int count;
  final String label;
  const _StatItem({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(children: [
      Text('$count', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A))),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF999999))),
    ]));
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: const Color(0xFFE0E0E0), margin: const EdgeInsets.symmetric(horizontal: 8));
  }
}