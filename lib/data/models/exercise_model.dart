import 'package:o2_exercise/data/models/set_model.dart';

class ExerciseModel {
  /// [ExerciseModel] class to represent an exercise.

  final String id;
  String name;
  List<SetModel> sets;
  int position;

  ExerciseModel({
    required this.id,
    required this.name,
    this.sets = const [],
    this.position = 0,
  });

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    return ExerciseModel(
      id: json['id'],
      name: json['name'],
      sets: json['sets'],
      position: json['position'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'sets': sets, 'position': position};
  }
}
