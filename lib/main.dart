import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'export_helper.dart';

void main() {
  runApp(const TodoApp());
}

class TodoApp extends StatefulWidget {
  const TodoApp({super.key});

  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> {
  // Secara default ikuti pengaturan sistem HP
  ThemeMode _themeMode = ThemeMode.system;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  // Memuat tema yang tersimpan di HP
  Future<void> _loadTheme() async {
    _prefs = await SharedPreferences.getInstance();
    final savedTheme = _prefs?.getString('theme');
    setState(() {
      if (savedTheme == 'dark') _themeMode = ThemeMode.dark;
      else if (savedTheme == 'light') _themeMode = ThemeMode.light;
    });
  }

  // Menyimpan dan mengganti tema
  void toggleTheme() {
    setState(() {
      if (_themeMode == ThemeMode.light) {
        _themeMode = ThemeMode.dark;
        _prefs?.setString('theme', 'dark');
      } else {
        _themeMode = ThemeMode.light;
        _prefs?.setString('theme', 'light');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Modern Task',
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      ),
      home: TodoScreen(toggleTheme: toggleTheme),
    );
  }
}

class TodoScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  const TodoScreen({super.key, required this.toggleTheme});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  List<Task> _inProgressTasks = [];
  List<Task> _completedTasks = [];
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = true;

  // Set menyimpan ID tugas yang sedang proses animasi (agar tidak bisa diklik dobel)
  final Set<int> _animatingTasks = {};

  @override
  void initState() {
    super.initState();
    _refreshTasks();
  }

  Future<void> _refreshTasks() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.readAllTasks();

    setState(() {
      _inProgressTasks = data.where((t) => t.isDone == 0).toList();
      _completedTasks = data.where((t) => t.isDone == 1).toList();
      _isLoading = false;
    });
  }

  // 1. UPDATE FUNGSI INI
  Future<void> _addTask() async {
    if (_controller.text.isNotEmpty) {
      final task = Task(
        title: _controller.text,
        createdAt: DateTime.now().toIso8601String(),
        orderIndex: _inProgressTasks.length,
      );
      await DatabaseHelper.instance.insertTask(task);
      _controller.clear();
      _refreshTasks();
      if (mounted) Navigator.pop(context); // <- Cukup panggil pop di sini jika sukses
    }
  }

  // 2. UPDATE FUNGSI INI
  Future<void> _editTask(Task task, String newTitle) async {
    if (newTitle.isNotEmpty && newTitle != task.title) {
      task.title = newTitle;
      await DatabaseHelper.instance.updateTask(task);
      _refreshTasks();
      if (mounted) Navigator.pop(context); // <- Cukup panggil pop di sini jika sukses
    } else {
      if (mounted) Navigator.pop(context); // Tetap tutup meskipun tidak ada perubahan
    }
  }

  // Animasi saat tugas selesai/dikembalikan
  Future<void> _toggleTask(Task task) async {
    if (_animatingTasks.contains(task.id)) return; // Cegah double tap

    setState(() {
      _animatingTasks.add(task.id!);
      task.isDone = task.isDone == 0 ? 1 : 0; // Trigger coretan teks langsung
    });

    // Beri jeda 400ms agar user bisa melihat coretan sebelum tugas menghilang
    await Future.delayed(const Duration(milliseconds: 400));

    await DatabaseHelper.instance.updateTask(task);
    if(mounted) {
      setState(() {
        _animatingTasks.remove(task.id!);
      });
      _refreshTasks();
    }
  }

  Future<void> _deleteTask(int id) async {
    await DatabaseHelper.instance.deleteTask(id);
    _refreshTasks();
  }

  // Fungsi Drag and Drop Reorder
  void _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1; // Penyesuaian indeks Flutter

    setState(() {
      final item = _inProgressTasks.removeAt(oldIndex);
      _inProgressTasks.insert(newIndex, item);
    });

