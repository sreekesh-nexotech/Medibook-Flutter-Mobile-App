# Medibook Component Contract (Presentation)

The exact Dart constructor signatures for the shared design-system widgets. This
is a **contract**: the DS-component agent implements these signatures precisely,
and every screen agent codes against them. If a screen needs a shape not here,
raise it — don't invent a diverging widget.

All widgets live in `lib/core/widgets/`. They import tokens from
`app/theme/{colors,typography,theme}.dart` and `app/config/constants.dart`.
Full styling detail per component is in `docs/DESIGN-SPEC.md §3`; this file fixes
the **Dart API** and the **must-match values**.

## Global rules (every widget & screen)

- **ScreenUtil on every dimension.** `.w` widths, `.h` heights, `.sp` font sizes,
  `.r` radii + icon sizes. Never a raw pixel. Never `const` on a widget whose
  style uses `.sp/.w/.h/.r`.
- **Tokens only.** Colors from `AppColors`, text via `AppText.poppins/inter`,
  radii via `AppRadii`, shadows via `AppShadows`, spacing via `AppSpacing`. No
  literal hex, no magic numbers that have a token.
- **Widget type discipline** (QA Prompt 6): `StatelessWidget` when it only takes
  data + callbacks (most DS widgets); `StatefulWidget` only for local visual
  state (press animation, obscure toggle); `ConsumerWidget` only when it reads a
  provider (DS widgets generally do **not** — they receive data as params).
- **Press feedback** matches the design: buttons scale to `0.98`, icon buttons to
  `0.92` on tap down (use `GestureDetector`/`AnimatedScale` or `Listener`).
- Icons render via `AppIcon(name, size:, color:)` (already built).

---

## AppButton — `core/widgets/app_button.dart`

```dart
enum AppButtonVariant { primary, secondary, ghost, danger, soft }
enum AppButtonSize { sm, md, lg }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.pill = false,
    this.fullWidth = false,
    this.leadingIcon,   // MedIcon name
    this.trailingIcon,  // MedIcon name
    this.disabled = false,
  });
}
```

Values (DESIGN-SPEC §3):
- Sizes: `sm{h38,padH16,fs13,gap6,icon16}` · `md{h48,padH22,fs16,gap8,icon18}` ·
  `lg{h54,padH26,fs16,gap10,icon20}`.
- Variants: `primary` navy fill / white / 1px brand border; `secondary`
  transparent / brand / **1.5px** brand border; `ghost` transparent / brand;
  `danger` `AppColors.danger` fill / white; `soft` `surfaceTint` bg / brand.
- Radius: `AppRadii.pill` when `pill`, else `AppRadii.md`. Font weight semibold.
- Disabled → opacity 0.5, ignore taps. Press → `scale(0.98)`.
- `fullWidth` → width `double.infinity`.

## AppIconButton — `core/widgets/app_icon_button.dart`

```dart
enum AppIconButtonVariant { plain, onBrand, tint, outline }

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,            // MedIcon name
    this.onPressed,
    this.size = 44,
    this.iconSize,                 // defaults to (size*0.5).round()
    this.variant = AppIconButtonVariant.plain,
  });
}
```
Circular (`AppRadii.pill`). `plain` transparent/brand; `onBrand`
transparent/white; `tint` surfaceTint/brand; `outline` surface/brand + 1px
border. Press → `scale(0.92)`.

## AppCard — `core/widgets/app_card.dart`

```dart
enum AppRadiusToken { sm, md, lg, xl }
enum AppShadowToken { none, xs, sm, md, lg }

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,                    // default EdgeInsets.all(16.w)
    this.radius = AppRadiusToken.lg,
    this.shadow = AppShadowToken.sm,
    this.onTap,
    this.border,                     // optional Border (selected states)
    this.color,                      // default AppColors.surface
  });
}
```
White surface, `AppShadows.sm` default. When `onTap != null`, wrap in a tap
handler with `scale(0.98/0.99)` press feedback (per design cards).

