import 'package:flutter/material.dart';

class ColorPecker extends StatefulWidget {
  final List<Color> indexedList;
  final double width;
  final int columns;
  final int rows;
  final bool rowSelect;
  final Color background;
  final Color selectColor;

  final Color current;
  final Function(Color, int) onSelect;
  const ColorPecker(this.width, this.indexedList, this.current, this.columns, this.rows, this.background, this.selectColor, this.onSelect, {super.key, this.rowSelect = true});

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

  Color _getSelectRowColor(int row, int col) {
    if (widget.rowSelect) {
      return selectedRow == row ? widget.selectColor : widget.background;
    }
    return (selectedRow == row && selectedCol == col) ? widget.selectColor : widget.background;
  }

  @override
  Widget build(BuildContext context) {
    final wide = widget.width - 50 - (_gap * widget.columns);
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
                    Container(
                      padding: const EdgeInsets.all(_gap),
                      color: _getSelectRowColor(row, col),
                      child: InkWell(
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
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