    // Update urutan di Database secara berurutan
    for (int i = 0; i < _inProgressTasks.length; i++) {
      _inProgressTasks[i].orderIndex = i;
      await DatabaseHelper.instance.updateTask(_inProgressTasks[i]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.toggleTheme,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            onSelected: (value) async {
              final allTasks = [..._inProgressTasks, ..._completedTasks];
              if (allTasks.isEmpty) return;
              if (value == 'pdf') await ExportHelper.exportToPDF(allTasks);
              else if (value == 'csv') await ExportHelper.exportToCSV(allTasks);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'pdf', child: Text('Export ke PDF')),
              const PopupMenuItem(value: 'csv', child: Text('Export ke CSV')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 20, top: 20, bottom: 10),
              child: _buildSectionHeader('In Progress', _inProgressTasks.length, Colors.orange),
            ),
          ),
          if (_inProgressTasks.isEmpty)
            SliverToBoxAdapter(child: Center(child: _buildEmptyState('No active tasks'))),

          // KODE BARU: ReorderableListView untuk Drag & Drop
          SliverReorderableList(
            itemCount: _inProgressTasks.length,
            itemBuilder: (context, index) {
              final task = _inProgressTasks[index];
              return _buildTaskCard(task, isDark, key: ValueKey(task.id), index: index);            },
            onReorder: _onReorder,
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 20, top: 30, bottom: 10),
              child: _buildSectionHeader('Completed', _completedTasks.length, Colors.green),
            ),
          ),
          if (_completedTasks.isEmpty)
            SliverToBoxAdapter(child: Center(child: _buildEmptyState('No completed tasks yet'))),

          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final task = _completedTasks[index];
                return _buildTaskCard(task, isDark, key: ValueKey(task.id));
              },
              childCount: _completedTasks.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)), // Ruang untuk FAB
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _controller.clear();
          _showTaskFormSheet(context, isEdit: false);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color badgeColor) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(count.toString(), style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildTaskCard(Task task, bool isDark, {required Key key, int? index}) {    final dateObj = DateTime.parse(task.createdAt);
    final formattedTime = DateFormat('dd MMM yyyy, HH:mm').format(dateObj);
    final isDone = task.isDone == 1;
    final isAnimating = _animatingTasks.contains(task.id);

    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      // Efek pudar transparan jika sedang dalam proses pindah status
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 350),
        opacity: isAnimating ? 0.0 : 1.0,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            leading: Checkbox(
              value: isDone,
              onChanged: (_) => _toggleTask(task),
              shape: const CircleBorder(),
            ),
            title: Text(
              task.title,
              style: TextStyle(
                decoration: isDone ? TextDecoration.lineThrough : null,
                color: isDone ? Colors.grey : (isDark ? Colors.white : Colors.black87),
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
                formattedTime,
                style: const TextStyle(fontSize: 12, color: Colors.grey)
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tombol Edit (Hanya tampil jika belum selesai)
                if (!isDone)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                    onPressed: () {
                      _controller.text = task.title;
                      _showTaskFormSheet(context, isEdit: true, taskToEdit: task);
                    },
                  ),
                // Tombol Hapus dengan Konfirmasi
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _confirmDelete(task),
                ),
                // Icon penanda bisa di-drag (Hanya di In Progress)
                if (!isDone && index != null) // Pastikan index tidak null
                  ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(message, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
    );
  }

  // KODE BARU: Modal Dialog Konfirmasi Hapus
  void _confirmDelete(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Tugas?'),
        content: Text('Apakah Anda yakin ingin menghapus "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              _deleteTask(task.id!);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Modal yang bisa dipakai untuk Tambah maupun Edit
  void _showTaskFormSheet(BuildContext context, {required bool isEdit, Task? taskToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                isEdit ? "Edit Task" : "Add Task",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              onSubmitted: (_) {
                if (isEdit) _editTask(taskToEdit!, _controller.text);
                else _addTask();
              },
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: () {
                if (isEdit) _editTask(taskToEdit!, _controller.text);
                else _addTask();
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: Text(isEdit ? "Simpan Perubahan" : "Create Task"),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}