## AppBadge — `core/widgets/app_badge.dart`

```dart
enum AppBadgeTone { neutral, brand, success, danger, warning }

class AppBadge extends StatelessWidget {
  const AppBadge({super.key, required this.label, this.tone = AppBadgeTone.neutral});
}
```
Pill, padding `6x14`, `fs sm`, weight medium. Tones per DESIGN-SPEC §3
(`success` = successSoft/successText, `danger` = dangerSoft/dangerText, etc.).

## AppTag — `core/widgets/app_tag.dart`

```dart
class AppTag extends StatelessWidget {
  const AppTag({super.key, required this.label, this.active = false});
}
```
Pill `4x12`, `fs xs`, weight medium. Active → brand fill / white; else
surfaceTint / brand.

## AppAvatar — `core/widgets/app_avatar.dart`

```dart
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.imageAsset,     // local asset path (seed doctors/user)
    this.imageUrl,       // optional network (future API) → cached_network_image
    this.size = 44,
    this.ring = false,
  });
}
```
Circle, `overflow:hidden`, `surfaceTint` bg, brand initials (first letters of
first two words, uppercased) at `size*0.38` when no image. `ring` →
`0 0 0 2px surface, 0 0 0 3.5px brand` (emulate with two stacked rings / Border +
box-shadow). Use `CachedNetworkImage` when `imageUrl` set, else `Image.asset`.

## AppRating — `core/widgets/app_rating.dart`

```dart
class AppRating extends StatelessWidget {
  const AppRating({
    super.key,
    required this.value,
    this.max = 5,
    this.size = 16,
    this.showValue = false,
    this.onRate,           // ValueChanged<int>? — display-only when null
  });
}
```
Stars: filled `MedIcon.bold(star)` in `AppColors.warning` for `i < round(value)`,
else `MedIcon.star` in `AppColors.grey200`. `gap 3`. `showValue` → appends
`value.toStringAsFixed(1)` at `fs sm` / medium / `textBody`, `marginLeft 6`.

## AppTextField — `core/widgets/app_text_field.dart`

```dart
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.label,
    this.controller,
    this.onChanged,
    this.hintText,          // placeholder
    this.errorText,
    this.iconName,          // optional leading MedIcon
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.focusNode,
  });
}
```
Label `fs base`/medium/`textStrong`, `mb 8`. Field: `h 52`, `padH 16`, bg
`surfaceAlt`, 1px border (`danger` on error else `border`), `AppRadii.md`,
`fs body`/`textPrimary`, placeholder `textMuted`. Error/hint line `fs xs`,
`mt 6` (`danger` when error). This is a `StatelessWidget` — the owning screen
holds the `TextEditingController` (local form state).

## AppCheckbox — `core/widgets/app_checkbox.dart`

```dart
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    this.onChanged,      // ValueChanged<bool>?
    this.label,
    this.error = false,
  });
}
```
20×20 box, `radius 6.r`, 1.5px border (danger on error / brand when checked /
grey300), brand fill + white check path `M5 12l4.5 4.5L19 7` when checked. Label
`fs sm`, lh 1.45, `textBody` (danger on error). Align `flex-start`, `gap 10`.

## AppRadio — `core/widgets/app_radio.dart`

```dart
class AppRadio extends StatelessWidget {
  const AppRadio({super.key, required this.selected, this.onChanged, this.label});
}
```
20×20 circle, 1.5px border (brand when selected else grey300), 10px brand dot.

## AppSelect — `core/widgets/app_select.dart`

```dart
class AppSelectOption<T> { const AppSelectOption(this.value, this.label); final T value; final String label; }

class AppSelect<T> extends StatelessWidget {
  const AppSelect({
    super.key,
    this.label,
    this.value,
    this.placeholder = 'Select',
    required this.options,
    this.onChanged,       // ValueChanged<T?>?
  });
}
```
Matches `AppTextField` field styling; custom chevron `M6 9l6 6 6-6`. (Not used by
the 15 current screens but part of the DS — implement for completeness.)

