class LogEntry {
  final String text;
  LogEntry? next;
  LogEntry(this.text);

  factory LogEntry.empty() {
    return LogEntry("");
  }

  bool get isEmpty {
    return text.isEmpty;
  }

  bool get isNotEmpty {
    return text.isNotEmpty;
  }
}

class Logger {
  final int maxLength;
  final bool asMarkdown;
  LogEntry? first;
  LogEntry? last;
  int length = 0;

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
  }
}
