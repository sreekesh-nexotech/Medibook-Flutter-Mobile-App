import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock_data/medibook_seed.dart';

/// Current user's display name for the Home greeting + header avatar. A tiny
/// read [Provider] so the screen never touches [MedibookSeed] directly
/// (screen-build-guide rule 10); the first name for the greeting is derived
/// from it. When the auth/session layer lands, this swaps to the signed-in
/// user provider and the screen code stays put.
final homeUserNameProvider = Provider<String>((ref) => MedibookSeed.userName);