## AppSwitch — `core/widgets/app_switch.dart`

```dart
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, this.onChanged});
}
```
Track 46×26 pill (`brand` on / `grey200` off), 20px white knob sliding
`left 3 → 23` over 180ms, subtle knob shadow.

## AppBottomNav — `core/widgets/navbar.dart`

```dart
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.active, this.onChanged});
  final AppTab active;                    // from app/router/app_routes.dart
  final ValueChanged<AppTab>? onChanged;
}
```
4 tabs home/appointments/records/profile. Render the exact custom glyphs:
`assets/icons/nav_<tab>.svg` (inactive) and `nav_<tab>_active.svg` (active), 25×25,
via `SvgPicture.asset` colored `brand` (active) / `grey300` (inactive). Label
`fs 12`, weight semibold (active) / regular. Bar padding `12,8,18`, top border
`borderSubtle`, bg surface. (The shell wires `onChanged` to tab navigation.)

## AppSegmentedTabs — `core/widgets/app_segmented_tabs.dart`

```dart
class AppSegmentedTabs extends StatelessWidget {
  const AppSegmentedTabs({super.key, required this.tabs, required this.active, this.onChanged});
  final List<String> tabs; final String active; final ValueChanged<String>? onChanged;
}
```
Horizontal scroll pill row, `gap 8`, each `padding 9x18`, `fs sm`/medium, pill.
Active navy fill/white; else surface + `border` + `textBody`.

## AppStepper — `core/widgets/app_stepper.dart`

```dart
class AppStepper extends StatelessWidget {
  const AppStepper({super.key, this.steps = 4, required this.current});
}
```
30px circles + 2px connectors. done/active navy + white; pending surfaceTint +
`primary300`. Connector navy when `n < current` else grey100.

---

## Shared layout helpers (also `core/widgets/`)

### AppInnerHeader — `core/widgets/app_inner_header.dart`
The repeated inner-screen header (back button + centered title). Used by
signup/forgot/verify/reset, search, notifications, booking, doctor, appt detail,
reschedule.
```dart
class AppInnerHeader extends StatelessWidget {
  const AppInnerHeader({
    super.key,
    required this.title,
    this.onBack,             // null → no back button (renders spacer)
    this.trailing,           // optional right-side widget (e.g. bell)
  });
}
```
Row: 38px back `AppIconButton(icon: back, variant: plain)`, centered title
`fs 20`/bold/`textStrong`, 38px trailing/spacer. **Top padding 12.h** (design
56px minus the 44px faux status bar — the app uses `SafeArea`, see build guide),
horizontal 18.w, bottom 14.h, bg `bgApp`.

### AppTabHeader — `core/widgets/app_tab_header.dart`
The large left-aligned title used by Appointments/Records/Profile tab tops.
```dart
class AppTabHeader extends StatelessWidget {
  const AppTabHeader({super.key, required this.title, this.trailing});
}
```
Title `fs 22`/bold/`textStrong`, optional trailing (bell IconButton). Padding
top 12.h, horizontal 20.w, bottom 14.h.

### showMedibookSheet — `core/widgets/app_bottom_sheet.dart`
Confirm bottom sheet (logout / delete / cancel appointment).
```dart
Future<void> showMedibookSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  AppButtonVariant confirmVariant = AppButtonVariant.primary,
  required VoidCallback onConfirm,
});
```
Scrim `AppColors.scrim`, sheet surface, top radius 24, padding `26,22,30`,
centered title `fs 18`/bold + message `fs sm`/muted, row: Cancel (soft) +
confirm button. `sheetUp` rise animation. Tap scrim closes.

### AppStatusPill — `core/widgets/app_status_pill.dart`
Small pill for appointment status / token, using `AppStatusStyle`.
```dart
class AppStatusPill extends StatelessWidget {
  const AppStatusPill({super.key, required this.label, required this.colors});
  final String label; final PillColors colors; // from AppStatusStyle
}
```
Pill, `fs 11`/semibold, padding `4x10`.
