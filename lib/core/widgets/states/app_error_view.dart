/// The error state, re-exported so all four screen states can be reached from
/// one place (`core/widgets/states/`).
///
/// The implementation lives in `core/error/error_view.dart`, next to the
/// [Failure] model it renders, and is **not** duplicated here — the audit's
/// §3.2.3 fix is one error view, not two that can drift apart.
///
/// ```dart
/// import 'package:medibook/core/widgets/states/app_error_view.dart';
/// // → AppErrorView, AppInlineError, AppErrorBanner, AppStateGlyph
/// ```
library;

export '../../error/error_view.dart'
    show
        AppBannerTone,
        AppErrorBanner,
        AppErrorView,
        AppInlineError,
        AppStateGlyph,
        AppStateGlyphTone;
