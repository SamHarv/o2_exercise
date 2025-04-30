// Expansion tiles with list tiles
import 'package:flutter/material.dart';
import 'package:o2_exercise/data/models/exercise_model.dart';
import 'package:o2_exercise/data/models/set_model.dart';
import 'package:o2_exercise/ui/widgets/exercise_input_widget.dart';
import 'package:o2_exercise/utils/constants.dart';
import 'package:uuid/uuid.dart';

import '../../data/database/db_helper.dart';
import '../../data/models/session_model.dart';

class SessionView extends StatefulWidget {
  final SessionModel session;
  const SessionView({super.key, required this.session});

  @override
  State<SessionView> createState() => _SessionViewState();
}

class _SessionViewState extends State<SessionView> {
  final db = DatabaseHelper.instance;
  late final TextEditingController _sessionNameController;

  @override
  void initState() {
    _sessionNameController = TextEditingController(text: widget.session.name);
    super.initState();
  }

  @override
  void dispose() {
    _sessionNameController.dispose();
    super.dispose();
  }

  String repRange(List<SetModel> sets) {
    if (sets.isEmpty) return '0';
    final min = sets.map((s) => s.reps).reduce((a, b) => a < b ? a : b);
    final max = sets.map((s) => s.reps).reduce((a, b) => a > b ? a : b);
    return min == max ? '$min' : '$min-$max';
  }

