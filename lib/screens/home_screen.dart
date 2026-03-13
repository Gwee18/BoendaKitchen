import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'login_screen.dart';
import 'add_recipe_screen.dart';
import 'recipe_detail_screen.dart';
import 'profile_screen.dart';
import 'public_profile_screen.dart';

const _kPrimary   = Color(0xFFFF9900);
const _kPrimaryBg = Color(0xFFFFF3E0);
const _kDark      = Color(0xFF1A1A1A);
const _kBgLight   = Color(0xFFF7F7F7);
const _kCardLight = Colors.white;

Future<void> _openRecipeDetail(BuildContext context, String resepId) async {
  final doc = await FirebaseFirestore.instance.collection('resep').doc(resepId).get();
  if (doc.exists && context.mounted) {
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(resepId: resepId, data: doc.data()!)));
  }
}

// ════════════════════════════════════════════════════════════════════
// CONNECTIVITY WRAPPER
// ════════════════════════════════════════════════════════════════════
class _ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  const _ConnectivityWrapper({required this.child});
  @override
  State<_ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<_ConnectivityWrapper> {
  bool _isOnline = true;
  late final StreamSubscription _subscription;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      final online = result != ConnectivityResult.none;
      if (mounted && online != _isOnline) setState(() => _isOnline = online);
    });
  }

  @override
  void dispose() { _subscription.cancel(); super.dispose(); }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) setState(() => _isOnline = result != ConnectivityResult.none);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      AbsorbPointer(
        absorbing: !_isOnline,
        child: AnimatedOpacity(opacity: _isOnline ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 300), child: widget.child),
      ),
      if (!_isOnline)
        Positioned(bottom: 0, left: 0, right: 0,
          child: Container(
            color: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: SafeArea(top: false, child: Row(children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text('Tidak ada koneksi internet',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
              GestureDetector(
                onTap: _checkConnectivity,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: _kPrimary, borderRadius: BorderRadius.circular(8)),
                  child: Text('Coba lagi', style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
            ])),
          )),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════
// HOME SCREEN
// ════════════════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
  }

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        return _ConnectivityWrapper(
          child: Scaffold(
            backgroundColor: _kBgLight,
            drawer: _AppDrawer(user: user, onLogout: _logout),
            bottomNavigationBar: _BottomNavBar(
              currentIndex: _currentTab, onTap: (i) => setState(() => _currentTab = i)),
            floatingActionButton: user != null
                ? _ModernFAB(onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AddRecipeScreen()))
                    .then((_) => setState(() {})))
                : null,
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            body: _currentTab == 0
                ? _CariResepTab(
                    user: user, searchController: _searchController,
                    searchQuery: _searchQuery,
                    onSearchChanged: (val) => setState(() => _searchQuery = val),
                    onLoginRequired: () => _showLoginRequired(context))
                : _KoleksiResepTab(user: user),
          ),
        );
      },
    );
  }

  void _showLoginRequired(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Login Diperlukan', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
      content: Text('Masuk untuk menikmati semua fitur BoendaKitchen.',
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13))),
        ElevatedButton(
          onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())); },
          style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10)),
          child: Text('Masuk', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ],
    ));
  }
}

// ════════════════════════════════════════════════════════════════════
// FAB
// ════════════════════════════════════════════════════════════════════
class _ModernFAB extends StatelessWidget {
  final VoidCallback onTap;
  const _ModernFAB({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFB300), _kPrimary],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))]),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// DRAWER
// ════════════════════════════════════════════════════════════════════
class _AppDrawer extends StatelessWidget {
  final User? user;
  final VoidCallback onLogout;
  const _AppDrawer({required this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      width: MediaQuery.of(context).size.width * 0.78,
      child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFFF8EE), Color(0xFFFFF3D6)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kPrimary.withOpacity(0.2), width: 1)),
          child: user != null
              ? FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(user!.uid).get(),
                  builder: (context, snap) {
                    final data = snap.data?.data() as Map<String, dynamic>?;
                    final fotoUrl = data?['fotoUrl'] as String?;
                    final nama  = data?['nama'] as String? ?? '';
                    final email = data?['email'] as String? ?? user!.email ?? '';
                    return Row(children: [
                      CircleAvatar(radius: 26, backgroundColor: _kPrimaryBg,
                        backgroundImage: (fotoUrl != null && fotoUrl.isNotEmpty) ? NetworkImage(fotoUrl) : null,
                        child: (fotoUrl == null || fotoUrl.isEmpty) ? const Icon(Icons.person, color: _kPrimary, size: 26) : null),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(nama, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: _kDark)),
                        const SizedBox(height: 2),
                        Text(email, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]), overflow: TextOverflow.ellipsis),
                      ])),
                    ]);
                  })
              : Row(children: [
                  CircleAvatar(radius: 26, backgroundColor: _kPrimaryBg,
                      child: const Icon(Icons.person, color: _kPrimary, size: 26)),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Halo, Tamu!', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: _kDark)),
                    GestureDetector(
                      onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())); },
                      child: Text('Masuk sekarang →', style: GoogleFonts.poppins(fontSize: 12, color: _kPrimary, fontWeight: FontWeight.w600))),
                  ]),
                ]),
        ),
        _DrawerItem(icon: Icons.person_outline_rounded, label: 'Profil Saya',
          onTap: user != null ? () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())); } : null),
        _DrawerItem(icon: Icons.people_outline_rounded, label: 'Mengikuti',
          onTap: user != null ? () { Navigator.pop(context); _showFollowingSheet(context, user!.uid); } : null),
        _DrawerItem(icon: Icons.history_rounded, label: 'Terakhir Dilihat',
          onTap: user != null ? () { Navigator.pop(context); _showLastViewedSheet(context, user!.uid); } : null),
        _DrawerItem(icon: Icons.help_outline_rounded, label: 'FAQ',
          onTap: () { Navigator.pop(context); _showFaqSheet(context); }),
        const Spacer(),
        const Divider(color: Color(0xFFF0F0F0), height: 1, indent: 16, endIndent: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (user != null)
              GestureDetector(
                onTap: () { Navigator.pop(context); onLogout(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 16),
                    const SizedBox(width: 6),
                    Text('Keluar', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.redAccent)),
                  ]),
                ),
              ),
          ]),
        ),
      ])),
    );
  }

  void _showFollowingSheet(BuildContext context, String uid) =>
      showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (_) => _BottomSheet(child: _FollowingSheet(uid: uid)));
  void _showLastViewedSheet(BuildContext context, String uid) =>
      showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (_) => _BottomSheet(child: _LastViewedSheet(uid: uid)));
  void _showFaqSheet(BuildContext context) =>
      showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (_) => const _BottomSheet(child: _FaqSheet()));
}

