import 'package:json_annotation/json_annotation.dart';

part 'task.g.dart';

@JsonSerializable()
class Task {
  final String id;
  final String title;
  final String? description;
  final bool completed;
  @JsonKey(name: 'updatedAt')
  final DateTime updatedAt;
  final DateTime? syncedAt;

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.completed,
    required this.updatedAt,
    this.syncedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
  Map<String, dynamic> toJson() => _$TaskToJson(this);

  Task copyWith({
    String? id,
    String? title,
    String? description,
    bool? completed,
    DateTime? updatedAt,
    DateTime? syncedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  String toString() {
    return 'Task(id: $id, title: $title, description: $description, completed: $completed, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Task &&
        other.id == id &&
        other.title == title &&
        other.description == description &&
        other.completed == completed &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        description.hashCode ^
        completed.hashCode ^
        updatedAt.hashCode;
  }
}
