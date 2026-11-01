/// A child profile created by a Parent (SRS US_6).
/// Each child keeps their OWN learning progress.
class ChildProfile {
  final String id;
  final String name;
  final int age;

  const ChildProfile({required this.id, required this.name, required this.age});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'age': age};

  factory ChildProfile.fromMap(Map<String, dynamic> map) => ChildProfile(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        age: (map['age'] ?? 0) as int,
      );
}

/// A class created by a Teacher, holding student names (SRS US_7).
class SchoolClass {
  final String id;
  final String name;
  final List<String> students;

  const SchoolClass(
      {required this.id, required this.name, required this.students});

  Map<String, dynamic> toMap() =>
      {'id': id, 'name': name, 'students': students};

  factory SchoolClass.fromMap(Map<String, dynamic> map) => SchoolClass(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        students: List<String>.from(map['students'] ?? const []),
      );
}
