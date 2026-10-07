import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../application/providers/records_provider.dart';
import '../../application/states/documents_list_state.dart';

/// The Records tab's title search (`q` on `GET /patient/documents`).
///
/// Owns its text controller so the list rebuilding under it never disturbs
/// what is being typed. The term itself lives in [documentsSearchProvider],
/// which debounces it; this box only mirrors a clear made elsewhere (the
/// empty state's "Clear search").
class RecordsSearchField extends ConsumerStatefulWidget {
  const RecordsSearchField({super.key});

  @override
  ConsumerState<RecordsSearchField> createState() => _RecordsSearchFieldState();
}

class _RecordsSearchFieldState extends ConsumerState<RecordsSearchField> {
  late final TextEditingController _field = TextEditingController(
    text: ref.read(documentsSearchProvider).input,
  );

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _clear() {
    _field.clear();
    ref.read(documentsSearchProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final hasInput = ref.watch(
      documentsSearchProvider.select((search) => search.hasInput),
    );
    // Cleared from outside this box: empty the text too.
    ref.listen(documentsSearchProvider.select((search) => search.input), (
      previous,
      next,
    ) {
      if (next.isEmpty && _field.text.isNotEmpty) _field.clear();
    });

    return AppTextField(
      controller: _field,
      iconName: MedIcon.search,
      hintText: 'Search by title',
      semanticLabel: 'Search your records by title',
      textInputAction: TextInputAction.search,
      maxLength: DocumentsSearchState.maxLength,
      onChanged: ref.read(documentsSearchProvider.notifier).onInput,
      suffix: hasInput
          ? AppIconButton(
              icon: PhIcon.x,
              size: 22,
              semanticLabel: 'Clear search',
              onPressed: _clear,
            )
          : null,
    );
  }
}