class _BottomSheet extends StatelessWidget {
  final Widget child;
  const _BottomSheet({required this.child});
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6, maxChildSize: 0.92, minChildSize: 0.3, expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: child));
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _DrawerItem({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      leading: Icon(icon, color: isDisabled ? Colors.grey[400] : _kPrimary, size: 22),
      title: Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500,
          color: isDisabled ? Colors.grey[400] : _kDark)),
      onTap: onTap, dense: true,
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// SHEETS
// ════════════════════════════════════════════════════════════════════
class _FollowingSheet extends StatelessWidget {
  final String uid;
  const _FollowingSheet({required this.uid});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _SheetHandle(),
      Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Text('Mengikuti', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: _kDark))),
      Expanded(child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('following').snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: _kPrimary));
          final docs = snap.data!.docs;
          if (docs.isEmpty) return _EmptyState(icon: Icons.people_outline, message: 'Belum mengikuti siapapun');
          return ListView.builder(
            itemCount: docs.length, padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final nama = data['nama']?.toString() ?? 'Pengguna';
              final followedUserId = data['userId']?.toString() ?? '';
              return _UserListTile(nama: nama, onTap: followedUserId.isNotEmpty ? () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: followedUserId, nama: nama)));
              } : null);
            },
          );
        },
      )),
    ]);
  }
}

class _LastViewedSheet extends StatelessWidget {
  final String uid;
  const _LastViewedSheet({required this.uid});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _SheetHandle(),
      Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Text('Terakhir Dilihat', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: _kDark))),
      Expanded(child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('lastViewed')
            .orderBy('viewedAt', descending: true).limit(20).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: _kPrimary));
          final docs = snap.data!.docs;
          if (docs.isEmpty) return _EmptyState(icon: Icons.history_rounded, message: 'Belum ada resep yang dilihat');
          return ListView.builder(
            itemCount: docs.length, padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final resepId = docs[i].id;
              return _RecipeListTile(
                namaResep: data['namaResep']?.toString() ?? '',
                namaPembuat: data['namaPembuat']?.toString() ?? '',
                fotoUrl: data['fotoUrl']?.toString() ?? '',
                onTap: () { Navigator.pop(context); _openRecipeDetail(context, resepId); });
            },
          );
        },
      )),
    ]);
  }
}

class _FaqSheet extends StatelessWidget {
  const _FaqSheet();
  static const _faqs = [
    {'q': 'Bagaimana cara menambahkan resep?', 'a': 'Klik tombol + di pojok kanan bawah untuk membuka halaman tambah resep. Isi nama, bahan, langkah, dan waktu masak.'},
    {'q': 'Bagaimana cara menyimpan resep orang lain?', 'a': 'Buka detail resep, lalu klik tombol "Simpan" di bawah foto resep. Resep akan tersimpan di tab Koleksi Resep.'},
    {'q': 'Bagaimana cara mengikuti pengguna lain?', 'a': 'Buka profil pengguna dengan mengklik nama pembuat di halaman detail resep, lalu klik tombol "Ikuti".'},
    {'q': 'Apakah saya bisa mengedit resep yang sudah diterbitkan?', 'a': 'Ya! Buka tab Koleksi Resep > Resep Saya, lalu klik ikon titik tiga di kartu resep dan pilih Edit.'},
    {'q': 'Bagaimana cara mengubah foto profil?', 'a': 'Buka Profil Saya dari sidebar, lalu klik foto profil atau ikon kamera di pojok bawah foto.'},
  ];
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _SheetHandle(),
      Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Text('FAQ', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: _kDark))),
      Expanded(child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        itemCount: _faqs.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF0F0F0)),
        itemBuilder: (context, i) => Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(vertical: 4),
            title: Text(_faqs[i]['q']!, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _kDark)),
            iconColor: _kPrimary, collapsedIconColor: Colors.grey[400],
            children: [Padding(padding: const EdgeInsets.only(bottom: 14, right: 8),
              child: Text(_faqs[i]['a']!, style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey[600], height: 1.6)))],
          ),
        ),
      )),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════
// TAB 0 — Cari Resep
// ════════════════════════════════════════════════════════════════════
class _CariResepTab extends StatelessWidget {
  final User? user;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onLoginRequired;
  const _CariResepTab({required this.user, required this.searchController, required this.searchQuery,
      required this.onSearchChanged, required this.onLoginRequired});

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          Builder(builder: (ctx) => GestureDetector(
            onTap: () => Scaffold.of(ctx).openDrawer(),
            child: user != null ? _UserAvatar(uid: user!.uid) : const Icon(Icons.person_outline, color: _kPrimary, size: 26),
          )),
          const SizedBox(width: 12),
          Expanded(child: Container(
            height: 42,
            decoration: BoxDecoration(color: _kCardLight, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
            child: TextField(
              controller: searchController, onChanged: onSearchChanged,
              style: GoogleFonts.poppins(fontSize: 13, color: _kDark),
              decoration: InputDecoration(
                hintText: 'Cari resep...', hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
                border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 11)),
            ),
          )),
          const SizedBox(width: 10),
          if (user != null) _NotificationBell(uid: user!.uid)
          else GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: _kPrimary, borderRadius: BorderRadius.circular(12)),
              child: Text('Masuk', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ]),
      ),
      Expanded(child: searchQuery.isNotEmpty
          ? _SearchResults(searchQuery: searchQuery, user: user, onLoginRequired: onLoginRequired)
          : _HomeContent(user: user, onLoginRequired: onLoginRequired)),
    ]));
  }
}

