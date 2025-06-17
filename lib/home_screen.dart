import 'package:flutter/material.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:kelompok_todolist/auth_service.dart'; 
import 'package:kelompok_todolist/signin_screen.dart'; 

// Kelas HomeScreen yang merupakan widget stateful
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key}); // konstruktor untuk HomeScreen

  @override
  State<HomeScreen> createState() => _HomeScreenState(); // mengembalikan state untuk HomeScreen
}

// State untuk HomeScreen
class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> todoList = []; // daftar tugas
  final TextEditingController _controller = TextEditingController(); // Kontrol untuk input teks
  int updateIndex = -1; // indeks untuk tugas yang sedang diperbarui
  late AnimationController _animationController; // Kontrol animasi
  late Animation<double> _fadeAnimation; // animasi fade

  @override
  void initState() {
    super.initState(); // Memanggil initState dari superclass
    // Menginisialisasi AnimationController
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300), // Durasi animasi
      vsync: this, // Menggunakan TickerProvider
    );
    // Menginisialisasi animasi fade
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    fetchTasks(); // Memanggil fungsi untuk mengambil tugas
    _animationController.forward(); // Memulai animasi
  }

  @override
  void dispose() {
    _animationController.dispose(); // Menghapus controller animasi
    super.dispose(); // Memanggil dispose dari superclass
  }

  // Fungsi untuk mengambil tugas dari Firestore
  Future<void> fetchTasks() async {
    final user = FirebaseAuth.instance.currentUser ; // Mendapatkan pengguna saat ini
    if (user == null) return; // Jika tidak ada pengguna, keluar dari fungsi

    // Mengambil data tugas dari Firestore
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('todos')
        .orderBy('createdAt', descending: false) // Mengurutkan berdasarkan waktu dibuat
        .get();

    // Memperbarui daftar tugas di state
    setState(() {
      todoList = snapshot.docs.map((doc) => {
        'id': doc.id, // ID dokumen
        'title': doc['title'], 
        'isCompleted': doc.data().containsKey('isCompleted') ? doc['isCompleted'] : false, // Status penyelesaian
        'createdAt': doc.data().containsKey('createdAt') ? doc['createdAt'] : null, // Waktu dibuat
      }).toList();
    });
  }

  // Fungsi untuk menambahkan tugas baru
  Future<void> addList(String task) async {
    if (task.trim().isEmpty) return; // Jika tugas kosong, keluar dari fungsi
    final user = FirebaseAuth.instance.currentUser ; // Mendapatkan pengguna saat ini
    if (user == null) return; // Jika tidak ada pengguna, keluar dari fungsi

    // Menambahkan tugas baru ke Firestore
    final docRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('todos')
        .add({
      'title': task,
      'isCompleted': false, // Status penyelesaian
      'createdAt': FieldValue.serverTimestamp(), // Waktu dibuat
    });

    // Memperbarui daftar tugas di state
    setState(() {
      todoList.add({
        'id': docRef.id, // ID dokumen yang baru ditambahkan
        'title': task,
        'isCompleted': false, // Status penyelesaian
        'createdAt': null, // Waktu dibuat
      });
      _controller.clear(); // Mengosongkan kontrol input
    });
  }

  // Fungsi untuk memperbarui tugas yang ada
  Future<void> updateListItem(String task, int index) async {
    if (task.trim().isEmpty) return; // Jika tugas kosong, keluar dari fungsi
    final user = FirebaseAuth.instance.currentUser ; // Mendapatkan pengguna saat ini
    if (user == null) return; // Jika tidak ada pengguna, keluar dari fungsi

    final docId = todoList[index]['id']; // Mendapatkan ID dokumen tugas
    // Memperbarui judul tugas di Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('todos')
        .doc(docId)
        .update({'title': task});

    // Memperbarui daftar tugas di state
    setState(() {
      todoList[index]['title'] = task; // Memperbarui judul tugas
      updateIndex = -1; // Mengatur kembali indeks pembaruan
      _controller.clear(); // Mengosongkan kontrol input
    });
  }

  // Fungsi untuk mengubah status penyelesaian tugas
  Future<void> toggleTaskCompletion(int index) async {
    final user = FirebaseAuth.instance.currentUser ; // Mendapatkan pengguna saat ini
    if (user == null) return; // Jika tidak ada pengguna, keluar dari fungsi

    final docId = todoList[index]['id']; // Mendapatkan ID dokumen tugas
    final newStatus = !todoList[index]['isCompleted']; // Mengubah status penyelesaian
    
    // Memperbarui status penyelesaian di Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('todos')
        .doc(docId)
        .update({'isCompleted': newStatus});

    // Memperbarui daftar tugas di state
    setState(() {
      todoList[index]['isCompleted'] = newStatus; // Memperbarui status penyelesaian
    });
  }

  // Fungsi untuk menghapus tugas
  Future<void> deleteItem(int index) async {
    final user = FirebaseAuth.instance.currentUser ; // Mendapatkan pengguna saat ini
    if (user == null) return; // Jika tidak ada pengguna, keluar dari fungsi

    final docId = todoList[index]['id']; // Mendapatkan ID dokumen tugas
    // Menghapus tugas dari Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('todos')
        .doc(docId)
        .delete();

    // Memperbarui daftar tugas di state
    setState(() {
      todoList.removeAt(index); // Menghapus tugas dari daftar
    });
  }

  // Fungsi untuk keluar dari akun
  void _signOut(BuildContext context) async {
    await AuthService().signOut(); // Memanggil fungsi signOut dari AuthService
    // Mengarahkan pengguna kembali ke layar masuk
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SignInScreen()),
    );
  }

  // Menghitung jumlah tugas yang telah diselesaikan
  int get completedTasksCount => todoList.where((task) => task['isCompleted']).length;
  // Menghitung total jumlah tugas
  int get totalTasksCount => todoList.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE), 
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation, 
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), 
            child: Column(
              children: [
                // Header yang ditingkatkan dengan progres
                Container(
                  padding: const EdgeInsets.all(20), 
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade600], 
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25), 
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.shade200, 
                        blurRadius: 15, 
                        offset: const Offset(0, 8), 
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // Penjajaran konten
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Penjajaran antara elemen
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start, 
                            children: [
                              const Text(
                                'To Do List', 
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white, 
                                ),
                              ),
                              const SizedBox(height: 4), 
                              Text(
                                'Tambahkan tugas anda, stay productive', 
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.8), // Warna teks dengan transparansi
                                ),
                              ),
                            ],
                          ),
                          // Tombol keluar
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2), // Warna latar belakang
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: () => _signOut(context),
                              icon: const Icon(Icons.logout, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20), // Jarak vertikal
                      // Indikator progres
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start, 
                              children: [
                                Text(
                                  '$completedTasksCount of $totalTasksCount tasks completed', // Menampilkan jumlah tugas yang diselesaikan
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8), // Jarak vertikal
                                LinearProgressIndicator(
                                  value: totalTasksCount > 0 ? completedTasksCount / totalTasksCount : 0, // Nilai progres
                                  backgroundColor: Colors.white.withOpacity(0.3), 
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white), 
                                  borderRadius: BorderRadius.circular(10), 
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16), 
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2), 
                              borderRadius: BorderRadius.circular(15), 
                            ),
                            child: Text(
                              totalTasksCount > 0 
                                  ? '${((completedTasksCount / totalTasksCount) * 100).round()}%' // Persentase tugas yang diselesaikan
                                  : '0%', // Jika tidak ada tugas
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20), 

                // Input tugas yang ditingkatkan
                Container(
                  padding: const EdgeInsets.all(20), 
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.circular(20), 
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200, 
                        blurRadius: 10, 
                        offset: const Offset(0, 5), 
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8), // Padding untuk ikon
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50, 
                          borderRadius: BorderRadius.circular(10), 
                        ),
                        child: Icon(
                          updateIndex == -1 ? Icons.add_task : Icons.edit_note, // Ikon tambah atau edit
                          color: Colors.deepPurple, 
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12), 
                      Expanded(
                        child: TextField(
                          controller: _controller, // Kontrol input
                          decoration: InputDecoration(
                            hintText: updateIndex == -1 ? 'Add a new task...' : 'Edit task...', 
                            hintStyle: TextStyle(color: Colors.grey.shade500), 
                            border: InputBorder.none, 
                          ),
                          style: const TextStyle(fontSize: 16), 
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade600], 
                          ),
                          borderRadius: BorderRadius.circular(12), 
                        ),
                        child: IconButton(
                          icon: Icon(
                            updateIndex == -1 ? Icons.send : Icons.check, 
                            color: Colors.white, 
                            size: 20,
                          ),
                          onPressed: () {
                            // Menangani penambahan atau pembaruan tugas
                            updateIndex != -1
                                ? updateListItem(_controller.text, updateIndex) // Memperbarui tugas
                                : addList(_controller.text); // Menambahkan tugas baru
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Daftar tugas yang ditingkatkan
                Expanded(
                  child: todoList.isEmpty // Jika daftar tugas kosong
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center, 
                            children: [
                              Icon(
                                Icons.task_alt,
                                size: 80,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16), 
                              Text(
                                'No tasks yet!', // Pesan jika tidak ada tugas
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade500, 
                                ),
                              ),
                              const SizedBox(height: 8), 
                              Text(
                                'Add your first task to get started', // Pesan untuk menambahkan tugas
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade400, 
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: todoList.length, // Jumlah item dalam daftar
                          itemBuilder: (context, index) {
                            final isCompleted = todoList[index]['isCompleted']; // Status penyelesaian tugas
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300), 
                              margin: const EdgeInsets.symmetric(vertical: 6), // Margin vertikal
                              decoration: BoxDecoration(
                                color: Colors.white, 
                                borderRadius: BorderRadius.circular(16), 
                                border: Border.all(
                                  color: isCompleted 
                                      ? Colors.green.shade200 // Warna border jika selesai
                                      : Colors.grey.shade100, // Warna border jika tidak selesai
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isCompleted 
                                        ? Colors.green.shade100 // Warna bayangan jika selesai
                                        : Colors.grey.shade200, // Warna bayangan jika tidak selesai
                                    blurRadius: 8, 
                                    offset: const Offset(0, 4), 
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), 
                                leading: GestureDetector(
                                  onTap: () => toggleTaskCompletion(index), // Menangani klik untuk mengubah status penyelesaian
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200), 
                                    width: 24, 
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle, 
                                      color: isCompleted ? Colors.green : Colors.transparent, 
                                      border: Border.all(
                                        color: isCompleted ? Colors.green : Colors.grey.shade400, 
                                        width: 2,
                                      ),
                                    ),
                                    child: isCompleted
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 16,
                                          )
                                        : null, // Jika tidak selesai, tidak ada ikon
                                  ),
                                ),
                                title: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200), 
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600, 
                                    fontSize: 16,
                                    color: isCompleted ? Colors.grey.shade500 : Colors.black87, 
                                    decoration: isCompleted ? TextDecoration.lineThrough : null, // Garis tengah jika selesai
                                  ),
                                  child: Text(todoList[index]['title']), // Judul tugas
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min, // Ukuran minimum untuk trailing
                                  children: [
                                    // Kontainer untuk tombol edit
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple.shade50, 
                                        borderRadius: BorderRadius.circular(8), 
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.edit_outlined, // Ikon untuk mengedit
                                          color: Colors.deepPurple.shade600, 
                                          size: 20, // Ukuran ikon
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _controller.clear(); // Mengosongkan kontrol input
                                            _controller.text = todoList[index]['title']; // Mengisi kontrol input dengan judul tugas yang dipilih
                                            updateIndex = index; // Mengatur indeks untuk tugas yang sedang diedit
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8), 
                                    // Kontainer untuk tombol hapus
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50, 
                                        borderRadius: BorderRadius.circular(8), 
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.delete_outline, 
                                          color: Colors.red.shade600,
                                          size: 20, 
                                        ),
                                        onPressed: () {
                                          // Menampilkan dialog konfirmasi sebelum menghapus tugas
                                          showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return AlertDialog(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(15), // Sudut melengkung untuk dialog
                                                ),
                                                title: const Text('Hapus Tugas'), // Judul dialog
                                                content: const Text('Yakin hapus tugas?'), // Konten dialog
                                                actions: [
                                                  // Tombol untuk membatalkan penghapusan
                                                  TextButton(
                                                    onPressed: () => Navigator.of(context).pop(), // Menutup dialog
                                                    child: Text('Batal', style: TextStyle(color: Colors.grey.shade600)),
                                                  ),
                                                  // Tombol untuk menghapus tugas
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      deleteItem(index); // Memanggil fungsi untuk menghapus tugas
                                                      Navigator.of(context).pop(); // Menutup dialog setelah menghapus
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.red.shade600,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                    ),
                                                    child: const Text('Hapus', style: TextStyle(color: Colors.white)),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}