import 'package:flutter/material.dart';
import 'dart:async';

const _buttonBorderStyle = BorderSide(color: Colors.black, width: 2);
const _buttonBorderStyleGrey = BorderSide(color: Colors.grey, width: 2);
const _styleSmall = TextStyle(fontFamily: 'Code128', fontSize: 20.0, color: Colors.black);
const _styleSmallDisabled = TextStyle(fontFamily: 'Code128', fontSize: 20.0, color: Colors.grey);

class DetailButton extends StatefulWidget {
  const DetailButton({super.key, required this.onPressed, required this.text, this.timerMs = 100, this.show = true});
  final bool show;
  final Function() onPressed;
  final String text;
  final int timerMs;
  @override
  State<DetailButton> createState() => _DetailButtonState();
}

class _DetailButtonState extends State<DetailButton> {
  bool grey = false;

  @override
  Widget build(BuildContext context) {
    if (widget.show) {
      return Row(
        children: [
          OutlinedButton(
            onPressed: () {
              if (grey) {
                return;
              }
              setState(() {
                grey = true;
              });
              Timer(const Duration(milliseconds: 5), () {
                widget.onPressed();
                Timer(Duration(milliseconds: 15 + widget.timerMs), () {
                  setState(() {
                    grey = false;
                  });
                });
              });
            },
            style: OutlinedButton.styleFrom(side: grey ? _buttonBorderStyleGrey : _buttonBorderStyle),
            child: Text(widget.text, style: grey ? _styleSmallDisabled : _styleSmall),
          ),
          const SizedBox(width: 8)
        ],
      );
    } else {
      return const SizedBox(width: 0);
    }
  }
}
