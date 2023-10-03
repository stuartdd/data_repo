import 'package:flutter/material.dart';

class ColorPecker extends StatefulWidget {
  final List<Color> indexedList;
  final double width;
  final int columns;
  final int rows;
  final bool rowSelect;
  final Color background;
  final Color selectColor;
  final int selectedIndex;
  final Function(Color, int) onSelect;
  const ColorPecker(this.width, this.indexedList, this.selectedIndex, this.columns, this.rows, this.background, this.selectColor, this.onSelect, {super.key, this.rowSelect = true});

  @override
  State<ColorPecker> createState() => _ColorPeckerState();
}

const _gap = 2.0;

class _ColorPeckerState extends State<ColorPecker> {
  int selectedRow = -1;
  int selectedCol = -1;

  @override
  initState() {
    super.initState();
    final i = widget.selectedIndex;
    if (i >= 0 && i < widget.indexedList.length) {
      selectedRow = i ~/ widget.columns;
      if (selectedRow == 0) {
        selectedCol = i;
      } else {
        selectedCol = i % selectedRow;
      }
    } else {
      selectedCol = -1;
      selectedRow = -1;
    }
  }

  int setSelected(int row, int col) {
    if (selectedRow != row || selectedCol != col) {
      selectedCol = col;
      selectedRow = row;
      return (row * widget.columns) + col;
    }
    return -1;
  }

  Color _getColor(int row, int col) {
    final i = (row * widget.columns) + col;
    if (i >= widget.indexedList.length) {
      return Colors.black;
    }
    return widget.indexedList[i];
  }

  Color _getSelectRowColor(int row, int col) {
    if (widget.rowSelect) {
      if (selectedRow == row) {
        return widget.selectColor;
      }
    } else {
      if (selectedRow == row && selectedCol == col) {
        return widget.selectColor;
      }
    }
    return widget.background;
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
                          final index = setSelected(row, col);
                          if (index >= 0) {
                            setState(() {
                              widget.onSelect(widget.indexedList[index], index);
                            });
                          }
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
