import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// Opens the "Parents only" check. Returns true when a grown-up passed it.
///
/// Sync & Premium is for parents, so before it opens we ask for a year of
/// birth that belongs to an adult (the same simple gate many kids' apps use).
Future<bool> askParentGate(BuildContext context) async {
  final ok = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const ParentGateScreen(),
    ),
  );
  return ok == true;
}

class ParentGateScreen extends StatefulWidget {
  const ParentGateScreen({super.key});

  @override
  State<ParentGateScreen> createState() => _ParentGateScreenState();
}

class _ParentGateScreenState extends State<ParentGateScreen> {
  String _digits = '';
  String? _error;

  void _tap(String d) {
    if (_digits.length >= 4) return;
    setState(() {
      _digits += d;
      _error = null;
    });
    if (_digits.length == 4) _check();
  }

  void _back() {
    if (_digits.isEmpty) return;
    setState(() {
      _digits = _digits.substring(0, _digits.length - 1);
      _error = null;
    });
  }

  void _check() {
    final year = int.tryParse(_digits) ?? 0;
    final latest = DateTime.now().year - 18;
    if (year >= 1900 && year <= latest) {
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) Navigator.pop(context, true);
      });
    } else {
      Future.delayed(const Duration(milliseconds: 260), () {
        if (!mounted) return;
        setState(() {
          _digits = '';
          _error = 'This part is for grown-ups. Please try again.';
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 26),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Parents only',
                      style: GoogleFonts.nunito(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                  const SizedBox(height: 6),
                  Text('Please enter your year of birth:',
                      style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.9))),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 4; i++) _slot(i),
                    ],
                  ),
                  SizedBox(
                    height: 44,
                    child: Center(
                      child: Text(_error ?? '',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.sun)),
                    ),
                  ),
                  for (final row in const [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final d in row) _key(d, () => _tap(d)),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 90),
                      _key('0', () => _tap('0')),
                      SizedBox(
                        width: 90,
                        height: 76,
                        child: IconButton(
                          onPressed: _back,
                          icon: const Icon(Icons.backspace_rounded,
                              color: Colors.white, size: 28),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _slot(int i) {
    final filled = i < _digits.length;
    return Container(
      width: 52,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: Colors.white.withValues(alpha: filled ? 1 : 0.6),
              width: 3),
        ),
      ),
      child: Text(filled ? _digits[i] : '',
          style: GoogleFonts.nunito(
              fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white)),
    );
  }

  Widget _key(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 76,
          height: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.18),
          ),
          child: Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
        ),
      ),
    );
  }
}