// ════════════════════════════════════════════════════════════════════
// SEARCH RESULTS
// ════════════════════════════════════════════════════════════════════
class _SearchResults extends StatelessWidget {
  final String searchQuery;
  final User? user;
  final VoidCallback onLoginRequired;
  const _SearchResults({required this.searchQuery, required this.user, required this.onLoginRequired});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('resep').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: _kPrimary));
        final docs = snapshot.data!.docs
            .where((d) => d['namaResep'].toString().toLowerCase().contains(searchQuery.toLowerCase())).toList();
        if (docs.isEmpty) return _EmptyState(icon: Icons.search_off_rounded, message: 'Resep tidak ditemukan');
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return GestureDetector(
              onTap: () => _openRecipeDetail(context, docs[index].id),
              child: _RecipeCard(data: data));
          },
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// HOME CONTENT
// ════════════════════════════════════════════════════════════════════
class _HomeContent extends StatelessWidget {
  final User? user;
  final VoidCallback onLoginRequired;
  const _HomeContent({required this.user, required this.onLoginRequired});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
      SliverToBoxAdapter(child: _GreetingBanner(user: user)),

      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: Row(children: [
          Container(width: 4, height: 20, decoration: BoxDecoration(color: _kPrimary, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text('Resep Populer', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: _kDark)),
        ]),
      )),
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('resep').orderBy('likes', descending: true).limit(6).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SliverToBoxAdapter(
              child: Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: _kPrimary))));
          final docs = snapshot.data!.docs;
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                return GestureDetector(
                  onTap: () => _openRecipeDetail(context, docs[index].id),
                  child: _RecipeCard(data: data));
              }, childCount: docs.length),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85)));
        },
      ),

      if (user != null) ...[
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(width: 4, height: 20, decoration: BoxDecoration(color: _kPrimary, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text('Terakhir Dilihat', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: _kDark)),
            ]),
            GestureDetector(
              onTap: () => _showLastViewedSheet(context, user!.uid),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: _kPrimaryBg, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Text('Semua', style: GoogleFonts.poppins(fontSize: 11, color: _kPrimary, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: _kPrimary),
                ]),
              ),
            ),
          ]),
        )),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('lastViewed')
              .orderBy('viewedAt', descending: true).limit(2).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
            final docs = snapshot.data!.docs;
            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final resepId = docs[index].id;
                return _LastViewedCard(data: data, onTap: () => _openRecipeDetail(context, resepId));
              }, childCount: docs.length)));
          },
        ),
      ],

      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(width: 4, height: 20, decoration: BoxDecoration(color: _kPrimary, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text('Resep Terbaru', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: _kDark)),
          ]),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _SemuaResepTerbaruScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: _kPrimaryBg, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Text('Semua', style: GoogleFonts.poppins(fontSize: 11, color: _kPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: _kPrimary),
              ]),
            ),
          ),
        ]),
      )),
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('resep').orderBy('createdAt', descending: true).limit(5).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SliverToBoxAdapter(child: SizedBox.shrink());
          final docs = snapshot.data!.docs;
          return SliverToBoxAdapter(child: SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                return GestureDetector(
                  onTap: () => _openRecipeDetail(context, docs[index].id),
                  child: _NewRecipeCard(data: data));
              },
            ),
          ));
        },
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 110)),
    ]);
  }

  void _showLastViewedSheet(BuildContext context, String uid) =>
      showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (_) => _BottomSheet(child: _LastViewedSheet(uid: uid)));
}

// ════════════════════════════════════════════════════════════════════
// GREETING BANNER
// ════════════════════════════════════════════════════════════════════
class _GreetingBanner extends StatelessWidget {
  final User? user;
  const _GreetingBanner({required this.user});
  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat Pagi';
    if (h < 15) return 'Selamat Siang';
    if (h < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0), padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF9900), Color(0xFFFFB300)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))]),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_getGreeting()}!', style: GoogleFonts.poppins(fontSize: 13,
              color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('Mau masak apa\nhari ini?', style: GoogleFonts.poppins(fontSize: 20,
              fontWeight: FontWeight.bold, color: Colors.white, height: 1.2)),
        ])),
        const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 40),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// LAST VIEWED CARD
// ════════════════════════════════════════════════════════════════════
class _LastViewedCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _LastViewedCard({required this.data, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final fotoUrl = data['fotoUrl']?.toString() ?? '';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: _kCardLight, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(children: [
          ClipRRect(borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
            child: fotoUrl.isNotEmpty
                ? Image.network(fotoUrl, width: 74, height: 74, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _ph())
                : _ph()),
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(data['namaResep']?.toString() ?? '',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: _kDark),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Row(children: [
                Icon(Icons.person_outline, size: 12, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(data['namaPembuat']?.toString() ?? '',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400]),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ]),
          )),
          Padding(padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[300])),
        ]),
      ),
    );
  }
  Widget _ph() => Container(width: 74, height: 74, color: _kPrimaryBg,
      child: const Center(child: Icon(Icons.restaurant_rounded, color: _kPrimary, size: 24)));
}

