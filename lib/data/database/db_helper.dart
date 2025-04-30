import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import '../models/exercise_model.dart';
import '../models/session_model.dart';
import '../models/set_model.dart';

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

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
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

    // Create sets table to store individual sets for exercises
    await db.execute('''
    CREATE TABLE sets (
      id $idType,
      exercise_id TEXT NOT NULL,
      order_num $integerType,
      reps $integerType,
      weight $integerType,
      rest $integerType,
      FOREIGN KEY (exercise_id) REFERENCES exercises (id) ON DELETE CASCADE
    )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Create sets table if upgrading from version 1
      await db.execute('''
      CREATE TABLE sets (
        id TEXT PRIMARY KEY,
        exercise_id TEXT NOT NULL,
        order_num INTEGER NOT NULL,
        reps INTEGER NOT NULL,
        weight INTEGER NOT NULL,
        rest INTEGER NOT NULL,
        FOREIGN KEY (exercise_id) REFERENCES exercises (id) ON DELETE CASCADE
      )
      ''');

      // Modify exercises table structure to remove columns moved to sets
      await db.execute('''
      CREATE TABLE exercises_new (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        position INTEGER NOT NULL
      )
      ''');

      // Copy relevant data from old table to new table
      await db.execute('''
      INSERT INTO exercises_new (id, name, position)
      SELECT id, name, position FROM exercises
      ''');

      // Drop old table and rename new one
      await db.execute('DROP TABLE exercises');
      await db.execute('ALTER TABLE exercises_new RENAME TO exercises');
    }
  }

  // CRUD operations for ExerciseModel

  Future<String> createExercise(ExerciseModel exercise) async {
    final db = await instance.database;

    await db.transaction((txn) async {
      // Insert exercise
      await txn.insert('exercises', {
        'id': exercise.id,
        'name': exercise.name,
        'position': exercise.position,
      });

      // Insert sets for this exercise
      for (var s in exercise.sets) {
        await txn.insert('sets', {
          'id': s.id,
          'exercise_id': exercise.id,
          'order_num': s.order,
          'reps': s.reps,
          'weight': s.weight,
          'rest': s.restSeconds,
        });
      }
    });

    return exercise.id;
  }

  Future<ExerciseModel> readExercise(String id) async {
    final db = await instance.database;

    // Get exercise data
    final exerciseMaps = await db.query(
      'exercises',
      columns: ['id', 'name', 'position'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (exerciseMaps.isEmpty) {
      throw Exception('Exercise with ID $id not found');
    }

    // Get sets for this exercise
    final setMaps = await db.query(
      'sets',
      where: 'exercise_id = ?',
      whereArgs: [id],
      orderBy: 'order_num ASC',
    );

    // Convert maps to SetModel objects
    final sets =
        setMaps
            .map(
              (setMap) => SetModel(
                id: setMap['id'] as String,
                exerciseId: setMap['exercise_id'] as String,
                order: setMap['order_num'] as int,
                reps: setMap['reps'] as int,
                weight: setMap['weight'] as int,
                restSeconds: setMap['rest'] as int,
              ),
            )
            .toList();

    // Create and return the exercise with its sets
    return ExerciseModel(
      id: exerciseMaps.first['id'] as String,
      name: exerciseMaps.first['name'] as String,
      position: exerciseMaps.first['position'] as int,
      sets: sets,
    );
  }

  Future<List<ExerciseModel>> readAllExercises() async {
    final db = await instance.database;

    // Get all exercises ordered by position
    final exerciseMaps = await db.query('exercises', orderBy: 'position ASC');

    if (exerciseMaps.isEmpty) return [];

    // Create a list to hold exercise models
    List<ExerciseModel> exercises = [];

    // For each exercise, get its sets
    for (var exerciseMap in exerciseMaps) {
      final exerciseId = exerciseMap['id'] as String;

      // Get sets for this exercise
      final setMaps = await db.query(
        'sets',
        where: 'exercise_id = ?',
        whereArgs: [exerciseId],
        orderBy: 'order_num ASC',
      );

      // Convert maps to SetModel objects
      final sets =
          setMaps
              .map(
                (setMap) => SetModel(
                  id: setMap['id'] as String,
                  exerciseId: setMap['exercise_id'] as String,
                  order: setMap['order_num'] as int,
                  reps: setMap['reps'] as int,
                  weight: setMap['weight'] as int,
                  restSeconds: setMap['rest'] as int,
                ),
              )
              .toList();

      // Create exercise with its sets
      exercises.add(
        ExerciseModel(
          id: exerciseId,
          name: exerciseMap['name'] as String,
          position: exerciseMap['position'] as int,
          sets: sets,
        ),
      );
    }

    return exercises;
  }

  Future<int> updateExercise(ExerciseModel exercise) async {
    final db = await instance.database;

    int result = 0;
    await db.transaction((txn) async {
      // Update exercise data
      result = await txn.update(
        'exercises',
        {'name': exercise.name, 'position': exercise.position},
        where: 'id = ?',
        whereArgs: [exercise.id],
      );

      // Delete existing sets
      await txn.delete(
        'sets',
        where: 'exercise_id = ?',
        whereArgs: [exercise.id],
      );

      // Insert updated sets
      for (var s in exercise.sets) {
        await txn.insert('sets', {
          'id': s.id,
          'exercise_id': exercise.id,
          'order_num': s.order,
          'reps': s.reps,
          'weight': s.weight,
          'rest': s.restSeconds,
        });
      }
    });

    return result;
  }

  Future<int> deleteExercise(String id) async {
    final db = await instance.database;

    // Delete exercise and its sets (sets will be deleted automatically due to CASCADE)
    return await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
  }

  // CRUD operations for SetModel

  Future<String> createSet(SetModel s) async {
    final db = await instance.database;
    await db.insert('sets', {
      'id': s.id,
      'exercise_id': s.exerciseId,
      'order_num': s.order,
      'reps': s.reps,
      'weight': s.weight,
      'rest': s.restSeconds,
    });
    return s.id;
  }

  Future<SetModel> readSet(String id) async {
    final db = await instance.database;
    final maps = await db.query('sets', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      return SetModel(
        id: maps.first['id'] as String,
        exerciseId: maps.first['exercise_id'] as String,
        order: maps.first['order_num'] as int,
        reps: maps.first['reps'] as int,
        weight: maps.first['weight'] as int,
        restSeconds: maps.first['rest'] as int,
      );
    } else {
      throw Exception('Set with ID $id not found');
    }
  }

  Future<List<SetModel>> readSetsForExercise(String exerciseId) async {
    final db = await instance.database;
    final result = await db.query(
      'sets',
      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
      orderBy: 'order_num ASC',
    );

    return result
        .map(
          (json) => SetModel(
            id: json['id'] as String,
            exerciseId: json['exercise_id'] as String,
            order: json['order_num'] as int,
            reps: json['reps'] as int,
            weight: json['weight'] as int,
            restSeconds: json['rest'] as int,
          ),
        )
        .toList();
  }

  Future<int> updateSet(SetModel s) async {
    final db = await instance.database;
    return db.update(
      'sets',
      {
        'exercise_id': s.exerciseId,
        'order_num': s.order,
        'reps': s.reps,
        'weight': s.weight,
        'rest': s.restSeconds,
      },
      where: 'id = ?',
      whereArgs: [s.id],
    );
  }

  Future<int> deleteSet(String id) async {
    final db = await instance.database;
    return await db.delete('sets', where: 'id = ?', whereArgs: [id]);
  }

  // CRUD operations for SessionModel (modified to include sets in exercises)

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
        await txn.insert('exercises', {
          'id': exercise.id,
          'name': exercise.name,
          'position': exercise.position,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        // Create relationship in junction table with position
        await txn.insert('session_exercises', {
          'session_id': session.id,
          'exercise_id': exercise.id,
          'position': i, // Use index as position in session
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        // Insert sets for this exercise
        for (var s in exercise.sets) {
          await txn.insert('sets', {
            'id': s.id,
            'exercise_id': exercise.id,
            'order_num': s.order,
            'reps': s.reps,
            'weight': s.weight,
            'rest': s.restSeconds,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
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

    // For each exercise, get its data and sets
    for (var exerciseId in exerciseIds) {
      // Get exercise data
      final exerciseMaps = await db.query(
        'exercises',
        where: 'id = ?',
        whereArgs: [exerciseId],
      );

      if (exerciseMaps.isNotEmpty) {
        // Get sets for this exercise
        final setMaps = await db.query(
          'sets',
          where: 'exercise_id = ?',
          whereArgs: [exerciseId],
          orderBy: 'order_num ASC',
        );

        // Convert maps to SetModel objects
        final sets =
            setMaps
                .map(
                  (setMap) => SetModel(
                    id: setMap['id'] as String,
                    exerciseId: setMap['exercise_id'] as String,
                    order: setMap['order_num'] as int,
                    reps: setMap['reps'] as int,
                    weight: setMap['weight'] as int,
                    restSeconds: setMap['rest'] as int,
                  ),
                )
                .toList();

        // Create exercise with its sets
        final exercise = ExerciseModel(
          id: exerciseMaps.first['id'] as String,
          name: exerciseMaps.first['name'] as String,
          position: exerciseMaps.first['position'] as int,
          sets: sets,
        );

        exercisesMap[exerciseId] = exercise;
      }
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

        // For each exercise, get its data and sets
        for (var exerciseId in exerciseIds) {
          // Get exercise data
          final exerciseMaps = await db.query(
            'exercises',
            where: 'id = ?',
            whereArgs: [exerciseId],
          );

          if (exerciseMaps.isNotEmpty) {
            // Get sets for this exercise
            final setMaps = await db.query(
              'sets',
              where: 'exercise_id = ?',
              whereArgs: [exerciseId],
              orderBy: 'order_num ASC',
            );

            // Convert maps to SetModel objects
            final sets =
                setMaps
                    .map(
                      (setMap) => SetModel(
                        id: setMap['id'] as String,
                        exerciseId: setMap['exercise_id'] as String,
                        order: setMap['order_num'] as int,
                        reps: setMap['reps'] as int,
                        weight: setMap['weight'] as int,
                        restSeconds: setMap['rest'] as int,
                      ),
                    )
                    .toList();

            // Create exercise with its sets
            exercises.add(
              ExerciseModel(
                id: exerciseMaps.first['id'] as String,
                name: exerciseMaps.first['name'] as String,
                position: exerciseMaps.first['position'] as int,
                sets: sets,
              ),
            );
          }
        }
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
      // First, get the current session to preserve its position
      final currentSessionQuery = await txn.query(
        'sessions',
        columns: ['position'],
        where: 'id = ?',
        whereArgs: [session.id],
      );

      // If the session exists, get its current position
      int currentPosition = 0;
      if (currentSessionQuery.isNotEmpty) {
        currentPosition = currentSessionQuery.first['position'] as int;
      }

      // Update session data while preserving the original position
      result = await txn.update(
        'sessions',
        {'name': session.name, 'position': currentPosition},
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
        await txn.insert('exercises', {
          'id': exercise.id,
          'name': exercise.name,
          'position': exercise.position,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        // Add relationship with position
        await txn.insert('session_exercises', {
          'session_id': session.id,
          'exercise_id': exercise.id,
          'position': i, // Use index as position in session
        });

        // Delete existing sets for this exercise
        await txn.delete(
          'sets',
          where: 'exercise_id = ?',
          whereArgs: [exercise.id],
        );

        // Insert updated sets
        for (var s in exercise.sets) {
          await txn.insert('sets', {
            'id': s.id,
            'exercise_id': exercise.id,
            'order_num': s.order,
            'reps': s.reps,
            'weight': s.weight,
            'rest': s.restSeconds,
          });
        }
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
      await txn.insert('exercises', {
        'id': exercise.id,
        'name': exercise.name,
        'position': exercise.position,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

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

      // Insert sets for this exercise
      for (var s in exercise.sets) {
        await txn.insert('sets', {
          'id': s.id,
          'exercise_id': exercise.id,
          'order_num': s.order,
          'reps': s.reps,
          'weight': s.weight,
          'rest': s.restSeconds,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
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

  // Get the next available order number for sets in an exercise
  // Future<int> getNextSetOrderForExercise(String exerciseId) async {
  //   final db = await instance.database;
  //   final result = await db.rawQuery(
  //     'SELECT MAX(order_num) as maxOrder FROM sets WHERE exercise_id = ?',
  //     [exerciseId],
  //   );
  //   final int maxOrder = result.first['maxOrder'] as int? ?? -1;
  //   return maxOrder + 1;
  // }

  // Close database
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