  @override
  Widget build(BuildContext context) {
    final mediaWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: black,
      appBar: AppBar(
        centerTitle: false,
        title: TextField(
          controller: _sessionNameController,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: white, fontSize: 20),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Session Name',
            hintStyle: TextStyle(color: Colors.grey, fontSize: 20),
          ),
          onChanged:
              (value) => setState(() {
                widget.session.name = value;
                db.updateSession(widget.session);
              }),
        ),
        automaticallyImplyLeading: true,
        backgroundColor: black,
        foregroundColor: white,
      ),
      body:
          widget.session.exercises.isEmpty
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No Exercises Found.',
                    style: TextStyle(color: white),
                  ),
                ),
              )
              : Theme(
                data: ThemeData(canvasColor: Colors.grey[900]),
                child: ReorderableListView.builder(
                  itemCount: widget.session.exercises.length,
                  onReorder: (oldIndex, newIndex) {
                    // Handle the reordering similar to sessions
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }

                    setState(() {
                      // First update the local model
                      final exercise = widget.session.exercises.removeAt(
                        oldIndex,
                      );
                      widget.session.exercises.insert(newIndex, exercise);

                      // Then update the database
                      List<String> exerciseIds =
                          widget.session.exercises.map((e) => e.id).toList();
                      db
                          .reorderExercisesInSession(
                            widget.session.id,
                            exerciseIds,
                          )
                          .then((_) {
                            // After the database operation completes, refresh the UI
                            setState(() {});
                          });
                    });
                  },
                  itemBuilder: (context, index) {
                    final exercise = widget.session.exercises[index];
                    final exerciseNameController = TextEditingController(
                      text: exercise.name,
                    );

                    return Dismissible(
                      key: Key(exercise.id),
                      direction: DismissDirection.endToStart,

                      confirmDismiss: (direction) async {
                        return await showDialog<bool>(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(32.0),
                                      side: const BorderSide(
                                        color: white,
                                        width: 2.0,
                                      ),
                                    ),
                                    backgroundColor: black,
                                    title: const Text(
                                      'Delete Exercise',
                                      style: TextStyle(color: white),
                                    ),
                                    content: const Text(
                                      'Are you sure you want to delete this exercise?',
                                      style: TextStyle(color: white),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop(true);
                                        },
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed:
                                            () => Navigator.of(
                                              context,
                                            ).pop(false),
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(color: white),
                                        ),
                                      ),
                                    ],
                                  ),
                            ) ??
                            false;
                      },
                      onDismissed: (direction) {
                        // Remove from local state first (optimistic update)

                        setState(() {
                          widget.session.exercises.removeAt(index);
                          db.deleteExercise(exercise.id).then((_) {
                            // After the database operation completes, refresh the UI
                            setState(() {});
                          });
                        });
                      },
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                      ),
                      child: ExpansionTile(
                        key: Key(exercise.id),
                        title: Text(
                          exercise.name,
                          style: TextStyle(color: white, fontSize: 16),
                        ),
                        subtitle: Text(
                          '${exercise.sets.length} sets | ${repRange(exercise.sets)} reps',
                          style: TextStyle(color: Colors.grey),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                TextField(
                                  controller: exerciseNameController,
                                  textCapitalization: TextCapitalization.words,
                                  style: const TextStyle(
                                    color: white,
                                    fontSize: 18,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Exercise Name',
                                    hintStyle: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 18,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    exercise.name = value;
                                    db.updateExercise(exercise);
                                  },
                                  onEditingComplete: () => setState(() {}),
                                ),

                                for (var s in exercise.sets)
                                  Dismissible(
                                    key: Key(s.id),
                                    direction: DismissDirection.endToStart,
                                    onDismissed: (direction) {
                                      // Remove from local state first (optimistic update)
                                      setState(() {
                                        exercise.sets.remove(s);
                                        db.deleteSet(s.id).then((_) {
                                          // After the database operation completes, refresh the UI
                                          setState(() {});
                                        });
                                      });
                                    },
                                    background: Container(
                                      color: Colors.red,
                                      alignment: Alignment.centerRight,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 16.0,
                                        ),
                                        child: const Icon(
                                          Icons.delete,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          ExerciseInputWidget(
                                            value: s.reps,
                                            suffix: 'reps',
                                            width: mediaWidth,
                                            onTapPlus: () {
                                              s.reps++;
                                              db.updateExercise(exercise).then((
                                                _,
                                              ) {
                                                setState(() {});
                                              });
                                            },
                                            onLongPressPlus: () {
                                              s.reps += 10;
                                              db.updateExercise(exercise).then((
                                                _,
                                              ) {
                                                setState(() {});
                                              });
                                            },
                                            onTapMinus: () {
                                              if (s.reps < 1) return;
                                              s.reps--;
                                              db.updateExercise(exercise).then((
                                                _,
                                              ) {
                                                setState(() {});
                                              });
                                            },
                                            onLongPressMinus: () {
                                              if (s.reps < 10) return;
                                              s.reps -= 10;
                                              db.updateExercise(exercise).then((
                                                _,
                                              ) {
                                                setState(() {});
                                              });
                                            },
                                          ),
                                          ExerciseInputWidget(
                                            value: s.weight,
                                            suffix: 'kg',
                                            width: mediaWidth,
                                            onTapPlus: () {
                                              s.weight++;
                                              db.updateExercise(exercise).then((
                                                _,
                                              ) {
                                                setState(() {});
                                              });
                                            },
                                            onLongPressPlus: () {
                                              s.weight += 10;
                                              db.updateExercise(exercise).then((
                                                _,
                                              ) {
                                                setState(() {});
                                              });
                                            },
                                            onTapMinus: () {
                                              if (s.weight < 1) return;
                                              s.weight--;
                                              db.updateExercise(exercise).then((
                                                _,
                                              ) {
                                                setState(() {});
                                              });
                                            },
                                            onLongPressMinus: () {
                                              if (s.weight < 10) return;
                                              s.weight -= 10;
                                              db.updateExercise(exercise).then((
                                                _,
                                              ) {
                                                setState(() {});
                                              });
                                            },
                                          ),

                                          ExerciseInputWidget(
                                            value: s.restSeconds,
                                            suffix: 's',
                                            width: mediaWidth,
                                            onTapPlus: () {
                                              s.restSeconds += 5;
                                              db.updateExercise(exercise).then((
                                                _,
                                              ) {
                                                setState(() {});
                                              });
                                            },
                                            onLongPressPlus: () {
                                              s.restSeconds += 30;
                                              db.updateExercise(exercise).then((
                                                _,
                                              ) {
                                                setState(() {});
                                              });
                                            },
                                            onTapMinus: () {
                                              if (s.restSeconds < 5) return;
                                              s.restSeconds -= 5;
                                              db.updateExercise(exercise).then((
                                                _,
                                              ) {
                                                setState(() {});
                                              });
                                            },
                                            onLongPressMinus: () {
                                              if (s.restSeconds < 30) return;
                                              s.restSeconds -= 30;
                                              db.updateExercise(exercise).then((
                                                _,
                                              ) {
                                                setState(() {});
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                // Add a new set
                                InkWell(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(4),
                                  ),
                                  onTap: () {
                                    final newSetId = const Uuid().v4();
                                    final newSet = SetModel(
                                      id: newSetId,
                                      exerciseId: exercise.id,
                                      order: exercise.sets.length,
                                      reps: 0,
                                      weight: 0,
                                      restSeconds: 0,
                                    );
                                    exercise.sets.add(newSet);
                                    db.updateExercise(exercise).then((_) {
                                      setState(() {});
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(4),
                                      ),
                                    ),
                                    width: mediaWidth - 32,
                                    child: Icon(Icons.add, color: white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        // Add your onTap, onLongPress handlers here
                      ),
                    );
                  },
                ),
              ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          final newExerciseId = const Uuid().v4();
          final newExercise = ExerciseModel(
            id: newExerciseId,
            name: 'New Exercise',
            sets: [],
            position: widget.session.exercises.length,
          );
          widget.session.exercises.add(newExercise);
          List<String> exerciseIds =
              widget.session.exercises.map((e) => e.id).toList();
          db.reorderExercisesInSession(widget.session.id, exerciseIds).then((
            _,
          ) {
            setState(() {});
          });
          db.createExercise(newExercise).then((_) {
            setState(() {});
          });
          db.updateSession(widget.session).then((_) {
            setState(() {});
          });
        },
      ),
    );
  }
}
