import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class Task {
  int? id;
  String title;
  int isDone;
  String createdAt;
  int orderIndex; // KODE BARU: Untuk menyimpan posisi drag & drop

  Task({
    this.id,
    required this.title,
    this.isDone = 0,
    required this.createdAt,
    this.orderIndex = 0, // Default 0
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isDone': isDone,
      'createdAt': createdAt,
      'orderIndex': orderIndex,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      isDone: map['isDone'],
      createdAt: map['createdAt'],
      orderIndex: map['orderIndex'] ?? 0,
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tasks_v2.db'); // Ganti nama DB untuk reset
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        isDone INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        orderIndex INTEGER NOT NULL
      )
    ''');
  }

  Future<int> insertTask(Task task) async {
    final db = await instance.database;
    return await db.insert('tasks', task.toMap());
  }

  Future<List<Task>> readAllTasks() async {
    final db = await instance.database;
    // KODE BARU: Urutkan berdasarkan orderIndex
    final result = await db.query('tasks', orderBy: 'orderIndex ASC');
    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<int> updateTask(Task task) async {
    final db = await instance.database;
    return db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  Future<int> deleteTask(int id) async {
    final db = await instance.database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }
}