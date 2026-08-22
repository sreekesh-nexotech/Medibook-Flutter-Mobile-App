import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Local "Available for Donation" toggle for the Profile screen.
///
/// Pure UI state that belongs to the Profile tab only, so it is `autoDispose`
/// and resets to the seeded value when Profile leaves the tree. Seeded `true`
/// to match the prototype's initial state. The screen watches this in `build`
/// and flips it from the switch callback.
final donationProvider = StateProvider.autoDispose<bool>((ref) => true);
