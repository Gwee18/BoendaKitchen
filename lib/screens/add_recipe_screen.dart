import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:convert';

class AddRecipeScreen extends StatefulWidget {
  final String? resepId;
  final Map<String, dynamic>? existingData;
  const AddRecipeScreen({super.key, this.resepId, this.existingData});

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final _namaResepController   = TextEditingController();
  final _deskripsiController   = TextEditingController();
  final _waktuAngkaController  = TextEditingController();
  String _waktuSatuan = 'menit';
  bool _isLoading = false;
  Uint8List? _imageBytes;
  String? _existingImageUrl;

  final List<TextEditingController> _bahanControllers = [TextEditingController()];
  final List<TextEditingController> _langkahControllers = [TextEditingController()];
  final List<Uint8List?> _langkahImageBytes = [null];
  final List<String?> _langkahImageUrls = [null];

  static const Color primary      = Color(0xFFFF9900);
  static const Color bgColor      = Color(0xFFFAFAFA);
  static const Color surfaceColor = Color(0xFFEEEBE7);
  static const Color textColor    = Color(0xFF1A1A1A);
  static const Color mutedColor   = Color(0xFF999999);

  bool get _isEditing => widget.resepId != null;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    if (_isEditing && widget.existingData != null) {
      final data = widget.existingData!;
      _namaResepController.text = data['namaResep'] ?? '';
      _deskripsiController.text = data['deskripsi'] ?? '';
      _existingImageUrl = data['fotoUrl'];
      final bahanLines = (data['bahan'] ?? '').toString().split('\n').where((l) => l.toString().trim().isNotEmpty).toList();
      if (bahanLines.isNotEmpty) {
        _bahanControllers.clear();
        for (final b in bahanLines) {
          _bahanControllers.add(TextEditingController(text: b));
        }
      }
      final langkahLines = (data['langkah'] ?? '').toString().split('\n').where((l) => l.toString().trim().isNotEmpty).toList();
      if (langkahLines.isNotEmpty) {
        _langkahControllers.clear();
        _langkahImageBytes.clear();
        _langkahImageUrls.clear();
        for (final l in langkahLines) {
          _langkahControllers.add(TextEditingController(text: l));
          _langkahImageBytes.add(null);
          _langkahImageUrls.add(null);
        }
      }
      final langkahFoto = data['langkahFoto'] as List<dynamic>?;
      if (langkahFoto != null) {
        for (int i = 0; i < _langkahImageUrls.length && i < langkahFoto.length; i++) {
          _langkahImageUrls[i] = langkahFoto[i]?.toString();
        }
      }
      final waktu = data['waktuMasak'] ?? '';
      final parts = waktu.split(' ');
      if (parts.length >= 2) {
        _waktuAngkaController.text = parts[0];
        _waktuSatuan = parts[1];
      } else {
        _waktuAngkaController.text = waktu;
      }
    }
  }

  @override
  void dispose() {
    _namaResepController.dispose();
    _deskripsiController.dispose();
    _waktuAngkaController.dispose();
    for (final c in _bahanControllers) {
      c.dispose();
    }
    for (final c in _langkahControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _imageBytes = bytes);
    }
  }

  Future<void> _pickLangkahImage(int index) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _langkahImageBytes[index] = bytes);
    }
  }

  Future<String?> _uploadToCloudinary(Uint8List imageBytes, {String filename = 'upload.jpg'}) async {
    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/dyo6a32zm/image/upload');
      final request = http.MultipartRequest('POST', uri);
      request.fields['upload_preset'] = 'boenda_kitchen';
      request.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: filename));
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['secure_url'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _simpanResep() async {
    final nama        = _namaResepController.text.trim();
    final deskripsi   = _deskripsiController.text.trim();
    final bahan       = _bahanControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).join('\n');
    final langkahTeks = _langkahControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).join('\n');
    final waktuAngka  = _waktuAngkaController.text.trim();
    if (nama.isEmpty || bahan.isEmpty || langkahTeks.isEmpty || waktuAngka.isEmpty) {
      _showSnackbar('Harap isi semua field!', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      String? fotoUrl = _existingImageUrl;
      if (_imageBytes != null) fotoUrl = await _uploadToCloudinary(_imageBytes!);

      final List<String> langkahFotoUrls = [];
      for (int i = 0; i < _langkahControllers.length; i++) {
        if (_langkahImageBytes[i] != null) {
          final url = await _uploadToCloudinary(_langkahImageBytes[i]!, filename: 'langkah_$i.jpg');
          langkahFotoUrls.add(url ?? '');
        } else {
          langkahFotoUrls.add(_langkahImageUrls[i] ?? '');
        }
      }

      final waktuMasak = '$waktuAngka $_waktuSatuan';
      if (_isEditing) {
        await FirebaseFirestore.instance.collection('resep').doc(widget.resepId).update({
          'namaResep': nama,
          'deskripsi': deskripsi,
          'bahan': bahan,
          'langkah': langkahTeks,
          'waktuMasak': waktuMasak,
          'fotoUrl': fotoUrl ?? '',
          'langkahFoto': langkahFotoUrls,
          'updatedAt': Timestamp.now(),
        });
      } else {
        final user = FirebaseAuth.instance.currentUser;
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
        final namaPembuat = userDoc.data()?['nama'] ?? 'Anonim';
        await FirebaseFirestore.instance.collection('resep').add({
          'namaResep': nama,
          'deskripsi': deskripsi,
          'bahan': bahan,
          'langkah': langkahTeks,
          'waktuMasak': waktuMasak,
          'fotoUrl': fotoUrl ?? '',
          'langkahFoto': langkahFotoUrls,
          'namaPembuat': namaPembuat,
          'userId': user.uid,
          'likes': 0,
          'createdAt': Timestamp.now(),
        });
      }
      if (mounted) {
        _showSnackbar(_isEditing ? 'Resep berhasil diperbarui!' : 'Resep berhasil diterbitkan!', isError: false);
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackbar('Gagal: ${e.toString()}', isError: true);
    }
    if (mounted) setState(() => _isLoading = false);
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

  Widget _bahanItem(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(8)),
            child: TextField(
              controller: _bahanControllers[index],
              style: GoogleFonts.poppins(fontSize: 14, color: textColor),
              decoration: InputDecoration(
                hintText: 'Contoh: ½ ekor ayam',
                hintStyle: GoogleFonts.poppins(fontSize: 13, color: mutedColor),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
            ),
          ),
        ),
        if (_bahanControllers.length > 1)
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent.withOpacity(0.7), size: 20),
            onPressed: () => setState(() {
              _bahanControllers[index].dispose();
              _bahanControllers.removeAt(index);
            }),
          )
        else
          const SizedBox(width: 40),
      ]),
    );
  }

  Widget _langkahItem(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28, height: 28,
          margin: const EdgeInsets.only(top: 10),
          decoration: const BoxDecoration(color: textColor, shape: BoxShape.circle),
          child: Center(child: Text('${index + 1}',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(8)),
              child: TextField(
                controller: _langkahControllers[index],
                maxLines: 3, minLines: 1,
                style: GoogleFonts.poppins(fontSize: 14, color: textColor),
                decoration: InputDecoration(
                  hintText: 'Contoh: Panaskan minyak di wajan...',
                  hintStyle: GoogleFonts.poppins(fontSize: 13, color: mutedColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _pickLangkahImage(index),
              child: Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: _langkahImageBytes[index] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(_langkahImageBytes[index]!, fit: BoxFit.cover))
                    : _langkahImageUrls[index] != null && _langkahImageUrls[index]!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(_langkahImageUrls[index]!, fit: BoxFit.cover))
                        : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.photo_camera_outlined, color: Colors.grey[400], size: 24),
                            const SizedBox(height: 4),
                            Text('Foto', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[400])),
                          ]),
              ),
            ),
          ]),
        ),
        if (_langkahControllers.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent.withOpacity(0.7), size: 20),
              onPressed: () => setState(() {
                _langkahControllers[index].dispose();
                _langkahControllers.removeAt(index);
                _langkahImageBytes.removeAt(index);
                _langkahImageUrls.removeAt(index);
              }),
            ),
          )
        else
          const SizedBox(width: 40),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: textColor, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEditing ? 'Edit Resep' : 'Tulis Resep',
          style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w600, fontSize: 15)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isLoading ? null : _simpanResep,
              style: TextButton.styleFrom(
                backgroundColor: _isLoading ? Colors.grey[200] : surfaceColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6)),
              child: _isLoading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: primary))
                  : Text(_isEditing ? 'Perbarui' : 'Terbitkan',
                      style: GoogleFonts.poppins(fontSize: 14, color: textColor, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Area foto utama
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity, height: 220,
              color: surfaceColor,
              child: _imageBytes != null
                  ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                  : _existingImageUrl != null && _existingImageUrl!.isNotEmpty
                      ? Stack(fit: StackFit.expand, children: [
                          Image.network(_existingImageUrl!, fit: BoxFit.cover),
                          Container(color: Colors.black.withOpacity(0.3),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.edit_rounded, color: Colors.white, size: 32),
                              Text('Ganti foto', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
                            ])),
                        ])
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.photo_camera_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[400]!),
                              borderRadius: BorderRadius.circular(20)),
                            child: Text('[Opsional] Foto Resep',
                              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
                          ),
                        ]),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Judul resep
              Container(
                decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(8)),
                child: TextField(
                  controller: _namaResepController,
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
                  decoration: InputDecoration(
                    hintText: '[Wajib] Judul: Sup Ayam Favorit',
                    hintStyle: GoogleFonts.poppins(fontSize: 14, color: mutedColor),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
                ),
              ),

              const SizedBox(height: 12),

              // Deskripsi (opsional)
              Container(
                decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(8)),
                child: TextField(
                  controller: _deskripsiController,
                  maxLines: 3, minLines: 1,
                  style: GoogleFonts.poppins(fontSize: 14, color: textColor),
                  decoration: InputDecoration(
                    hintText: '[Opsional] Deskripsi singkat resep...',
                    hintStyle: GoogleFonts.poppins(fontSize: 13, color: mutedColor),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
                ),
              ),

              const SizedBox(height: 12),

              // Waktu masak
              Row(children: [
                SizedBox(width: 110,
                  child: Text('Lama memasak', style: GoogleFonts.poppins(fontSize: 14, color: mutedColor))),
                Expanded(
                  child: Row(children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(8)),
                        child: TextField(
                          controller: _waktuAngkaController,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.poppins(fontSize: 14, color: textColor),
                          decoration: InputDecoration(
                            hintText: '30',
                            hintStyle: GoogleFonts.poppins(color: mutedColor, fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(8)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _waktuSatuan,
                          style: GoogleFonts.poppins(fontSize: 14, color: textColor),
                          items: ['detik', 'menit', 'jam'].map((s) => DropdownMenuItem(
                            value: s, child: Text(s, style: GoogleFonts.poppins(color: textColor)))).toList(),
                          onChanged: (val) => setState(() => _waktuSatuan = val!),
                        ),
                      ),
                    ),
                  ]),
                ),
              ]),

              const SizedBox(height: 24),

              Text('Bahan-bahan',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 12),
              ...List.generate(_bahanControllers.length, (i) => _bahanItem(i)),
              const SizedBox(height: 4),
              _AddButton(
                label: '+ Bahan',
                onTap: () => setState(() => _bahanControllers.add(TextEditingController())),
              ),

              const SizedBox(height: 28),

              Text('Langkah',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 12),
              ...List.generate(_langkahControllers.length, (i) => _langkahItem(i)),
              const SizedBox(height: 4),
              _AddButton(
                label: '+ Langkah',
                onTap: () => setState(() {
                  _langkahControllers.add(TextEditingController());
                  _langkahImageBytes.add(null);
                  _langkahImageUrls.add(null);
                }),
              ),

              const SizedBox(height: 40),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AddButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label,
        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A))),
    );
  }
}