import 'package:flutter/material.dart';

class AnimatedPillStrip extends StatefulWidget {
  final int total;
  final int taken;
  final Color filledColor;
  final Color emptyColor;

  const AnimatedPillStrip({
    Key? key,
    required this.total,
    required this.taken,
    this.filledColor = Colors.white,
    this.emptyColor = Colors.yellow,
  }) : super(key: key);

  @override
  State<AnimatedPillStrip> createState() => _AnimatedPillStripState();
}

class _AnimatedPillStripState extends State<AnimatedPillStrip> {
  bool hasAnimated = false;

  @override
  void didUpdateWidget(covariant AnimatedPillStrip oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Trigger animation only once when all pills are taken
    if (widget.taken == widget.total && !hasAnimated) {
      hasAnimated = true;
      setState(() {}); // show empty visually
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() {}); // refill
      });
    }

    // Reset for next time if not full
    if (widget.taken != widget.total) {
      hasAnimated = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Display taken pills; show empty first if animating
    final displayTaken =
    (widget.taken == widget.total && hasAnimated) ? 0 : widget.taken;

    final pills = List.generate(widget.total, (i) {
      final isTaken = i < displayTaken;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.all(4),
        width: 28,
        height: 16,
        decoration: BoxDecoration(
          color: isTaken
              ? widget.filledColor.withValues(alpha: 0.2)
              : widget.emptyColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.6), width: 1.2),
        ),
      );
    });

    // Break pills into rows of 5
    final rows = <Widget>[];
    for (int i = 0; i < pills.length; i += 5) {
      rows.add(Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: pills.skip(i).take(5).toList(),
      ));
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: rows,
    );
  }
}
