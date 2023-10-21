import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'config.dart';
import 'data_types.dart';
import 'detail_buttons.dart';

class LogEntry {
  final String _text;
  int count = 1;
  LogEntry? next;
  LogEntry(this._text);

  factory LogEntry.empty() {
    return LogEntry("");
  }

  void inc() {
    count++;
  }

  bool get isEmpty {
    return _text.isEmpty;
  }

  bool get isNotEmpty {
    return _text.isNotEmpty;
  }

  bool equals(String t) {
    return (_text == t);
  }

  String get text {
    if (count > 1) {
      return "$count $_text";
    }
    return _text;
  }
}

class Logger {
  final int maxLength;
  final bool asMarkdown;
  String previousLog = "";
  LogEntry? first;
  LogEntry? last;
  int length = 0;
  Function()? update;

  Logger(this.maxLength, this.asMarkdown) {
    last = first;
  }

  @override
  String toString() {
    if (first == null) {
      return "";
    }
    StringBuffer sb = StringBuffer();
    var l = first;
    while (l != null) {
      if (l.next == null) {
        sb.write(l.text);
      } else {
        sb.writeln(l.text);
        if (asMarkdown) {
          sb.writeln();
        }
      }
      l = l.next;
    }
    return sb.toString();
  }

  log(String text) {
    if (last != null && last!.equals(text)) {
      last!.inc();
      if (update != null) {
        update!();
      }
      return;
    }

    previousLog = text;
    if (first == null) {
      first = LogEntry(text);
      last = first;
      length = 1;
    } else {
      final le = LogEntry(text);
      final l = last;
      last = le;
      l!.next = le;
      if (length >= maxLength) {
        first = first!.next;
      } else {
        length++;
      }
    }
    if (update != null) {
      update!();
    }
  }
}

class LogContent extends StatefulWidget {
  final Logger log;
  final AppThemeData appThemeData;

  final Function(String, String?, String) onTapLink;
  final _scrollController = ScrollController(keepScrollOffset: true);
  bool _autoScroll = true;

  LogContent({super.key, required this.log, required this.appThemeData, required this.onTapLink});

  void scrollBottom() {
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    _autoScroll = true;
  }

  void scrollTop() {
    _scrollController.jumpTo(_scrollController.position.minScrollExtent);
    _autoScroll = false;
  }

  bool get autoScroll {
    return _autoScroll;
  }

  @override
  State<LogContent> createState() => _LogContentState();
}

class _LogContentState extends State<LogContent> {
  @override
  void initState() {
    widget.log.update = () {
      if (widget._autoScroll) {
        widget._scrollController.jumpTo(widget._scrollController.position.maxScrollExtent);
      }
      Timer(
        const Duration(milliseconds: 127),
        () {
          setState(() {});
        },
      );
    };
    super.initState();
  }

  @override
  void dispose() {
    widget.log.update = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Markdown(
      controller: widget._scrollController,
      data: widget.log.toString(),
      selectable: true,
      shrinkWrap: true,
      styleSheetTheme: MarkdownStyleSheetBaseTheme.platform,
      onTapLink: (text, href, title) {
        widget.onTapLink(text, href, title);
      },
    );
  }
}

Future<void> showLogDialog(final BuildContext context, final AppThemeData appThemeData, final ScreenSize screenSize, final Logger log, final bool Function(String) onTapLink) async {

  final logContent = LogContent(
      log: log,
      appThemeData: appThemeData,
      onTapLink: (text, href, title) {
        bool ok = true;
        if (href == null) {
          ok = onTapLink(text);
        } else {
          ok = onTapLink(href);
        }
        if (ok) {
          Navigator.of(context).pop();
        }
      });

  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: appThemeData.dialogBackgroundColor,
        insetPadding: const EdgeInsets.all(0),
        title: Text('Event Log', style: appThemeData.tsMedium),
        content: Container(
          height: screenSize.height,
          width: screenSize.width,
          color: appThemeData.primary.dark,
          child: logContent,
        ),
        actions: <Widget>[
          Row(
            children: [
              const SizedBox(width: 10),
              IndicatorIconManager(
                const [Icons.playlist_play, Icons.playlist_remove],
                size: appThemeData.iconSize,
                color: appThemeData.screenForegroundColour(true),
                getState: (c, widget) {
                  return logContent.autoScroll ? 0 : 1;
                },
                period: 500,
              ).widget,
              const SizedBox(width: 10),
              DetailButton(
                appThemeData: appThemeData,
                text: "TOP",
                onPressed: () {
                  logContent.scrollTop();
                },
              ),
              DetailButton(
                appThemeData: appThemeData,
                text: "BOTTOM",
                onPressed: () {
                  logContent.scrollBottom();
                },
              ),
              DetailButton(
                appThemeData: appThemeData,
                text: "DONE",
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          )
        ],
      );
    },
  );
}
