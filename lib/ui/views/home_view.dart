import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:o2_exercise/utils/constants.dart';

import '../../data/database/db_helper.dart';
import '../../data/models/session_model.dart';
import 'session_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final db = DatabaseHelper.instance;
  List<SessionModel> sessions = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final loadedSessions = await db.readAllSessions();

      setState(() {
        sessions = loadedSessions;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: black,
      appBar: AppBar(
        title: const Text('O2 Exercise', style: TextStyle(color: white)),
        centerTitle: false,
        backgroundColor: black,
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          final newSession = SessionModel(
            id: const Uuid().v4(),
            name: 'New Session',
            exercises: [],
          );
          db.createSession(newSession).then((_) {
            Navigator.push(
              // ignore: use_build_context_synchronously
              context,
              // fade in
              PageRouteBuilder(
                pageBuilder:
                    (context, animation, secondaryAnimation) =>
                        SessionView(session: newSession),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) =>
                        FadeTransition(opacity: animation, child: child),
              ),
              // MaterialPageRoute(
              //   builder: (context) => EntryView(entry: newEntry),
              // ),
            ).then((_) => _loadSessions());
          });
        },
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: white));
    }

    if (error != null) {
      return Center(
        child: Text('Error: $error', style: TextStyle(color: white)),
      );
    }

    if (sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No Sessions Found.', style: TextStyle(color: white)),
        ),
      );
    }

    return Theme(
      data: ThemeData(canvasColor: Colors.grey[900]),
      child: ReorderableListView.builder(
        itemCount: sessions.length,
        onReorder: (oldIndex, newIndex) {
          // Handle the index adjustment
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }

          // Update UI immediately (optimistic update)
          setState(() {
            final movedSession = sessions.removeAt(oldIndex);
            sessions.insert(newIndex, movedSession);
          });

          // Then update database without triggering a full reload
          final List<String> sessionIds = sessions.map((s) => s.id).toList();
          db.reorderSessions(sessionIds).catchError((error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to update order: $error')),
            );
            _loadSessions(); // Reload on error to get correct state
          });
        },
        itemBuilder: (context, index) {
          final session = sessions[index];
          return Dismissible(
            direction: DismissDirection.endToStart,
            key: Key(session.id),
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32.0),
                            side: const BorderSide(color: white, width: 2.0),
                          ),
                          backgroundColor: black,
                          title: const Text(
                            'Delete Session',
                            style: TextStyle(color: white),
                          ),
                          content: const Text(
                            'Are you sure you want to delete this session?',
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
                              onPressed: () => Navigator.of(context).pop(false),
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
              final deletedSession = sessions[index];
              setState(() {
                sessions.removeAt(index);
              });

              // Then update database
              db.deleteSession(deletedSession.id).then((_) {
                _loadSessions(); // Reload on error to get correct state
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
            child: ListTile(
              splashColor: Colors.transparent,
              title: Text(session.name, style: TextStyle(color: white)),
              onTap:
                  () => Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder:
                          (context, animation, secondaryAnimation) =>
                              SessionView(session: session),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) =>
                              FadeTransition(opacity: animation, child: child),
                    ),
                  ).then(
                    (_) => _loadSessions(),
                  ), // Reload data when returning from SessionView
            ),
          );
        },
      ),
    );
  }
}
