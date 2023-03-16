class Path {
  List<String> pathList = List.filled(9, "", growable: false);
  int count = 0;

  Path(String dotPath, String sep) {
    if (dotPath == "") {
      count = 0;
      return;
    }
    final l = dotPath.split(sep);
    for (int i = 0; i < l.length; i++) {
      pathList[i] = l[i];
    }
    count = l.length;
  }

  factory Path.empty() {
    return Path("","");
  }

  factory Path.fromDotPath(String dotPath) {
    return Path(dotPath,'.');
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

  String getRoot() {
    if (isEmpty()) {
      return "";
    }
    return pathList[0];
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
