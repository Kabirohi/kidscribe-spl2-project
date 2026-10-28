import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/learn/trace_items_cubit.dart';
import '../../models/trace_item.dart';
import '../../services/progress_service.dart';
import '../../theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/art.dart';
import '../../widgets/common.dart';
import '../../widgets/fun.dart';
import 'tracing_screen.dart';

/// A grid of tracing items (Stage 1 strokes, or the letters of one family).
/// Each card shows the shape, its name, and the stars earned so far.
class TraceItemsScreen extends StatelessWidget {
  final String title;
  final List<TraceItem> items;

  const TraceItemsScreen({super.key, required this.title, required this.items});

  // Card colors cycle through the app palette.
  static const _cardColors = [
    Color(0xFF6C4BFF),
    Color(0xFF14B8A6),
    Color(0xFFFF5FA2),
    Color(0xFFFFA41B),
    Color(0xFF2EB5F0),
  ];

  @override
  Widget build(BuildContext context) {
    // More columns on wide tablet screens, fewer on phones.
    final width = MediaQuery.of(context).size.width;
    final columns = width > 900
        ? 5
        : width > 600
            ? 4
            : 3;

    return BlocProvider(
      create: (ctx) =>
          TraceItemsCubit(progress: ctx.read<ProgressService>())..load(),
      child: BlocBuilder<TraceItemsCubit, Map<String, int>>(
        builder: (context, stars) => KidPage(
          color: const Color(0xFF14B8A6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KidHeader(title),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) => PopIn(
                    delay: Duration(milliseconds: 40 + i * 50),
                    child: _card(context, i, stars[items[i].id] ?? 0,
                        _cardColors[i % _cardColors.length]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, int i, int earned, Color color) {
    final item = items[i];
    final cubit = context.read<TraceItemsCubit>();
    return Bouncy(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TracingScreen(items: items, startIndex: i)),
      ).then((_) => cubit.load()),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(color: AppColors.line, offset: Offset(0, 5)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
        child: Column(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.ledge(color, 0.16),
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(item.glyph,
                          style: GoogleFonts.fredoka(
                              fontSize: 40,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(item.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kid(13.5, weight: FontWeight.w800)),
            const SizedBox(height: 4),
            KidStars(earned, size: 18),
          ],
        ),
      ),
    );
  }
}
