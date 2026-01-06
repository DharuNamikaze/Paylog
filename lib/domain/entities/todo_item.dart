/// Represents a single todo item in the todo list
class TodoItem {
  /// Unique identifier for the todo item
  final String id;

  /// Description of the task
  final String description;

  /// Whether the task has been completed
  final bool isCompleted;

  /// When the todo item was created
  final DateTime createdAt;

  const TodoItem({
    required this.id,
    required this.description,
    this.isCompleted = false,
    required this.createdAt,
  });

  /// Create a copy of this todo item with updated fields
  TodoItem copyWith({
    String? id,
    String? description,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return TodoItem(
      id: id ?? this.id,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Serialize to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Deserialize from JSON map
  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as String,
      description: json['description'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodoItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          description == other.description &&
          isCompleted == other.isCompleted &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      description.hashCode ^
      isCompleted.hashCode ^
      createdAt.hashCode;

  @override
  String toString() {
    return 'TodoItem{id: $id, description: $description, isCompleted: $isCompleted, createdAt: $createdAt}';
  }
}
