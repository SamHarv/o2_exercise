import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import '../models/exercise_model.dart';
import '../models/session_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('exercise_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';

    // Create exercises table with position field
    await db.execute('''
    CREATE TABLE exercises (
      id $idType,
      name $textType,
      sets $integerType,
      reps $integerType,
      weightKG $integerType,
      restSeconds $integerType,
      position $integerType
    )
    ''');

    // Create sessions table with position field
    await db.execute('''
    CREATE TABLE sessions (
      id $idType,
      name $textType,
      position $integerType DEFAULT 0
    )
    ''');

    // Create session_exercises table (junction table for many-to-many relationship)
    // Added position field to track exercise order within a session
    await db.execute('''
    CREATE TABLE session_exercises (
      session_id TEXT NOT NULL,
      exercise_id TEXT NOT NULL,
      position INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (session_id, exercise_id),
      FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE,
      FOREIGN KEY (exercise_id) REFERENCES exercises (id) ON DELETE CASCADE
    )
    ''');
  }

  // CRUD operations for ExerciseModel

  Future<String> createExercise(ExerciseModel exercise) async {
    final db = await instance.database;
    await db.insert('exercises', exercise.toJson());
    return exercise.id;
  }

  Future<ExerciseModel> readExercise(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'exercises',
      columns: [
        'id',
        'name',
        'sets',
        'reps',
        'weightKG',
        'restSeconds',
        'position',
      ],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return ExerciseModel.fromJson(maps.first);
    } else {
      throw Exception('Exercise with ID $id not found');
    }
  }

  Future<List<ExerciseModel>> readAllExercises() async {
    final db = await instance.database;
    // Order exercises by their position
    final result = await db.query('exercises', orderBy: 'position ASC');
    return result.map((json) => ExerciseModel.fromJson(json)).toList();
  }

  Future<int> updateExercise(ExerciseModel exercise) async {
    final db = await instance.database;
    return db.update(
      'exercises',
      exercise.toJson(),
      where: 'id = ?',
      whereArgs: [exercise.id],
    );
  }

  Future<int> deleteExercise(String id) async {
    final db = await instance.database;
    return await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
  }

  // CRUD operations for SessionModel

  Future<String> createSession(SessionModel session) async {
    final db = await instance.database;

    // Get the next position value
    final maxPosResult = await db.rawQuery(
      'SELECT MAX(position) as maxPos FROM sessions',
    );
    final int nextPos = (maxPosResult.first['maxPos'] as int? ?? -1) + 1;

    // Start a transaction to ensure data consistency
    await db.transaction((txn) async {
      // Insert session with position
      await txn.insert('sessions', {
        'id': session.id,
        'name': session.name,
        'position': nextPos,
      });

      // Insert exercise relationships
      for (var i = 0; i < session.exercises.length; i++) {
        var exercise = session.exercises[i];

        // Ensure the exercise exists in the exercises table
        await txn.insert(
          'exercises',
          exercise.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Create relationship in junction table with position
        await txn.insert('session_exercises', {
          'session_id': session.id,
          'exercise_id': exercise.id,
          'position': i, // Use index as position in session
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });

    return session.id;
  }

  Future<SessionModel> readSession(String id) async {
    final db = await instance.database;

    // Get session data
    final sessionMaps = await db.query(
      'sessions',
      columns: ['id', 'name', 'position'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (sessionMaps.isEmpty) {
      throw Exception('Session with ID $id not found');
    }

    // Get all exercise IDs associated with this session, ordered by position in junction table
    final exerciseRelations = await db.query(
      'session_exercises',
      columns: ['exercise_id', 'position'],
      where: 'session_id = ?',
      whereArgs: [id],
      orderBy: 'position ASC',
    );

    final exerciseIds =
        exerciseRelations.map((rel) => rel['exercise_id'] as String).toList();

    // Early return if no exercises
    if (exerciseIds.isEmpty) {
      return SessionModel(
        id: sessionMaps.first['id'] as String,
        name: sessionMaps.first['name'] as String,
        position: sessionMaps.first['position'] as int,
        exercises: [],
      );
    }

    // Create a map to maintain the correct order of exercises
    final exercisesMap = <String, ExerciseModel>{};

    // Get all exercises
    final exerciseMaps = await db.query(
      'exercises',
      where: 'id IN (${List.filled(exerciseIds.length, '?').join(',')})',
      whereArgs: exerciseIds,
    );

    // Create a map of exercise id to exercise model
    for (var exerciseMap in exerciseMaps) {
      final exercise = ExerciseModel.fromJson(exerciseMap);
      exercisesMap[exercise.id] = exercise;
    }

    // Create ordered list of exercises using the order from the junction table
    final orderedExercises =
        exerciseIds
            .map((id) => exercisesMap[id])
            .whereType<ExerciseModel>()
            .toList();

    // Create session with exercises in correct order
    return SessionModel(
      id: sessionMaps.first['id'] as String,
      name: sessionMaps.first['name'] as String,
      position: sessionMaps.first['position'] as int,
      exercises: orderedExercises,
    );
  }

  Future<List<SessionModel>> readAllSessions() async {
    final db = await instance.database;

    // Get all sessions ordered by their position
    final sessionMaps = await db.query('sessions', orderBy: 'position ASC');

    if (sessionMaps.isEmpty) return [];

    // Create a list to hold the session models
    List<SessionModel> sessions = [];

    // For each session, get its exercises
    for (var sessionMap in sessionMaps) {
      final sessionId = sessionMap['id'] as String;

      // Get exercise IDs for this session
      final exerciseRelations = await db.query(
        'session_exercises',
        columns: ['exercise_id'],
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'position ASC',
      );

      List<ExerciseModel> exercises = [];

      if (exerciseRelations.isNotEmpty) {
        final exerciseIds =
            exerciseRelations
                .map((rel) => rel['exercise_id'] as String)
                .toList();

        // Get exercises data
        final exerciseMaps = await db.query(
          'exercises',
          where: 'id IN (${List.filled(exerciseIds.length, '?').join(',')})',
          whereArgs: exerciseIds,
        );

        // Create a map of exercise id to exercise model
        final exercisesMap = <String, ExerciseModel>{};
        for (var exerciseMap in exerciseMaps) {
          final exercise = ExerciseModel.fromJson(exerciseMap);
          exercisesMap[exercise.id] = exercise;
        }

        // Create ordered list of exercises
        exercises =
            exerciseIds
                .map((id) => exercisesMap[id])
                .whereType<ExerciseModel>()
                .toList();
      }

      // Create session with its exercises
      sessions.add(
        SessionModel(
          id: sessionId,
          name: sessionMap['name'] as String,
          position: sessionMap['position'] as int,
          exercises: exercises,
        ),
      );
    }

    return sessions;
  }

  Future<int> updateSession(SessionModel session) async {
    final db = await instance.database;

    // Start a transaction
    int result = 0;
    await db.transaction((txn) async {
      // Update session data
      result = await txn.update(
        'sessions',
        {'name': session.name, 'position': session.position},
        where: 'id = ?',
        whereArgs: [session.id],
      );

      // Delete all existing exercise relationships
      await txn.delete(
        'session_exercises',
        where: 'session_id = ?',
        whereArgs: [session.id],
      );

      // Insert updated exercise relationships
      for (var i = 0; i < session.exercises.length; i++) {
        var exercise = session.exercises[i];

        // Ensure exercise exists
        await txn.insert(
          'exercises',
          exercise.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Add relationship with position
        await txn.insert('session_exercises', {
          'session_id': session.id,
          'exercise_id': exercise.id,
          'position': i, // Use index as position in session
        });
      }
    });

    return result;
  }

  Future<int> deleteSession(String id) async {
    final db = await instance.database;

    // Delete session and its relations (relations will be deleted automatically due to CASCADE)
    return await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  // Add or remove a single exercise from a session
  Future<void> addExerciseToSession(
    String sessionId,
    ExerciseModel exercise,
  ) async {
    final db = await instance.database;

    await db.transaction((txn) async {
      // Ensure exercise exists
      await txn.insert(
        'exercises',
        exercise.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Get the current max position for exercises in this session
      final maxPosResult = await txn.rawQuery(
        'SELECT MAX(position) as maxPos FROM session_exercises WHERE session_id = ?',
        [sessionId],
      );
      final int maxPos = maxPosResult.first['maxPos'] as int? ?? -1;

      // Add relationship with the next position value
      await txn.insert('session_exercises', {
        'session_id': sessionId,
        'exercise_id': exercise.id,
        'position': maxPos + 1, // Add at the end
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> removeExerciseFromSession(
    String sessionId,
    String exerciseId,
  ) async {
    final db = await instance.database;

    await db.delete(
      'session_exercises',
      where: 'session_id = ? AND exercise_id = ?',
      whereArgs: [sessionId, exerciseId],
    );

    // Optionally, reorder remaining exercises to close gaps
    await reorderExercisesInSession(sessionId);
  }

  // Methods for reordering exercises within a session
  Future<void> reorderExercisesInSession(
    String sessionId, [
    List<String>? exerciseIdsInOrder,
  ]) async {
    final db = await instance.database;

    await db.transaction((txn) async {
      List<String> exerciseIds;

      if (exerciseIdsInOrder == null || exerciseIdsInOrder.isEmpty) {
        // If no order specified, get current exercises in their current order
        final exerciseRelations = await txn.query(
          'session_exercises',
          columns: ['exercise_id'],
          where: 'session_id = ?',
          whereArgs: [sessionId],
          orderBy: 'position ASC',
        );

        exerciseIds =
            exerciseRelations
                .map((rel) => rel['exercise_id'] as String)
                .toList();

        if (exerciseIds.isEmpty) return; // No exercises to reorder
      } else {
        exerciseIds = exerciseIdsInOrder;
      }

      // Update positions for each exercise
      for (var i = 0; i < exerciseIds.length; i++) {
        final exerciseId = exerciseIds[i];

        await txn.update(
          'session_exercises',
          {'position': i},
          where: 'session_id = ? AND exercise_id = ?',
          whereArgs: [sessionId, exerciseId],
        );
      }
    });
  }

  // Method to update the positions of sessions
  Future<void> reorderSessions([List<String>? sessionIdsInOrder]) async {
    final db = await instance.database;

    await db.transaction((txn) async {
      List<String> sessionIds;

      if (sessionIdsInOrder == null || sessionIdsInOrder.isEmpty) {
        // If no order specified, get current sessions in their current order
        final sessionMaps = await txn.query(
          'sessions',
          columns: ['id'],
          orderBy: 'position ASC',
        );

        sessionIds = sessionMaps.map((s) => s['id'] as String).toList();

        if (sessionIds.isEmpty) return; // No sessions to reorder
      } else {
        sessionIds = sessionIdsInOrder;
      }

      // Update positions for each session
      for (var i = 0; i < sessionIds.length; i++) {
        final sessionId = sessionIds[i];

        await txn.update(
          'sessions',
          {'position': i},
          where: 'id = ?',
          whereArgs: [sessionId],
        );
      }
    });
  }

  // Methods to handle next available position
  Future<int> getNextExercisePosition() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT MAX(position) as maxPos FROM exercises',
    );
    final int maxPos = result.first['maxPos'] as int? ?? -1;
    return maxPos + 1;
  }

  Future<int> getNextSessionPosition() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT MAX(position) as maxPos FROM sessions',
    );
    final int maxPos = result.first['maxPos'] as int? ?? -1;
    return maxPos + 1;
  }

  // Close database
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
