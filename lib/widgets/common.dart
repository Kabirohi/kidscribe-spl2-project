import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'fun.dart';

/// Small building blocks shared by many screens, so every screen looks
/// the same and the screen files stay short.
///
/// Design language: chunky rounded shapes, a solid "ledge" under buttons and
/// cards (instead of a blurry shadow), heavy friendly headings, lots of space.

/// A standard text style helper, so screens stay readable.
TextStyle kid(double size,
        {FontWeight weight = FontWeight.w600,
        Color color = AppColors.textDark}) =>
    GoogleFonts.nunito(fontSize: size, fontWeight: weight, color: color);

/// A friendly message at the bottom of the screen.
void showKidSnack(BuildContext context, String msg,
    {Color color = AppColors.textDark}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(msg,
            style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        backgroundColor: color == AppColors.purple ? AppColors.textDark : color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
}

/// The look of every dialog in the app.
Widget _dialogShell({
  required String title,
  required Widget content,
  required List<Widget> actions,
  Color titleColor = AppColors.textDark,
}) {
  return AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    titlePadding: const EdgeInsets.fromLTRB(28, 26, 28, 8),
    contentPadding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
    actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
    title: Text(title,
        style: GoogleFonts.nunito(
            fontSize: 24, fontWeight: FontWeight.w900, color: titleColor)),
    content: content,
    actions: actions,
  );
}

/// Shows a saved report file: where it is and what it says.
void showReportDialog(BuildContext context, String path, String content) {
  showDialog(
    context: context,
    builder: (ctx) => _dialogShell(
      title: 'Report saved 📄',
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Saved to:\n$path',
                style: kid(12, color: AppColors.textMuted)),
            const Divider(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SelectableText(content,
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// Asks for one line of text (a name). [onSave] returns true when the
/// text was accepted, so the box can close.
void showNameDialog(
  BuildContext context, {
  required String title,
  required String label,
  required IconData icon,
  String buttonText = 'Save',
  String initial = '',
  required Future<bool> Function(String text) onSave,
}) {
  final ctrl = TextEditingController(text: initial);
  showDialog(
    context: context,
    builder: (ctx) => _dialogShell(
      title: title,
      content: TextField(
        controller: ctrl,
        autofocus: true,
        style: kid(17),
        decoration: KidInput.decoration(label: label, icon: icon),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final ok = await onSave(ctrl.text.trim());
            if (ok && ctx.mounted) Navigator.pop(ctx);
          },
          child: Text(buttonText),
        ),
      ],
    ),
  );
}

/// "Are you sure?" with a red button. Calls [onYes] only on yes.
void showConfirmDialog(
  BuildContext context, {
  required String title,
  required String text,
  String yesText = 'Delete',
  required VoidCallback onYes,
}) {
  showDialog(
    context: context,
    builder: (ctx) => _dialogShell(
      title: title,
      content: Text(text, style: kid(16, color: AppColors.textMuted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error, foregroundColor: Colors.white),
          onPressed: () {
            Navigator.pop(ctx);
            onYes();
          },
          child: Text(yesText),
        ),
      ],
    ),
  );
}

/// Text-field look used by sign in, sign up and the dialogs: a quiet grey
/// row that turns into a violet outline when you type in it.
class KidInput {
  static InputDecoration decoration({
    required String label,
    IconData? icon,
    Widget? suffix,
    String? hint,
  }) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: kid(16, weight: FontWeight.w700, color: AppColors.textMuted),
      floatingLabelStyle:
          kid(15, weight: FontWeight.w800, color: AppColors.primary),
      prefixIcon: icon == null ? null : Icon(icon, color: AppColors.textMuted),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
      border: border(Colors.transparent, 0),
      enabledBorder: border(Colors.transparent, 0),
      focusedBorder: border(AppColors.primary, 2.5),
      errorBorder: border(AppColors.error, 2),
      focusedErrorBorder: border(AppColors.error, 2.5),
      errorStyle: kid(13, weight: FontWeight.w700, color: AppColors.error),
    );
  }
}

/// The page background used across the app.
class KidPage extends StatelessWidget {
  final Widget child;
  final Widget? floatingActionButton;