// ════════════════════════════════════════════════════════════════════
// NEW RECIPE CARD
// ════════════════════════════════════════════════════════════════════
class _NewRecipeCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _NewRecipeCard({required this.data});
  @override
  Widget build(BuildContext context) {
    final fotoUrl = data['fotoUrl']?.toString() ?? '';
    return Container(
      width: 230, margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(color: _kCardLight, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(children: [
        ClipRRect(borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
          child: fotoUrl.isNotEmpty
              ? Image.network(fotoUrl, width: 74, height: 90, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _ph())
              : _ph()),
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(data['namaResep']?.toString() ?? '',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: _kDark),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(data['namaPembuat']?.toString() ?? '',
                style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[400]),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        )),
      ]),
    );
  }
  Widget _ph() => Container(width: 74, height: 90, color: _kPrimaryBg,
      child: const Center(child: Icon(Icons.restaurant_rounded, color: _kPrimary, size: 24)));
}

// ════════════════════════════════════════════════════════════════════
// NOTIFICATION BELL — followers + komentar
// ════════════════════════════════════════════════════════════════════
class _NotificationBell extends StatefulWidget {
  final String uid;
  const _NotificationBell({required this.uid});
  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  Timestamp? _lastSeen;

  @override
  void initState() { super.initState(); _loadLastSeen(); }

  Future<void> _loadLastSeen() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
    if (mounted) setState(() => _lastSeen = doc.data()?['notifLastSeen'] as Timestamp?);
  }

  Future<void> _markAsSeen() async {
    final now = Timestamp.now();
    await FirebaseFirestore.instance.collection('users').doc(widget.uid)
        .update({'notifLastSeen': now});
    // Tandai semua notif komentar sebagai sudah dibaca (tapi tidak dihapus)
    final unread = await FirebaseFirestore.instance
        .collection('users').doc(widget.uid)
        .collection('notifikasi')
        .where('isRead', isEqualTo: false).get();
    for (final doc in unread.docs) {
      doc.reference.update({'isRead': true});
    }
    if (mounted) setState(() => _lastSeen = now);
  }

  int _countUnreadFollowers(List<QueryDocumentSnapshot> docs) {
    if (_lastSeen == null) return docs.length;
    return docs.where((d) {
      final followedAt = (d.data() as Map<String, dynamic>)['followedAt'] as Timestamp?;
      return followedAt != null && followedAt.compareTo(_lastSeen!) > 0;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(widget.uid)
          .collection('notifikasi')
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, notifSnap) {
        final unreadKomentar = notifSnap.data?.docs.length ?? 0;
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.uid)
              .collection('followers').orderBy('followedAt', descending: true).limit(20).snapshots(),
          builder: (context, followSnap) {
            final followerDocs   = followSnap.data?.docs ?? [];
            final unreadFollowers = _countUnreadFollowers(followerDocs);
            final totalUnread    = unreadKomentar + unreadFollowers;

            return GestureDetector(
              onTap: () async {
                await _markAsSeen();
                if (context.mounted) _showNotifSheet(context, followerDocs);
              },
              child: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: totalUnread > 0 ? _kPrimaryBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(12)),
                child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                  Icon(totalUnread > 0 ? Icons.notifications_rounded : Icons.notifications_outlined,
                      color: totalUnread > 0 ? _kPrimary : Colors.grey[500], size: 22),
                  if (totalUnread > 0)
                    Positioned(top: 4, right: 4, child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(totalUnread > 9 ? '9+' : '$totalUnread',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                    )),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  void _showNotifSheet(BuildContext context, List<QueryDocumentSnapshot> followerDocs) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _NotifSheet(uid: widget.uid, followerDocs: followerDocs, lastSeen: _lastSeen),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// NOTIF SHEET — StatefulWidget agar bisa update saat hapus
// ════════════════════════════════════════════════════════════════════
class _NotifSheet extends StatefulWidget {
  final String uid;
  final List<QueryDocumentSnapshot> followerDocs;
  final Timestamp? lastSeen;
  const _NotifSheet({required this.uid, required this.followerDocs, required this.lastSeen});
  @override
  State<_NotifSheet> createState() => _NotifSheetState();
}

class _NotifSheetState extends State<_NotifSheet> {
  // Cache foto profil follower: userId -> fotoUrl
  final Map<String, String> _followerFotos = {};

  @override
  void initState() {
    super.initState();
    _loadFollowerFotos();
  }

  Future<void> _loadFollowerFotos() async {
    for (final doc in widget.followerDocs) {
      final userId = (doc.data() as Map<String, dynamic>)['userId']?.toString() ?? '';
      if (userId.isEmpty || _followerFotos.containsKey(userId)) continue;
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        final foto = userDoc.data()?['fotoUrl']?.toString() ?? '';
        if (mounted) setState(() => _followerFotos[userId] = foto);
      } catch (_) {}
    }
  }

  Future<void> _hapusNotif(String docId) async {
    await FirebaseFirestore.instance
        .collection('users').doc(widget.uid)
        .collection('notifikasi').doc(docId).delete();
  }

  bool _isNewFollower(Timestamp? followedAt) {
    if (widget.lastSeen == null) return true;
    return followedAt != null && followedAt.compareTo(widget.lastSeen!) > 0;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6, maxChildSize: 0.92, minChildSize: 0.3, expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: StreamBuilder<QuerySnapshot>(
          // Stream semua notif komentar (read maupun unread), terbaru dulu
          stream: FirebaseFirestore.instance
              .collection('users').doc(widget.uid)
              .collection('notifikasi')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, notifSnap) {
            final notifDocs = notifSnap.data?.docs ?? [];

            // Gabungkan followers + notif komentar
            final List<Map<String, dynamic>> allNotifs = [];

            for (final doc in widget.followerDocs) {
              final d = doc.data() as Map<String, dynamic>;
              final userId = d['userId']?.toString() ?? '';
              allNotifs.add({
                'tipe':      'follower',
                'nama':      d['nama']?.toString() ?? 'Pengguna',
                'userId':    userId,
                'fotoUrl':   _followerFotos[userId] ?? '',
                'createdAt': d['followedAt'] as Timestamp? ?? Timestamp.now(),
                'isNew':     _isNewFollower(d['followedAt'] as Timestamp?),
              });
            }

            for (final doc in notifDocs) {
              final d = doc.data() as Map<String, dynamic>;
              allNotifs.add({
                'tipe':       'komentar',
                'docId':      doc.id,
                'nama':       d['dari']?.toString() ?? 'Pengguna',
                'fromUserId': d['fromUserId']?.toString() ?? '',
                'resepId':    d['resepId']?.toString() ?? '',
                'namaResep':  d['namaResep']?.toString() ?? '',
                'preview':    d['preview']?.toString() ?? '',
                'fotoResep':  d['fotoResep']?.toString() ?? '',
                'createdAt':  d['createdAt'] as Timestamp? ?? Timestamp.now(),
                'isNew':      !(d['isRead'] as bool? ?? true),
              });
            }

            allNotifs.sort((a, b) =>
                (b['createdAt'] as Timestamp).compareTo(a['createdAt'] as Timestamp));

            return Column(children: [
              _SheetHandle(),
              Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Notifikasi', style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.bold, color: _kDark)),
                  if (allNotifs.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: _kPrimaryBg, borderRadius: BorderRadius.circular(10)),
                      child: Text('${allNotifs.length}',
                          style: GoogleFonts.poppins(fontSize: 11, color: _kPrimary, fontWeight: FontWeight.w600))),
                ])),
              Expanded(child: allNotifs.isEmpty
                  ? _EmptyState(icon: Icons.notifications_none_rounded, message: 'Belum ada notifikasi')
                  : ListView.builder(
                      controller: controller, itemCount: allNotifs.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, i) {
                        final n    = allNotifs[i];
                        final tipe = n['tipe'] as String;
                        final isNew = n['isNew'] as bool;

                        if (tipe == 'follower') {
                          // Follower tile dengan foto profil
                          final fotoUrl = n['fotoUrl'] as String;
                          final userId  = n['userId'] as String;
                          final nama    = n['nama'] as String;
                          return _NotifFollowerTile(
                            nama: nama, fotoUrl: fotoUrl, isNew: isNew,
                            createdAt: n['createdAt'] as Timestamp?,
                            onTap: userId.isNotEmpty ? () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) =>
                                  PublicProfileScreen(userId: userId, nama: nama)));
                            } : null,
                          );
                        } else {
                          // Komentar tile dengan foto resep + swipe to delete
                          final docId    = n['docId'] as String;
                          final resepId  = n['resepId'] as String;
                          return _NotifKomentarTile(
                            uid: widget.uid,
                            docId: docId,
                            nama: n['nama'] as String,
                            namaResep: n['namaResep'] as String,
                            preview: n['preview'] as String,
                            fotoResep: n['fotoResep'] as String,
                            resepId: resepId,
                            isNew: isNew,
                            createdAt: n['createdAt'] as Timestamp?,
                            onDelete: () => _hapusNotif(docId),
                            onTap: resepId.isNotEmpty ? () {
                              Navigator.pop(context);
                              _openRecipeDetail(context, resepId);
                            } : null,
                          );
                        }
                      })),
            ]);
          },
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// NOTIF TILE — Follower (dengan foto profil)
// ════════════════════════════════════════════════════════════════════
class _NotifFollowerTile extends StatelessWidget {
  final String nama;
  final String fotoUrl;
  final bool isNew;
  final Timestamp? createdAt;
  final VoidCallback? onTap;
  const _NotifFollowerTile({required this.nama, required this.fotoUrl,
      required this.isNew, this.createdAt, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isNew ? const Color(0xFFFFF8EE) : Colors.transparent,
        borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        leading: Stack(children: [
          CircleAvatar(
            radius: 22, backgroundColor: _kPrimaryBg,
            backgroundImage: fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
            child: fotoUrl.isEmpty
                ? Text(nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                    style: GoogleFonts.poppins(color: _kPrimary, fontWeight: FontWeight.bold, fontSize: 16))
                : null),
          Positioned(bottom: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: _kPrimary, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5)),
              child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 10))),
        ]),
        title: RichText(text: TextSpan(
          style: GoogleFonts.poppins(fontSize: 13, color: _kDark),
          children: [
            TextSpan(text: nama, style: const TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(text: ' mulai mengikutimu'),
          ])),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_formatWaktu(createdAt),
              style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[400])),
          if (isNew) ...[
            const SizedBox(height: 4),
            Container(width: 8, height: 8,
                decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
          ],
        ]),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// NOTIF TILE — Komentar (dengan foto resep, swipe to delete)
