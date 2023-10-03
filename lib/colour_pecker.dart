import 'package:flutter/material.dart';

class ColorPecker extends StatefulWidget {
  final List<Color> indexedList;
  final double width;
  final int columns;
  final int rows;
  final Color background;
  final Function(Color, int) onSelect;
  const ColorPecker(this.width, this.indexedList, this.columns, this.rows, this.background, this.onSelect, {super.key});

  @override
  State<ColorPecker> createState() => _ColorPeckerState();
}

const _gap = 2.0;

class _ColorPeckerState extends State<ColorPecker> {
  int selectedRow = -1;
  int selectedCol = -1;
  Color _getColor(int row, int col) {
    final i = (row * widget.columns) + col;
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
              Container(
                padding: const EdgeInsets.fromLTRB(_gap, _gap, 0, _gap),
                color: selectedRow == row ? Colors.white : widget.background,
                child: Row(
                  children: [
                    for (int col = 0; col < widget.columns; col++) ...[
                      InkWell(
                        onTap: () {
                          setState(() {
                            selectedCol = col;
                            selectedRow = row;
                            final index = (row * widget.columns) + col;
                            widget.onSelect(widget.indexedList[index], index);
                          });
                        }, // Handle your callback
                        child: Container(height: cellWidth, width: cellWidth, color: _getColor(row, col)),
                      ),
                      const SizedBox(width: _gap),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
