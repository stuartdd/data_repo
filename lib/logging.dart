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
  Function()? onUpdate;

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
      if (onUpdate != null) {
        onUpdate!();
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
    if (onUpdate != null) {
      onUpdate!();
    }
  }
}

class InterfaceNotImplementedException implements Exception {
  final String message;
  InterfaceNotImplementedException(this.message);
  String error() {
    return message;
  }
}

abstract class ScrollAble {
  void scrollBottom();
  void scrollTop();
  bool get autoFollow;
}

class LogContentManager implements ScrollAble {
  late final GlobalKey key;
  late final Widget widget;
  LogContentManager({required Logger log, required bool scrollToEndOnStart, required AppThemeData appThemeData, required Function(String, String?, String) onTapLink}) {
    key = GlobalKey();
    widget = _LogContent(key: key, log: log, scrollToEndOnStart: scrollToEndOnStart, appThemeData: appThemeData, onTapLink: onTapLink);
  }

  ScrollAble _getInstance() {
    final cs = key.currentState;
    if (cs == null) {
      throw InterfaceNotImplementedException("LogContentManager: Global key returned null 'currentState'");
    }
    if (cs is ScrollAble) {
      return (cs as ScrollAble);
    }
    throw InterfaceNotImplementedException("LogContentManager:ScrollAble Global key 'currentState' returned type:${cs.runtimeType}");
  }

  @override
  void scrollBottom() {
    _getInstance().scrollBottom();
  }

  @override
  void scrollTop() {
    _getInstance().scrollTop();
  }

  @override
  bool get autoFollow {
    return _getInstance().autoFollow;
  }
}

class _LogContent extends StatefulWidget {
  final Logger log;
  final AppThemeData appThemeData;
  final bool scrollToEndOnStart;
  final Function(String, String?, String) onTapLink;
  const _LogContent({super.key, required this.log, required this.scrollToEndOnStart, required this.appThemeData, required this.onTapLink});

  @override
  State<_LogContent> createState() => _LogContentState();
}

class _LogContentState extends State<_LogContent> implements ScrollAble {
  final _scrollController = ScrollController(keepScrollOffset: true);
  bool _autoFollow = true;
  bool _waitingToScroll = false;

  void _scrollBottomLater(int ms) {
    if (_waitingToScroll) {
      return;
    }
    _waitingToScroll = true;
    Timer(
      Duration(milliseconds: ms),
          () {
        scrollBottom();
      },
    );
  }

  @override
  void initState() {
    super.initState();
    widget.log.onUpdate = () {
      // This only happens if the log is updated!
      if (_autoFollow) {
        _scrollBottomLater(127);
      }
    };
    if (widget.scrollToEndOnStart) {
      _scrollBottomLater(100);
    }
  }


  @override
  void scrollBottom() {
    setState(() {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      _waitingToScroll = false;
      _autoFollow = true;
    });
  }

  @override
  void scrollTop() {
    setState(() {
      _scrollController.jumpTo(_scrollController.position.minScrollExtent);
      _autoFollow = false;
    });
  }

  @override
  bool get autoFollow {
    return _autoFollow;
  }

  @override
  void dispose() {
    widget.log.onUpdate = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return markdownDisplayWidget(true, widget.log.toString(),  widget.appThemeData.primary.lightest, scrollController: _scrollController, (text, href, title) {
       widget.onTapLink(text, href, title);
    });
  }
}

Future<void> showLogDialog(final BuildContext context, final AppThemeData appThemeData, final ScreenSize screenSize, final Logger log, final bool Function(String) onTapLink) async {
  final logContentManager = LogContentManager(
      log: log,
      scrollToEndOnStart: true,
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
          child: logContentManager.widget,
        ),
        actions: <Widget>[
          Row(
            children: [
              appThemeData.iconGapBox(2),
              IndicatorIconManager(
                const [Icons.playlist_play, Icons.playlist_remove],
                size: appThemeData.iconSize,
                color: appThemeData.screenForegroundColour(true),
                getState: (c, widget) {
                  return logContentManager.autoFollow ? 0 : 1;
                },
                period: 500,
              ).widget,
              appThemeData.iconGapBox(1),
              DetailTextButton(
                appThemeData: appThemeData,
                text: "TOP",
                onPressed: (button) {
                  logContentManager.scrollTop();
                },
              ),
              DetailTextButton(
                appThemeData: appThemeData,
                text: "FOLLOW",
                onPressed: (button) {
                  logContentManager.scrollBottom();
                },
              ),
              DetailTextButton(
                appThemeData: appThemeData,
                text: "DONE",
                onPressed: (button) {
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
