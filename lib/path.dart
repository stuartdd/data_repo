class Path {
  final List<String> pathList = List.filled(9, "", growable: false);
  int count = 0;

  Path(List<String> list) {
    for (int i = 0; i < list.length; i++) {
      pathList[i] = list[i];
    }
    count = list.length;
  }

  Path cloneAppend(List<String> app) {
    final List<String> l = List.empty(growable: true);
    for (int i = 0; i<count; i++) {
      l.add(pathList[i]);
    }
    l.addAll(app);
    return Path(l);
  }

  factory  Path.empty() {
    return Path([]);
  }

  factory Path.fromDotPath(String dotPath) {
    return Path(dotPath.split('.'));
  }

  factory Path.fromList(List<String> list) {
    return Path(list);
  }

  bool isInMap(Map<String, dynamic> map) {
    if (isEmpty()) {
      return false;
    }
    var m = map;
    for (int i = 0; i < count; i++) {
      var x = m[pathList[i]];
      if (x == null) {
        return false;
      }
      m = x;
    }
    return true;
  }

  int length() {
    return count;
  }

  bool isEmpty() {
    return (count == 0);
  }

  bool isNotEmpty() {
    return (count > 0);
  }

  String peek(int i) {
    if (i >= 0 && i < count) {
      return pathList[i];
    }
    return "";
  }

  String getRoot() {
    if (isEmpty()) {
      return "";
    }
    return pathList[0];
  }

  String getLast() {
    if (isEmpty()) {
      return "";
    }
    return pathList[count - 1];
  }

  void push(String p) {
    pathList[count] = p;
    count++;
  }

  String pop() {
    if (count > 0) {
      count--;
      return pathList[count];
    }
    return "";
  }

  @override
  String toString() {
    StringBuffer sb = StringBuffer();
    for (int i = 0; i < count; i++) {
      sb.write(pathList[i]);
      if (i < (count - 1)) {
        sb.write(".");
      }
    }
    return sb.toString();
  }
}
