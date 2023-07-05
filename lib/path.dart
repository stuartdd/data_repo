class PathProperties {
  bool _renamed = false;
  bool _updated = false;
  bool groupSelect = false;
  bool cut = false;
  PathProperties(this._updated, this.groupSelect, this.cut, this._renamed);

  factory PathProperties.clear() {
    return PathProperties(false, false, false, false);
  }

  @override
  String toString() {
    return "rename:$_renamed updated:$_updated group:$groupSelect cut:$cut";
  }

  void clear() {
    _renamed = false;
    _updated = false;
    cut = false;
    groupSelect = false;
  }

  bool get isEmpty {
    return !isNotEmpty;
  }

  bool get isNotEmpty {
    return _renamed || _updated || groupSelect || cut;
  }

  bool get changed {
    return _updated || _renamed;
  }

  bool get updated {
    return _updated;
  }

  void set updated(bool b) {
    _updated = b;
  }

  void set renamed(bool b) {
    _renamed = b;
  }

  bool get renamed {
    return _renamed;
  }
}

class PathPropertiesList {
  final Map<String, PathProperties> _list = {};

  bool get isEmpty {
    return _list.isEmpty;
  }

  bool get isNotEmpty {
    return _list.isNotEmpty;
  }

  @override
  String toString() {
    if (_list.isEmpty) {
      return "";
    }
    StringBuffer sb = StringBuffer();
    _list.forEach((key, value) {
      sb.write("Path:$key = $value\n");
    });
    return sb.toString();
  }

  void clear() {
    _list.clear();
  }

  void setGroupSelect(Path p) {
    final ps = p.toString();
    final pfp = _propertiesForPath(ps);
    pfp.groupSelect = !pfp.groupSelect;
    if (pfp.isEmpty) {
      _list.remove(ps);
    } else {
      _list[ps] = pfp;
    }
  }

  void setCut(Path p, bool set) {
    final ps = p.toString();
    final pfp = _propertiesForPath(ps);
    pfp.cut = set;
    if (pfp.isEmpty) {
      _list.remove(ps);
    } else {
      _list[ps] = pfp;
    }
  }

  void setRenamed(Path p) {
    final ps = p.toString();
    final pfp = _propertiesForPath(ps);
    pfp._renamed = true;
    _list[ps] = pfp;
  }

  void setUpdated(Path p) {
    final ps = p.toString();
    final pfp = _propertiesForPath(ps);
    pfp._updated = true;
    _list[ps] = pfp;
  }

  PathProperties propertiesForPath(Path p) {
    return _propertiesForPath(p.toString());
  }

  PathProperties _propertiesForPath(String p) {
    var plp = _list[p];
    plp ??= PathProperties.clear();
    return plp;
  }
}

const int initialSize = 9;

class PathNodes {
  final List<dynamic> nodes;
  final bool error;
  PathNodes(this.nodes, this.error);

  factory PathNodes.from(Map<String, dynamic> json, Path path) {
    if (path.isEmpty) {
      return PathNodes([], true);
    }
    if (json.isEmpty) {
      return PathNodes([], true);
    }
    var nn = json;
    final List<dynamic> nodes = List.empty(growable: true);
    for (var i = 0; i < path.length; i++) {
      final name = path.peek(i);
      var node = nn[name];
      if (node == null) {
        return PathNodes(nodes, true);
      }
      nodes.add(node);
      if (node is Map<String, dynamic>) {
        nn = node;
      } else {
        break;
      }
    }
    return PathNodes(nodes, false);
  }

  factory PathNodes.empty() {
    return PathNodes([], true);
  }

  bool alreadyContainsName(String name) {
    if (lastNodeIsMap) {
      if (lastNodeAsMap!.containsKey(name)) {
        return true;
      }
    } else {
      if (lastNodeParent!.containsKey(name)) {
        return true;
      }
    }
    return false;
  }

  bool get lastNodeIsMap {
    if (nodes.isEmpty) {
      return false;
    }
    return (nodes[nodes.length - 1] is Map<String, dynamic>);
  }

  bool get lastNodeIsData {
    if (nodes.isEmpty) {
      return false;
    }
    return nodes[nodes.length - 1] is! Map<String, dynamic>;
  }

  Map<String, dynamic>? get lastNodeAsMap {
    if (nodes.isNotEmpty) {
      return nodes[nodes.length - 1] as Map<String, dynamic>;
    }
    return null;
  }

  bool get lastNodeHasParent {
    return (nodes.length > 1);
  }

  Map<String, dynamic>? get lastNodeParent {
    if (nodes.length > 1) {
      return nodes[nodes.length - 2] as Map<String, dynamic>;
    }
    return null;
  }

  dynamic? get lastNodeAsData {
    if (nodes.isNotEmpty) {
      return nodes[nodes.length - 1];
    }
    return null;
  }

  bool get isEmpty {
    return nodes.isEmpty;
  }

  bool get isNotEmpty {
    return nodes.isNotEmpty;
  }

  int get length {
    return nodes.length;
  }

  @override
  String toString() {
    StringBuffer sb = StringBuffer();
    sb.write("${error ? 'Error' : 'OK'}:");
    for (int i = 0; i < nodes.length; i++) {
      sb.write(nodes[i].toString());
      sb.write('|');
    }
    return sb.toString();
  }
}

class Path {
  final List<String> pathList = List.filled(initialSize, "", growable: false);
  int count = 0;

  Path(List<String> list) {
    count = 0;
    for (int i = 0; i < list.length; i++) {
      if (list[i].isNotEmpty) {
        pathList[i] = list[i];
        count++;
      }
    }
  }

  PathNodes pathNodes(Map<String, dynamic> m) {
    return PathNodes.from(m, this);
  }

  bool isNotEqual(Path other) {
    return !isEqual(other);
  }

  bool isEqual(Path other) {
    if (count != other.count) {
      return false;
    }
    for (int i = 0; i < count; i++) {
      if (pathList[i] != other.pathList[i]) {
        return false;
      }
    }
    return true;
  }

  Path cloneAppendList(List<String> app) {
    final p = Path.empty();
    for (int i = 0; i < count; i++) {
      p.push(pathList[i]);
    }
    for (int i = 0; i < app.length; i++) {
      p.push(app[i]);
    }
    return p;
  }

  Path cloneRename(String newName) {
    final p = Path.empty();
    for (int i = 0; i < count - 1; i++) {
      p.push(pathList[i]);
    }
    p.push(newName);
    return p;
  }

  Path cloneReversed() {
    final p = Path.empty();
    for (int i = count - 1; i >= 0; i--) {
      p.push(pathList[i]);
    }
    return p;
  }

  Path cloneParentPath() {
    final p = Path.empty();
    for (int i = 0; i < count - 1; i++) {
      p.push(pathList[i]);
    }
    return p;
  }

  factory Path.empty() {
    return Path([]);
  }

  factory Path.fromDotPath(String dotPath) {
    return Path(dotPath.split('.'));
  }

  factory Path.fromList(List<String> list) {
    return Path(list);
  }

  bool isInMap(Map<String, dynamic> map) {
    if (count == 0) {
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

  bool get hasParent {
    return (count > 1);
  }

  int get length {
    return count;
  }

  bool get isEmpty {
    return (count == 0);
  }

  bool get isNotEmpty {
    return (count > 0);
  }

  String peek(int i) {
    if (i >= 0 && i < count) {
      return pathList[i];
    }
    return "";
  }

  String get root {
    if (count == 0) {
      return "";
    }
    return pathList[0];
  }

  String get last {
    if (count == 0) {
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
