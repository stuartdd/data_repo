import 'package:flutter/material.dart';
import 'dart:async';

const _buttonBorderStyle = BorderSide(color: Colors.black, width: 2);
const _buttonBorderStyleGrey = BorderSide(color: Colors.grey, width: 2);
const _styleSmall = TextStyle(fontFamily: 'Code128', fontSize: 20.0, color: Colors.black);
const _styleSmallDisabled = TextStyle(fontFamily: 'Code128', fontSize: 20.0, color: Colors.grey);

class DetailIconButton extends StatefulWidget {
  final bool show;
  final Function() onPressed;
  final int timerMs;
  final Icon icon;
  final String tooltip;
  final MaterialColor materialColor;
  const DetailIconButton({super.key, this.show = true, required this.onPressed, this.timerMs = 100, required this.icon, this.tooltip = "", required this.materialColor});
  @override
  State<DetailIconButton> createState() => _DetailIconButton();
}

class _DetailIconButton extends State<DetailIconButton> {
  bool grey = false;

  @override
  Widget build(BuildContext context) {
    if (widget.show) {
      return IconButton(
        color: grey ? widget.materialColor.shade900 : widget.materialColor.shade900,
        icon: widget.icon,
        tooltip: widget.tooltip,
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
      );
    } else {
      return const SizedBox(width: 0);
    }
  }
}

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