// ════════════════════════════════════════════════════════════════════
class _NotifKomentarTile extends StatefulWidget {
  final String uid;
  final String docId;
  final String nama;
  final String namaResep;
  final String preview;
  final String fotoResep;
  final String resepId;
  final bool isNew;
  final Timestamp? createdAt;
  final VoidCallback onDelete;
  final VoidCallback? onTap;
  const _NotifKomentarTile({required this.uid, required this.docId, required this.nama,
      required this.namaResep, required this.preview, required this.fotoResep,
      required this.resepId, required this.isNew, this.createdAt, required this.onDelete, this.onTap});
  @override
  State<_NotifKomentarTile> createState() => _NotifKomentarTileState();
}

class _NotifKomentarTileState extends State<_NotifKomentarTile> {
  String _fotoResep = '';

  @override
  void initState() {
    super.initState();
    _fotoResep = widget.fotoResep;
    if (_fotoResep.isEmpty && widget.resepId.isNotEmpty) _loadFotoResep();
  }

  Future<void> _loadFotoResep() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('resep').doc(widget.resepId).get();
      final foto = doc.data()?['fotoUrl']?.toString() ?? '';
      if (mounted && foto.isNotEmpty) setState(() => _fotoResep = foto);
    } catch (_) {}
  }

  void _konfirmasiHapus() {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Hapus Notifikasi?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      content: Text('Notifikasi ini akan dihapus permanen.', style: GoogleFonts.poppins(fontSize: 13)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.poppins(color: Colors.grey))),
        TextButton(
          onPressed: () { Navigator.pop(context); widget.onDelete(); },
          child: Text('Hapus', style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(widget.docId),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
          SizedBox(height: 2),
          Text('Hapus', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
      confirmDismiss: (_) async {
        bool confirm = false;
        await showDialog(context: context, builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Hapus Notifikasi?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text('Notifikasi ini akan dihapus permanen.', style: GoogleFonts.poppins(fontSize: 13)),
          actions: [
            TextButton(onPressed: () { Navigator.pop(context); confirm = false; },
                child: Text('Batal', style: GoogleFonts.poppins(color: Colors.grey))),
            TextButton(
              onPressed: () { Navigator.pop(context); confirm = true; },
              child: Text('Hapus', style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold))),
          ],
        ));
        if (confirm) widget.onDelete();
        return false; // Firestore stream yang handle update UI
      },
      child: GestureDetector(
        onLongPress: _konfirmasiHapus,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: widget.isNew ? const Color(0xFFF0F7FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: widget.isNew
                ? Border.all(color: Colors.blueAccent.withOpacity(0.2))
                : Border.all(color: Colors.transparent)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            leading: Stack(children: [
              // Foto resep
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _fotoResep.isNotEmpty
                    ? Image.network(_fotoResep, width: 48, height: 48, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fotoPlaceholder())
                    : _fotoPlaceholder()),
              // Badge ikon komentar di pojok kanan bawah
              Positioned(bottom: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5)),
                  child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 9))),
            ]),
            title: RichText(text: TextSpan(
              style: GoogleFonts.poppins(fontSize: 12.5, color: _kDark),
              children: [
                TextSpan(text: widget.nama, style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: ' berkomentar di '),
                TextSpan(text: widget.namaResep, style: const TextStyle(fontWeight: FontWeight.w600, color: _kPrimary)),
              ])),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('"${widget.preview}"',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
                  maxLines: 2, overflow: TextOverflow.ellipsis)),
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_formatWaktu(widget.createdAt),
                  style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[400])),
              if (widget.isNew) ...[
                const SizedBox(height: 4),
                Container(width: 8, height: 8,
                    decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle)),
              ],
            ]),
            onTap: widget.onTap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _fotoPlaceholder() => Container(
    width: 48, height: 48, color: _kPrimaryBg,
    child: const Center(child: Icon(Icons.restaurant_rounded, color: _kPrimary, size: 22)));
}

