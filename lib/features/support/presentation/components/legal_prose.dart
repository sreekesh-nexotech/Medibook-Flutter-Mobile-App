import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';

/// What kind of block one piece of a legal document is.
enum ProseBlockKind { heading, paragraph, bullet }

/// One renderable block of a legal document, with its inline runs already
/// resolved (see [ProseRun]).
@immutable
class ProseBlock {
  const ProseBlock({required this.kind, required this.runs});

  final ProseBlockKind kind;

  /// The block's text, split into plain and bold runs.
  final List<ProseRun> runs;

  /// The block's text with all emphasis flattened — what a screen reader and
  /// the FAQ/legal search need.
  String get plainText => runs.map((r) => r.text).join();
}

/// A run of text inside a [ProseBlock]: either plain or bold.
@immutable
class ProseRun {
  const ProseRun(this.text, {this.isBold = false});

  final String text;
  final bool isBold;
}

/// Parses the seed's "markdownish" legal bodies into renderable blocks.
///
/// ## Why a parser and not a markdown package
///
/// `LegalDocument.bodyMarkdownish` documents a deliberately tiny subset, and
/// the app must not gain a markdown dependency. But the seed's actual text is
/// **hard-wrapped at ~78 columns**, which the model's own line-per-block
/// `LegalDocument.blocks` getter cannot see: it turns
///
/// ```text
/// - You must be 18 or older to hold an account. You may add family members of any
///   age as dependants under your own account.
/// ```
///
/// into a bullet followed by a stray one-word paragraph ("age as dependants
/// under your own account."), and does the same to every wrapped paragraph.
/// The privacy policy also uses `**bold**` lead-ins
/// (`- **Account details** — your name, …`), which that getter renders as
/// literal asterisks.
///
/// So this parser works on *blocks* rather than lines:
///
/// * `## ` starts a heading block;
/// * `- ` starts a bullet block;
/// * a blank line ends the current block;
/// * any other line **continues** the block it is inside (joined with a single
///   space), which is what un-wraps the seed's hard line breaks;
/// * `**…**` inside a block becomes a bold [ProseRun].
///
/// Pure functions, no Flutter dependency beyond `@immutable`, so the shape is
/// testable without a widget tree.
abstract final class LegalProseParser {
  LegalProseParser._();

  static final RegExp _whitespace = RegExp(r'\s+');

  /// Parses [body] into blocks. Never throws; unparseable input simply yields
  /// paragraphs.
  static List<ProseBlock> parse(String body) {
    final blocks = <ProseBlock>[];
    final buffer = StringBuffer();
    var kind = ProseBlockKind.paragraph;

    void flush() {
      final text = buffer.toString().trim().replaceAll(_whitespace, ' ');
      buffer.clear();
      if (text.isEmpty) return;
      blocks.add(ProseBlock(kind: kind, runs: parseRuns(text)));
    }

    for (final rawLine in body.split('\n')) {
      final line = rawLine.trim();

      if (line.isEmpty) {
        flush();
        kind = ProseBlockKind.paragraph;
        continue;
      }
      if (line.startsWith('## ')) {
        flush();
        kind = ProseBlockKind.heading;
        buffer.write(line.substring(3));
        flush();
        kind = ProseBlockKind.paragraph;
        continue;
      }
      if (line.startsWith('- ')) {
        flush();
        kind = ProseBlockKind.bullet;
        buffer.write(line.substring(2));
        continue;
      }
      // A continuation of the block above — the seed hard-wraps its prose, so
      // this is the common case, not the exception.
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(line);
    }
    flush();

    return blocks;
  }

