import 'package:horas_hombre_mobile/models/pending_attendance.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AttendanceQueueRepository {
  Database? _db;

  Future<Database> _database() async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, 'attendance_queue.db'),
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE pending_attendance (
            offline_event_id TEXT PRIMARY KEY,
            user_id INTEGER NOT NULL,
            employee_name TEXT,
            attendance_type TEXT NOT NULL,
            attendance_date TEXT NOT NULL,
            attendance_time TEXT NOT NULL,
            location_id INTEGER,
            location_name TEXT,
            device_id TEXT NOT NULL,
            status TEXT NOT NULL,
            server_message TEXT,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
    _db = db;
    return db;
  }

  Future<void> enqueue(PendingAttendance item) async {
    final db = await _database();
    await db.insert(
      'pending_attendance',
      item.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<PendingAttendance>> all() async {
    final db = await _database();
    final rows = await db.query(
      'pending_attendance',
      orderBy: 'attendance_date ASC, attendance_time ASC, created_at ASC',
    );
    return rows.map(PendingAttendance.fromDbMap).toList();
  }

  Future<PendingAttendance?> find(String offlineEventId) async {
    final db = await _database();
    final rows = await db.query(
      'pending_attendance',
      where: 'offline_event_id = ?',
      whereArgs: [offlineEventId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PendingAttendance.fromDbMap(rows.first);
  }

  Future<void> mark(String offlineEventId, String status, String? message) async {
    final db = await _database();
    await db.update(
      'pending_attendance',
      {
        'status': status,
        'server_message': message,
      },
      where: 'offline_event_id = ?',
      whereArgs: [offlineEventId],
    );
  }

  Future<void> delete(String offlineEventId) async {
    final db = await _database();
    await db.delete(
      'pending_attendance',
      where: 'offline_event_id = ?',
      whereArgs: [offlineEventId],
    );
  }
}
