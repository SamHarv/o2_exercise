// Expansion tiles with list tiles
import 'package:flutter/material.dart';
import 'package:o2_exercise/data/models/exercise_model.dart';
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
                          '${exercise.sets} x ${exercise.reps} | ${exercise.weightKG}kg | ${exercise.restSeconds}s rest',
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
                                SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        ExerciseInputWidget(
                                          value: exercise.sets,
                                          suffix: 'sets',
                                          width: mediaWidth,
                                          onTapPlus: () {
                                            exercise.sets++;
                                            db.updateExercise(exercise).then((
                                              _,
                                            ) {
                                              setState(() {});
                                            });
                                          },
                                          onLongPressPlus: () {
                                            exercise.sets += 10;
                                            db.updateExercise(exercise).then((
                                              _,
                                            ) {
                                              setState(() {});
                                            });
                                          },
                                          onTapMinus: () {
                                            if (exercise.sets < 1) return;
                                            exercise.sets--;
                                            db.updateExercise(exercise).then((
                                              _,
                                            ) {
                                              setState(() {});
                                            });
                                          },
                                          onLongPressMinus: () {
                                            if (exercise.sets < 10) return;
                                            exercise.sets -= 10;
                                            db.updateExercise(exercise).then((
                                              _,
                                            ) {
                                              setState(() {});
                                            });
                                          },
                                        ),
                                        SizedBox(height: 16),
                                        ExerciseInputWidget(
                                          value: exercise.reps,
                                          suffix: 'reps',
                                          width: mediaWidth,
                                          onTapPlus: () {
                                            exercise.reps++;
                                            db.updateExercise(exercise).then((
                                              _,
                                            ) {
                                              setState(() {});
                                            });
                                          },
                                          onLongPressPlus: () {
                                            exercise.reps += 10;
                                            db.updateExercise(exercise).then((
                                              _,
                                            ) {
                                              setState(() {});
                                            });
                                          },
                                          onTapMinus: () {
                                            if (exercise.reps < 1) return;
                                            exercise.reps--;
                                            db.updateExercise(exercise).then((
                                              _,
                                            ) {
                                              setState(() {});
                                            });
                                          },
                                          onLongPressMinus: () {
                                            if (exercise.reps < 10) return;
                                            exercise.reps -= 10;
                                            db.updateExercise(exercise).then((
                                              _,
                                            ) {
                                              setState(() {});
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        ExerciseInputWidget(
                                          value: exercise.weightKG,
                                          suffix: 'kg',
                                          width: mediaWidth,
                                          onTapPlus: () {
                                            exercise.weightKG++;
                                            db.updateExercise(exercise).then((
                                              _,
                                            ) {
                                              setState(() {});
                                            });
                                          },
                                          onLongPressPlus: () {
                                            exercise.weightKG += 10;
                                            db.updateExercise(exercise).then((
                                              _,
                                            ) {
                                              setState(() {});
                                            });
                                          },
                                          onTapMinus: () {
                                            if (exercise.weightKG < 1) return;
                                            exercise.weightKG--;
                                            db.updateExercise(exercise).then((
                                              _,
                                            ) {
                                              setState(() {});
                                            });
                                          },
                                          onLongPressMinus: () {
                                            if (exercise.weightKG < 10) return;
                                            exercise.weightKG -= 10;
                                            db.updateExercise(exercise).then((
                                              _,
                                            ) {
                                              setState(() {});
                                            });
                                          },
                                        ),
                                        SizedBox(height: 16),
                                        ExerciseInputWidget(
                                          value: exercise.restSeconds,
                                          suffix: 's',
                                          width: mediaWidth,
                                          onTapPlus: () {
                                            exercise.restSeconds += 5;
                                            db.updateExercise(exercise).then((
                                              _,
                                            ) {
                                              setState(() {});
                                            });
                                          },
                                          onLongPressPlus: () {
                                            exercise.restSeconds += 30;
                                            db.updateExercise(exercise).then((
                                              _,
                                            ) {
                                              setState(() {});
                                            });
                                          },
                                          onTapMinus: () {
                                            if (exercise.restSeconds < 5)
                                              return;
                                            exercise.restSeconds -= 5;
                                            db.updateExercise(exercise).then((
                                              _,
                                            ) {
                                              setState(() {});
                                            });
                                          },
                                          onLongPressMinus: () {
                                            if (exercise.restSeconds < 30)
                                              return;
                                            exercise.restSeconds -= 30;
                                            db.updateExercise(exercise).then((
                                              _,
                                            ) {
                                              setState(() {});
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
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
          final newExercise = ExerciseModel(
            id: const Uuid().v4(),
            name: 'New Exercise',
            sets: 3,
            reps: 10,
            weightKG: 0,
            restSeconds: 90,
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