  /// Splits `**bold**` spans out of [text]. An unclosed `**` is treated as
  /// literal text rather than swallowing the rest of the block.
  static List<ProseRun> parseRuns(String text) {
    if (!text.contains('**')) return [ProseRun(text)];

    final runs = <ProseRun>[];
    var index = 0;
    while (index < text.length) {
      final open = text.indexOf('**', index);
      if (open == -1) {
        runs.add(ProseRun(text.substring(index)));
        break;
      }
      final close = text.indexOf('**', open + 2);
      if (close == -1) {
        runs.add(ProseRun(text.substring(index)));
        break;
      }
      if (open > index) runs.add(ProseRun(text.substring(index, open)));
      final bold = text.substring(open + 2, close);
      if (bold.isNotEmpty) runs.add(ProseRun(bold, isBold: true));
      index = close + 2;
    }
    return runs.isEmpty ? [ProseRun(text)] : runs;
  }
}

/// Renders parsed legal prose: section headings, paragraphs and bullets.
///
/// Stateless and scroll-agnostic — the screen owns the scroll view, so the same
/// widget renders a whole document or one section inside a sheet. Nothing here
/// has a fixed height, so the text survives OS scaling to 1.3x by growing.
class LegalProse extends StatelessWidget {
  const LegalProse({super.key, required this.blocks});

  /// From [LegalProseParser.parse].
  final List<ProseBlock> blocks;

  /// Convenience: parse and render in one step.
  LegalProse.fromBody(String body, {super.key})
    : blocks = LegalProseParser.parse(body);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++)
          _ProseBlockView(block: blocks[i], isFirst: i == 0),
      ],
    );
  }
}

/// One block, with the vertical rhythm that separates a new section from a
/// continuing paragraph.
class _ProseBlockView extends StatelessWidget {
  const _ProseBlockView({required this.block, required this.isFirst});

  final ProseBlock block;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    switch (block.kind) {
      case ProseBlockKind.heading:
        return Padding(
          padding: EdgeInsets.only(
            top: isFirst ? 0 : AppSpacing.x6.h,
            bottom: AppSpacing.x2.h,
          ),
          child: Semantics(
            header: true,
            child: Text(
              block.plainText,
              style: AppText.poppins(
                size: AppFontSize.body,
                weight: AppText.bold,
                color: AppColors.textStrong,
                height: 1.4,
              ),
            ),
          ),
        );

      case ProseBlockKind.paragraph:
        return Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.x3.h),
          child: Text.rich(_span(_bodyStyle), style: _bodyStyle),
        );

      case ProseBlockKind.bullet:
        return Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.x2.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A dot, not a glyph: the icon set has no bullet and a text
              // hyphen reads as a minus sign.
              Container(
                margin: EdgeInsets.only(top: 8.h, right: AppSpacing.x3.w),
                width: 5.r,
                height: 5.r,
                decoration: const BoxDecoration(
                  color: AppColors.textMutedDecorative,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text.rich(_span(_bodyStyle), style: _bodyStyle),
              ),
            ],
          ),
        );
    }
  }

  TextStyle get _bodyStyle => AppText.poppins(
    size: AppFontSize.base,
    color: AppColors.textBody,
    height: 1.6,
  );

  TextSpan _span(TextStyle base) => TextSpan(
    children: [
      for (final run in block.runs)
        TextSpan(
          text: run.text,
          style: run.isBold
              ? base.copyWith(
                  fontWeight: AppText.semibold,
                  color: AppColors.textStrong,
                )
              : null,
        ),
    ],
  );
}

/// The "Version 2026.1 · Updated 28 Jul 2026" line above a legal document, and
/// the note that the copy is placeholder text.
class LegalProseMeta extends StatelessWidget {
  const LegalProseMeta({super.key, required this.version, required this.updated});

  final String version;

  /// Already formatted (`AppDates.dayMonthYear`) by the caller, because the
  /// date format belongs to the screen, not to this row.
  final String updated;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.x4.w,
        vertical: AppSpacing.x3.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadii.md,
        border: Border.all(color: AppColors.border, width: 1.w),
      ),
      child: Text(
        'Version $version · Updated $updated',
        style: AppText.poppins(size: AppFontSize.xs, color: AppColors.textMuted),
      ),
    );
  }
}
