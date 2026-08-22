import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The live search query text. `autoDispose` so it resets to empty each time the
/// Search screen is left and re-entered. The screen owns the
/// `TextEditingController` (input mechanics); this holds the query the filtered
/// Departments/Doctors lists derive from. Stores the raw text — matching
/// lowercases at the filter site, and the empty state echoes it verbatim.
final searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');
