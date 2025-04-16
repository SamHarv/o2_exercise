import 'exercise_model.dart';

class SessionModel {
  /// [SessionModel] class to represent a session of exercises

  final String id;
  String name;
  List<ExerciseModel> exercises;
  int position;

  SessionModel({
    required this.id,
    required this.name,
    required this.exercises,
    this.position = 0,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'],
      name: json['name'],
      exercises:
          json['exercises']
              .map<ExerciseModel>((e) => ExerciseModel.fromJson(e))
              .toList(),
      position: json['position'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'exercises': exercises.map((e) => e.toJson()).toList(),
      'position': position,
    };
  }
}