// ════════════════════════════════════════════════════════════════════
// TAB 1 — Koleksi Resep
// ════════════════════════════════════════════════════════════════════
class _KoleksiResepTab extends StatefulWidget {
  final User? user;
  const _KoleksiResepTab({required this.user});
  @override
  State<_KoleksiResepTab> createState() => _KoleksiResepTabState();
}

class _KoleksiResepTabState extends State<_KoleksiResepTab> {
  int _selectedChip = 0;
  @override
  Widget build(BuildContext context) {
    if (widget.user == null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 80, height: 80,
            decoration: BoxDecoration(color: _kPrimaryBg, borderRadius: BorderRadius.circular(24)),
            child: const Icon(Icons.bookmark_outline_rounded, color: _kPrimary, size: 40)),
        const SizedBox(height: 16),
        Text('Koleksi Resepmu', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: _kDark)),
        const SizedBox(height: 6),
        Text('Masuk untuk melihat koleksi resep', style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13)),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
          style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white, elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: Text('Masuk Sekarang', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        ),
      ]));
    }
    return SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Text('Koleksi Resep', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: _kDark))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          _FilterChip(label: 'Resep Saya', isSelected: _selectedChip == 0, onTap: () => setState(() => _selectedChip = 0)),
          const SizedBox(width: 10),
          _FilterChip(label: 'Tersimpan', isSelected: _selectedChip == 1, onTap: () => setState(() => _selectedChip = 1)),
          const SizedBox(width: 10),
          _FilterChip(label: 'Disukai', isSelected: _selectedChip == 2, onTap: () => setState(() => _selectedChip = 2)),
        ])),
      const SizedBox(height: 12),
      Expanded(child: _selectedChip == 0
          ? _ResepSayaGrid(user: widget.user!)
          : _selectedChip == 1
              ? _TersimpanGrid(user: widget.user!)
              : _DisukaiGrid(user: widget.user!)),
    ]));
  }
}

// ════════════════════════════════════════════════════════════════════
// RESEP SAYA
// ════════════════════════════════════════════════════════════════════
class _ResepSayaGrid extends StatelessWidget {
  final User user;
  const _ResepSayaGrid({required this.user});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('resep')
          .where('userId', isEqualTo: user.uid).orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: _kPrimary));
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return _EmptyCollection(icon: Icons.receipt_long_outlined,
            message: 'Belum ada resep', sub: 'Mulai tambahkan resep pertamamu!');
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.75),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data  = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            return _CollectionCard(
              data: data,
              onTap: () => _openRecipeDetail(context, docId),
              onEdit: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => AddRecipeScreen(resepId: docId, existingData: data))),
              onDelete: () => _confirmDelete(context, docId),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String docId) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Hapus Resep', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      content: Text('Yakin ingin menghapus resep ini?', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.poppins(color: Colors.grey[500]))),
        ElevatedButton(
          onPressed: () { FirebaseFirestore.instance.collection('resep').doc(docId).delete(); Navigator.pop(context); },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text('Hapus', style: GoogleFonts.poppins(color: Colors.white)),
        ),
      ],
    ));
  }
}

// ════════════════════════════════════════════════════════════════════
// TERSIMPAN
// ════════════════════════════════════════════════════════════════════
class _TersimpanGrid extends StatefulWidget {
  final User user;
  const _TersimpanGrid({required this.user});
  @override
  State<_TersimpanGrid> createState() => _TersimpanGridState();
}

