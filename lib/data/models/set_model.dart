class SetModel {
  String id;
  String exerciseId;
  int reps;
  int weight;
  int restSeconds;
  int order;

  SetModel({
    required this.id,
    required this.exerciseId,
    required this.reps,
    required this.weight,
    required this.restSeconds,
    required this.order,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exercise_id': exerciseId,
      'reps': reps,
      'weight': weight,
      'rest': restSeconds,
      'order_num': order,
    };
  }

  factory SetModel.fromJson(Map<String, dynamic> json) {
    return SetModel(
      id: json['id'],
      exerciseId: json['exercise_id'],
      reps: json['reps'],
      weight: json['weight'],
      restSeconds: json['rest'],
      order: json['order_num'],
    );
  }
}