  const KidPage({super.key, required this.child, this.floatingActionButton});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: Stack(
          children: [
            // Stars, bubbles and letters drifting softly in the background.
            const Positioned.fill(
                child: FloatingShapes(count: 12, opacity: 0.16)),
            SafeArea(
              // On a big tablet the content stays a comfortable reading width.
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A round "back" button, like a game's close button.
class KidBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool onDark;

  const KidBackButton({super.key, this.onPressed, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return Bouncy(
      onTap: onPressed ?? () => Navigator.maybePop(context),
      pressedScale: 0.85,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: onDark ? Colors.white.withValues(alpha: 0.16) : Colors.white,
          shape: BoxShape.circle,
          border: onDark ? null : Border.all(color: AppColors.line, width: 2),
          boxShadow: onDark
              ? null
              : const [
                  BoxShadow(color: AppColors.line, offset: Offset(0, 3)),
                ],
        ),
        child: Icon(Icons.chevron_left_rounded,
            size: 32, color: onDark ? Colors.white : AppColors.primary),
      ),
    );
  }
}

/// A back button and a big heavy title, with optional buttons on the right.
class KidHeader extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final double fontSize;

  const KidHeader(this.title,
      {super.key, this.actions = const [], this.fontSize = 28});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
      child: Row(
        children: [
          const KidBackButton(),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                height: 1.1,
                color: AppColors.textDark,
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// A white rounded card with a soft solid ledge underneath.
class KidCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final VoidCallback? onTap;

  const KidCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final edge = borderColor ?? AppColors.line;
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: edge, width: 2),
        boxShadow: [
          BoxShadow(color: edge, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
    return onTap == null
        ? card
        : Bouncy(onTap: onTap, pressedScale: 0.96, child: card);
  }
}

/// A big chunky pill button. It sits on a solid darker "ledge" and sinks
/// when pressed.
class KidButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool busy;
  final double height;

  const KidButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.color = AppColors.primary,
    this.busy = false,
    this.height = 56,
  });

  @override
  State<KidButton> createState() => _KidButtonState();
}

class _KidButtonState extends State<KidButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    final face = enabled ? widget.color : const Color(0xFFDAD6EC);
    final edge =
        enabled ? AppColors.ledge(widget.color) : const Color(0xFFBEBAD6);
    final depth = (_down && enabled) ? 1.0 : 5.0;

    return SizedBox(
      width: double.infinity,
      height: widget.height + 5,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: (_down && enabled) ? 0.95 : 1.0,
          duration: Duration(milliseconds: _down ? 80 : 380),
          curve: _down ? Curves.easeOut : Curves.elasticOut,
          child: Align(
            alignment: Alignment.topCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 70),
              margin: EdgeInsets.only(top: 5 - depth),
              height: widget.height,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: face,
                gradient: enabled
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color.lerp(face, Colors.white, 0.18)!, face],
                      )
                    : null,
                borderRadius: BorderRadius.circular(widget.height),
                boxShadow: [
                  BoxShadow(color: edge, offset: Offset(0, depth)),
                ],
              ),
              child: widget.busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 3),
                    )
                  : Text(widget.label,
                      style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: enabled
                              ? Colors.white
                              : const Color(0xFF9692B5))),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small coloured tag, e.g. "Active" or "You are here".
class KidTag extends StatelessWidget {
  final String text;
  final Color color;
  final bool solid;

  const KidTag(this.text,
      {super.key, this.color = AppColors.primary, this.solid = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: GoogleFonts.nunito(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: solid ? Colors.white : color)),
    );
  }
}

/// A round coloured badge holding an icon.
class KidIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const KidIconBadge(this.icon,
      {super.key, this.color = AppColors.primary, this.size = 60});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.34),
        boxShadow: [
          BoxShadow(color: AppColors.ledge(color), offset: const Offset(0, 3)),
        ],
      ),
      child: Icon(icon, size: size * 0.52, color: Colors.white),
    );
  }
}

/// A centred picture and a line of text for empty lists.
class KidEmpty extends StatelessWidget {
  final IconData icon;
  final String text;

  const KidEmpty(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Wiggle(
              child: Container(
                width: 112,
                height: 112,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 56, color: AppColors.purple),
              ),
            ),
            const SizedBox(height: 18),
            Text(text,
                textAlign: TextAlign.center,
                style: kid(17,
                    weight: FontWeight.w700, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

/// The wavy top edge used where a white sheet meets a violet header.
class WaveClipper extends CustomClipper<Path> {
  final double amplitude;
  const WaveClipper({this.amplitude = 14});

  @override
  Path getClip(Size size) {
    final w = size.width;
    final a = amplitude;
    final p = Path()..moveTo(0, a);
    p.quadraticBezierTo(w * 0.125, 0, w * 0.25, a);
    p.quadraticBezierTo(w * 0.375, a * 2, w * 0.5, a);
    p.quadraticBezierTo(w * 0.625, 0, w * 0.75, a);
    p.quadraticBezierTo(w * 0.875, a * 2, w, a);
    p.lineTo(w, size.height);
    p.lineTo(0, size.height);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant WaveClipper old) => old.amplitude != amplitude;
}

/// A quiet outlined pill button, for the second choice on a screen.
class KidOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final double height;

  const KidOutlineButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.color = AppColors.primary,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color, width: 2.5),
          shape: const StadiumBorder(),
          textStyle:
              GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        child: Text(label),
      ),
    );
  }
}
