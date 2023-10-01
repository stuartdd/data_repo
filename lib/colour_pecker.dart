import 'package:flutter/material.dart';
import 'config.dart';

class ColorPecker extends StatefulWidget {
  final List<Color> indexedList;
  final int startIndex;
  final double width;
  final int columns;
  final int rows;
  final Color background;
  final Function(Color, int) onSelect;
  const ColorPecker(this.width, this.indexedList, this.startIndex, this.columns, this.rows, this.background, this.onSelect, {super.key});

  @override
  State<ColorPecker> createState() => _ColorPeckerState();
}

const _gap = 5.0;

class _ColorPeckerState extends State<ColorPecker> {

  Color _getColor(int row, int col) {
    final i = widget.startIndex + (row * widget.columns) + col;
    if (i >= widget.indexedList.length) {
      return Colors.black;
    }
    return widget.indexedList[i];
  }

  @override
  Widget build(BuildContext context) {
    final wide = widget.width - 50;
    final cellWidth = (wide / widget.columns) - _gap;
    return Container(
      color: widget.background,
      width: widget.width,
      child: SingleChildScrollView(
        child: ListBody(
          children: [
            for (int row = 0; row < widget.rows; row++) ...[
              Row(
                children: [
                  for (int col = 0; col < widget.columns; col++) ...[
                    InkWell(
                      onTap: () {
                        final index = widget.startIndex + (row * widget.columns) + col;
                        widget.onSelect(widget.indexedList[index], index);
                      }, // Handle your callback
                      child: Container(height: cellWidth, width: cellWidth, color: _getColor(row, col)),
                    ),
                    const SizedBox(width: _gap),
                  ],
                ],
              ),
              const SizedBox(height: _gap),
            ],
          ],
        ),
      ),
    );
  }
}