class _TersimpanGridState extends State<_TersimpanGrid> {
  List<Map<String, dynamic>>? _savedReseps;
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadSavedReseps(); }

  Future<void> _loadSavedReseps() async {
    if (mounted) setState(() => _loading = true);
    try {
      final savedDocs = await FirebaseFirestore.instance
          .collection('users').doc(widget.user.uid).collection('savedResep').get();
      final List<Map<String, dynamic>> result = [];
      for (final doc in savedDocs.docs) {
        final resepDoc = await FirebaseFirestore.instance.collection('resep').doc(doc.id).get();
        if (resepDoc.exists) result.add({'_id': doc.id, ...resepDoc.data()!});
      }
      if (mounted) setState(() { _savedReseps = result; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _savedReseps = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _kPrimary));
    final saved = _savedReseps ?? [];
    if (saved.isEmpty) return _EmptyCollection(icon: Icons.bookmark_outline_rounded,
        message: 'Belum ada resep tersimpan', sub: 'Simpan resep favoritmu dari beranda!');
    return RefreshIndicator(
      color: _kPrimary, onRefresh: _loadSavedReseps,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.75),
        itemCount: saved.length,
        itemBuilder: (context, index) {
          final resepId = saved[index]['_id'] as String;
          final data = Map<String, dynamic>.from(saved[index])..remove('_id');
          return _CollectionCard(data: data, showBookmark: true, onTap: () => _openRecipeDetail(context, resepId));
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// DISUKAI
// ════════════════════════════════════════════════════════════════════
class _DisukaiGrid extends StatefulWidget {
  final User user;
  const _DisukaiGrid({required this.user});
  @override
  State<_DisukaiGrid> createState() => _DisukaiGridState();
}

class _DisukaiGridState extends State<_DisukaiGrid> {
  List<Map<String, dynamic>>? _likedReseps;
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadLikedReseps(); }

  Future<void> _loadLikedReseps() async {
    if (mounted) setState(() => _loading = true);
    try {
      final allResep = await FirebaseFirestore.instance.collection('resep').get();
      final List<Map<String, dynamic>> liked = [];
      for (final doc in allResep.docs) {
        final likeDoc = await FirebaseFirestore.instance
            .collection('resep').doc(doc.id).collection('likes').doc(widget.user.uid).get();
        if (likeDoc.exists) liked.add({'_id': doc.id, ...doc.data()});
      }
      if (mounted) setState(() { _likedReseps = liked; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _likedReseps = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _kPrimary));
    final liked = _likedReseps ?? [];
    if (liked.isEmpty) return _EmptyCollection(icon: Icons.favorite_outline_rounded,
        message: 'Belum ada resep disukai', sub: 'Like resep favoritmu!');
    return RefreshIndicator(
      color: _kPrimary, onRefresh: _loadLikedReseps,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.75),
        itemCount: liked.length,
        itemBuilder: (context, index) {
          final resepId = liked[index]['_id'] as String;
          final data = Map<String, dynamic>.from(liked[index])..remove('_id');
          return _CollectionCard(data: data, onTap: () => _openRecipeDetail(context, resepId));
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ════════════════════════════════════════════════════════════════════
class _CollectionCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool showBookmark;
  const _CollectionCard({required this.data, required this.onTap, this.onEdit, this.onDelete, this.showBookmark = false});

  @override
  Widget build(BuildContext context) {
    final fotoUrl   = data['fotoUrl']?.toString() ?? '';
    final namaResep = data['namaResep']?.toString() ?? '';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: _kCardLight, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(height: 130, child: Stack(children: [
            ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: fotoUrl.isNotEmpty
                  ? Image.network(fotoUrl, width: double.infinity, height: 130, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _ph())
                  : _ph()),
            Positioned(top: 8, right: 8, child: Row(children: [
              if (showBookmark) _OverlayIcon(icon: Icons.bookmark_rounded),
              if (onEdit != null || onDelete != null)
                PopupMenuButton(padding: EdgeInsets.zero, icon: _OverlayIcon(icon: Icons.more_horiz_rounded),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  itemBuilder: (_) => [
                    if (onEdit != null) PopupMenuItem(onTap: onEdit, child: Row(children: [
                      const Icon(Icons.edit_outlined, color: Colors.orange, size: 18), const SizedBox(width: 8),
                      Text('Edit', style: GoogleFonts.poppins(fontSize: 13))])),
                    if (onDelete != null) PopupMenuItem(onTap: onDelete, child: Row(children: [
                      const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), const SizedBox(width: 8),
                      Text('Hapus', style: GoogleFonts.poppins(fontSize: 13, color: Colors.redAccent))])),
                  ]),
            ])),
          ])),
          Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Text(namaResep, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: _kDark),
                maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
  Widget _ph() => Container(color: _kPrimaryBg, child: const Center(child: Icon(Icons.restaurant_rounded, color: _kPrimary, size: 36)));
}

class _RecipeCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RecipeCard({required this.data});
  @override
  Widget build(BuildContext context) {
    final fotoUrl      = data['fotoUrl']?.toString() ?? '';
    final namaResep    = data['namaResep']?.toString() ?? '';
    final namaPembuat  = data['namaPembuat']?.toString() ?? '';
    final likes        = (data['likes'] ?? 0) as int;
    return Container(
      decoration: BoxDecoration(color: _kCardLight, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: 130, child: Stack(children: [
          ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: fotoUrl.isNotEmpty
                ? Image.network(fotoUrl, width: double.infinity, height: 130, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _ph())
                : _ph()),
          if (likes > 0) Positioned(bottom: 8, right: 8, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 11),
              const SizedBox(width: 4),
              Text('$likes', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ]))),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(namaResep, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: _kDark),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              Icon(Icons.person_outline, size: 11, color: Colors.grey[400]),
              const SizedBox(width: 3),
              Expanded(child: Text(namaPembuat, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[400]),
                  overflow: TextOverflow.ellipsis)),
            ]),
          ])),
      ]),
    );
  }
  Widget _ph() => Container(color: _kPrimaryBg, child: const Center(child: Icon(Icons.restaurant_rounded, color: _kPrimary, size: 36)));
}

