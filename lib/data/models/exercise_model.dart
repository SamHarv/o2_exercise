class ExerciseModel {
  /// [ExerciseModel] class to represent an exercise.

  final String id;
  String name;
  int sets;
  int reps;
  int weightKG;
  int restSeconds;
  int position;

  ExerciseModel({
    required this.id,
    required this.name,
    this.sets = 0,
    this.reps = 0,
    this.weightKG = 0,
    this.restSeconds = 0,
    this.position = 0,
  });

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    return ExerciseModel(
      id: json['id'],
      name: json['name'],
      sets: json['sets'],
      reps: json['reps'],
      weightKG: json['weightKG'],
      restSeconds: json['restSeconds'],
      position: json['position'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sets': sets,
      'reps': reps,
      'weightKG': weightKG,
      'restSeconds': restSeconds,
      'position': position,
    };
  }
}
