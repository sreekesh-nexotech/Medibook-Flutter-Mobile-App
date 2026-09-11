import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Localization scaffolding.
///
/// Audit §3.6: the app ships no localization at all — not even the framework
/// delegates — so a non-English device gets English Material tooltips, an
/// English date picker and no way to add a translation without restructuring.
/// Translating the product copy is a separate piece of work; **the scaffolding
/// and the delegates are not**, and this file is the scaffolding:
///
/// * [AppLocalizations.delegates] and [AppLocalizations.supportedLocales] are
///   wired into `MaterialApp.router` in `app/app.dart`, so the framework's own
///   strings, date/number formats and text direction follow the device.
/// * [AppStrings] is a locale-keyed lookup for the app's *shared* copy — every
///   string used by `core/widgets/**` plus the strings introduced by the new
///   error/empty/loading/not-found states. English is fully populated; other
///   locales fall back to English key by key, so a partial translation is
///   usable rather than broken.
/// * [L10nContext.l10n] is the call-site accessor: `context.l10n.retry`.
///
/// ## Adding a locale
///
/// 1. Add the [Locale] to [AppLocalizations.supportedLocales].
/// 2. Add a `_StringsXx` subclass overriding the keys that differ.
/// 3. Register it in [AppStrings._tables].
///
/// When the string count outgrows a hand-written table, move to ARB files
/// under `app/localization/arb/` and `flutter gen-l10n`; the
/// `context.l10n.<key>` call sites do not change, which is the point of going
/// through an accessor now.
abstract final class AppLocalizations {
  AppLocalizations._();

  /// The locales the app claims to support. Everything else falls back to
  /// [fallbackLocale].
  static const List<Locale> supportedLocales = [
    Locale('en'), // English (default)
    Locale('hi'), // Hindi
    Locale('ml'), // Malayalam
    Locale('ta'), // Tamil
  ];

  /// Used when the device locale is not in [supportedLocales].
  static const Locale fallbackLocale = Locale('en');

  /// The framework delegates. Without these, Material's own widgets
  /// (date pickers, text-selection menus, semantic labels for "back") stay
  /// English regardless of device language.
  static const List<LocalizationsDelegate<Object>> delegates = [
    _AppStringsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  /// Resolution callback for `MaterialApp.localeResolutionCallback`: match on
  /// language code, ignore the country, fall back to English.
  static Locale localeResolution(
    Locale? deviceLocale,
    Iterable<Locale> supported,
  ) {
    if (deviceLocale == null) return fallbackLocale;
    for (final locale in supported) {
      if (locale.languageCode == deviceLocale.languageCode) return locale;
    }
    return fallbackLocale;
  }
}

/// The shared string table.
///
/// Only *cross-feature* copy belongs here: the design-system widgets, the four
/// screen states, and the words that appear on more than one screen. Feature
/// screens keep their own copy inline for now (the audit explicitly allows the
/// translation itself to wait) — but anything a feature agent adds to
/// `core/widgets/**` must add its string here.
class AppStrings {
  const AppStrings();

  /// Resolve the table for [locale], falling back to English.
  static AppStrings of(Locale locale) =>
      _tables[locale.languageCode] ?? const AppStrings();

  /// Registered tables by language code. English is the base class itself.
  static const Map<String, AppStrings> _tables = <String, AppStrings>{
    'en': AppStrings(),
    // 'hi': _StringsHi(),  ← add alongside a _StringsHi subclass
  };

  /// The locale this table serves — for `Intl` / `DateFormat` call sites.
  String get localeName => 'en';

  // ---- Common actions ----
  String get retry => 'Try Again';
  String get cancel => 'Cancel';
  String get confirm => 'Confirm';
  String get save => 'Save';
  String get saveChanges => 'Save Changes';
  String get discard => 'Discard';
  String get keepEditing => 'Keep Editing';
  String get delete => 'Delete';
  String get remove => 'Remove';
  String get edit => 'Edit';
  String get add => 'Add';
  String get close => 'Close';
  String get done => 'Done';
  String get next => 'Next';
  String get back => 'Back';
  String get goBack => 'Go Back';
  String get goHome => 'Go to Home';
  String get search => 'Search';
  String get select => 'Select';
  String get viewAll => 'View All';
  String get viewDetails => 'View Details';
  String get download => 'Download';
  String get share => 'Share';
  String get refresh => 'Refresh';
  String get signIn => 'Sign In';
  String get signOut => 'Log Out';

  // ---- Screen states (core/widgets/states/**) ----
  String get loading => 'Loading…';
  String get loadingHint => 'This will only take a moment.';
  String get somethingWentWrong => 'Something went wrong';
  String get nothingHere => 'Nothing here yet';
  String get pageNotFoundTitle => 'Page not found';
  String get pageNotFoundBody =>
      'The screen you were looking for has moved or no longer exists.';
  String get offlineTitle => "You're offline";
  String get offlineBody =>
      'Check your connection and try again — your saved data is still here.';
  String get updating => 'Updating…';

  /// Amber stale-cache bar (HIVE spec, Scenario 5).
  String staleData(String age) => 'Data from $age · Tap to refresh';

  // ---- Form / validation surface ----
  String get requiredFieldShort => 'Required';
  String get showPassword => 'Show password';
  String get hidePassword => 'Hide password';
  String get countryCode => 'Country code';
  String get mobileNumber => 'Mobile Number';
  String get selectDate => 'Select a date';
  String get noSlotsForDay => 'No slots on this day';
  String get unsavedChangesTitle => 'Discard your changes?';
  String get unsavedChangesBody =>
      'You have unsaved changes. Leaving now will lose them.';

  // ---- Accessibility labels (audit §3.3) ----
  String get semanticBack => 'Back';
  String get semanticClose => 'Close';
  String get semanticNotifications => 'Notifications';
  String get semanticEdit => 'Edit';
  String get semanticSearch => 'Search';
  String get semanticDownload => 'Download';
  String get tabHome => 'Home';
  String get tabAppointments => 'Appointments';
  String get tabRecords => 'Records';
  String get tabProfile => 'Profile';
  String get selectedSuffix => 'selected';

  // ---- Stubbed-action wording (house style — see app_stub_notice.dart) ----
  String stubbed(String action) => '$action is stubbed in this demo';
  String get stubBannerTitle => 'Not built yet';
  String get stubBannerBody =>
      'This section is part of the design but is not wired up in this build.';

  /// Countdown pill (X-02 slot hold).
  String slotHeldFor(String mmss) => 'Slot held for $mmss';
  String get slotHoldExpired => 'Your slot hold has expired';
}

/// Loads [AppStrings] for the active locale.
///
/// Synchronous — the tables are compiled in — so there is no loading frame and
/// no need for a `FutureBuilder` anywhere.
class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppStrings> load(Locale locale) =>
      SynchronousFuture<AppStrings>(AppStrings.of(locale));

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

/// `context.l10n.retry` — the accessor every call site uses.
///
/// Falls back to the English table when the widget is built outside a
/// `Localizations` scope (a bare `WidgetsApp` in a test), so a missing wrapper
/// degrades to English instead of throwing.
extension L10nContext on BuildContext {
  AppStrings get l10n =>
      Localizations.of<AppStrings>(this, AppStrings) ?? const AppStrings();
}