class _UserAvatar extends StatelessWidget {
  final String uid;
  const _UserAvatar({required this.uid});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        final fotoUrl = (snapshot.data?.data() as Map<String, dynamic>?)?['fotoUrl'] as String?;
        return CircleAvatar(radius: 19, backgroundColor: _kPrimaryBg,
          backgroundImage: (fotoUrl != null && fotoUrl.isNotEmpty) ? NetworkImage(fotoUrl) : null,
          child: (fotoUrl == null || fotoUrl.isEmpty) ? const Icon(Icons.person, color: _kPrimary, size: 20) : null);
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.isSelected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? _kPrimary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [BoxShadow(color: _kPrimary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
              : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))]),
        child: Text(label, style: GoogleFonts.poppins(fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.grey[600])),
      ),
    );
  }
}

class _OverlayIcon extends StatelessWidget {
  final IconData icon;
  const _OverlayIcon({required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
    child: Icon(icon, color: Colors.white, size: 15));
}

class _EmptyCollection extends StatelessWidget {
  final IconData icon;
  final String message;
  final String sub;
  const _EmptyCollection({required this.icon, required this.message, required this.sub});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 72, height: 72,
        decoration: BoxDecoration(color: _kPrimaryBg, borderRadius: BorderRadius.circular(20)),
        child: Icon(icon, size: 36, color: _kPrimary)),
    const SizedBox(height: 14),
    Text(message, style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 15, fontWeight: FontWeight.w500)),
    const SizedBox(height: 4),
    Text(sub, style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12)),
  ]));
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 64, height: 64,
        decoration: BoxDecoration(color: _kPrimaryBg, borderRadius: BorderRadius.circular(18)),
        child: Icon(icon, size: 30, color: _kPrimary)),
    const SizedBox(height: 12),
    Text(message, style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 14)),
  ]));
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8),
    child: Center(child: Container(width: 36, height: 4,
        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))));
}

String _formatWaktu(Timestamp? ts) {
  if (ts == null) return '';
  final now  = DateTime.now();
  final diff = now.difference(ts.toDate());
  if (diff.inMinutes < 1)  return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m yang lalu';
  if (diff.inHours < 24)   return '${diff.inHours}j yang lalu';
  if (diff.inDays < 7)     return '${diff.inDays}h yang lalu';
  if (diff.inDays < 30)    return '${(diff.inDays ~/ 7)}mgg yang lalu';
  if (diff.inDays < 365)   return '${(diff.inDays ~/ 30)}bln yang lalu';
  return '${(diff.inDays ~/ 365)}thn yang lalu';
}

class _UserListTile extends StatelessWidget {
  final String nama;
  final String? subtitle;
  final bool isHighlighted;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _UserListTile({required this.nama, this.subtitle, this.isHighlighted = false, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFFFFF8EE) : Colors.transparent,
        borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        leading: CircleAvatar(backgroundColor: _kPrimaryBg,
          child: Text(nama.isNotEmpty ? nama[0].toUpperCase() : '?',
              style: GoogleFonts.poppins(color: _kPrimary, fontWeight: FontWeight.bold))),
        title: Text(nama, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: subtitle != null ? Text(subtitle!, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400])) : null,
        trailing: trailing, onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _RecipeListTile extends StatelessWidget {
  final String namaResep;
  final String namaPembuat;
  final String fotoUrl;
  final VoidCallback onTap;
  const _RecipeListTile({required this.namaResep, required this.namaPembuat, required this.fotoUrl, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        leading: ClipRRect(borderRadius: BorderRadius.circular(10),
          child: fotoUrl.isNotEmpty
              ? Image.network(fotoUrl, width: 52, height: 52, fit: BoxFit.cover)
              : Container(width: 52, height: 52, color: _kPrimaryBg,
                  child: const Icon(Icons.restaurant_rounded, color: _kPrimary))),
        title: Text(namaResep, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(namaPembuat, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400])),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[300]),
        onTap: onTap, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// BOTTOM NAV
// ════════════════════════════════════════════════════════════════════
class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNavBar({required this.currentIndex, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, -2))]),
      child: SafeArea(top: false, child: SizedBox(height: 60, child: Row(children: [
        _NavItem(icon: Icons.home_rounded, activeIcon: Icons.home_rounded, label: 'Beranda',
            isActive: currentIndex == 0, onTap: () => onTap(0)),
        _NavItem(icon: Icons.bookmark_outline_rounded, activeIcon: Icons.bookmark_rounded, label: 'Koleksi',
            isActive: currentIndex == 1, onTap: () => onTap(1)),
      ]))),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.isActive, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(
      onTap: onTap, behavior: HitTestBehavior.opaque,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(isActive ? activeIcon : icon, color: isActive ? _kPrimary : Colors.grey[400], size: 22),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.poppins(fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? _kPrimary : Colors.grey[400])),
      ]),
    ));
  }
}

// ════════════════════════════════════════════════════════════════════
// SEMUA RESEP TERBARU
// ════════════════════════════════════════════════════════════════════
class _SemuaResepTerbaruScreen extends StatelessWidget {
  const _SemuaResepTerbaruScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgLight,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0, scrolledUnderElevation: 0,
        title: Text('Resep Terbaru', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: _kDark)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: _kDark, size: 20),
            onPressed: () => Navigator.pop(context)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('resep').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: _kPrimary));
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return _EmptyState(icon: Icons.receipt_long_outlined, message: 'Belum ada resep');
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return GestureDetector(
                onTap: () => _openRecipeDetail(context, docs[index].id),
                child: _RecipeCard(data: data));
            },
          );
        },
      ),
    );
  }
}