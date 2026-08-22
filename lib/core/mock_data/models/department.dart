/// A clinical department (booking step 1, home services, search).
///
/// Presentation view-model. Immutable value object with `final` fields only —
/// no business logic — so it maps 1:1 onto the future `domain/entities`
/// Department entity when the data layer is built.
class Department {
  const Department({
    required this.name,
    required this.sub,
    required this.iconName,
  });

  /// Display name and the department key used to filter doctors.
  final String name;

  /// Short descriptor ("Heart specialists").
  final String sub;

  /// Medibook icon name for the tile (see [MedIcon]).
  final String iconName;
}
