const _updatedNotForUnDo = "~";

class PathProperties {
  String renamedFrom = "";
  String updatedFrom = "";
  bool groupSelect = false;
  PathProperties(this.updatedFrom, this.groupSelect, this.renamedFrom);

  factory PathProperties.empty() {
    return PathProperties("", false, "");
  }

  @override
  String toString() {
    return "rename:$renamed updated:$updated group:$groupSelect";
  }

  void clear() {
    renamedFrom = "";
    updatedFrom = "";
    groupSelect = false;
  }

  bool get isEmpty {
    return !isNotEmpty;
  }

  bool get isNotEmpty {
    return renamed || updated || groupSelect;
  }

  bool get renamed {
    return renamedFrom.isNotEmpty;
  }

  bool get canUndoRename {
    return (renamedFrom != _updatedNotForUnDo) && renamedFrom.isNotEmpty;
  }

  bool get canUndoUpdate {
    return (updatedFrom != _updatedNotForUnDo) && updatedFrom.isNotEmpty;
  }

  bool get updated {
    return updatedFrom.isNotEmpty;
  }

  bool get changed {
    return updated || renamed;
  }
}

class PathPropertiesList {
  final Map<String, PathProperties> _list = {};
  final void Function(String)? log;
  PathPropertiesList({this.log});

  bool get isEmpty {
    return _list.isEmpty;
  }

  bool get isNotEmpty {
    return _list.isNotEmpty;
  }

  int get length {
    return _list.length;
  }

  Map<String, PathProperties> get groupSelectsClone {
    final Map<String, PathProperties> clone = <String, PathProperties>{};
    for (var k in _list.keys) {
      final v = _list[k];
      if (v != null) {
        if (v.groupSelect) {
          clone[k] = v;
        }
      }
    }
    return clone;
  }

  bool get hasGroupSelects {
    for (var v in _list.values) {
      if (v.groupSelect) {
        return true;
      }
    }
    return false;
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
    if (log != null) {
      log!("__NODE__ LIST CLEARED");
    }
  }

  List<String> cloneKeys() {
    final List<String> keys = [];
    for (var k in _list.keys) {
      keys.add(k);
    }
    return keys;
  }

  void clearGroupSelect() {
    for (var k in cloneKeys()) {
      final v = _list[k];
      if (v != null) {
        v.groupSelect = false;
        if (v.isEmpty) {
          _list.remove(k);
        }
      }
    }
    if (log != null) {
      log!("__NODE__ GROUP SELECTION CLEARED");
    }
  }

  void setGroupSelect(final Path p) {
    final ps = p.toString();
    final pfp = _propertiesForPath(ps);
    pfp.groupSelect = !pfp.groupSelect;
    if (log != null) {
      log!("__NODE__ GROUP [$p] ${pfp.groupSelect ? 'YES' : 'NO'}");
    }
    if (pfp.isEmpty) {
      _list.remove(ps);
    } else {
      _list[ps] = pfp;
    }
  }

  void setRenamed(final Path p, {String from = _updatedNotForUnDo}) {
    final ps = p.toString();
    final pfp = _propertiesForPath(ps);
    if (!pfp.canUndoRename) {
      pfp.renamedFrom = from;
    }
    if (log != null) {
      log!("__NODE__ RENAME [$p] ${pfp.renamed ? 'YES' : 'NO'}");
    }
    _list[ps] = pfp;
  }

  void setUpdated(final Path p, {String from = _updatedNotForUnDo}) {
    final ps = p.toString();
    final pfp = _propertiesForPath(ps);
    if (!pfp.canUndoUpdate) {
      pfp.updatedFrom = from;
    }
    if (log != null) {
      log!("__NODE__ UPDATED [$p]  ${pfp.updated ? 'YES' : 'NO'}");
    }
    _list[ps] = pfp;
  }

  PathProperties propertiesForPath(final Path p) {
    return _propertiesForPath(p.toString());
  }

  PathProperties _propertiesForPath(final String p) {
    var plp = _list[p];
    plp ??= PathProperties.empty();
    return plp;
  }
}

const int initialSize = 9;

class PathNodes {
  final List<dynamic> nodes;
  final bool error;
  PathNodes(this.nodes, this.error);

  factory PathNodes.from(final Map<String, dynamic> json, final Path path) {
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

  bool alreadyContainsName(final String name) {
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

  dynamic get lastNodeAsData {
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
  int _count = 0;

  Path(List<String> list) {
    _count = 0;
    for (int i = 0; i < list.length; i++) {
      if (list[i].isNotEmpty) {
        pathList[i] = list[i];
        _count++;
      }
    }
  }

  PathNodes pathNodes(final Map<String, dynamic> m) {
    return PathNodes.from(m, this);
  }

  bool isNotEqual(final Path other) {
    return !isEqual(other);
  }

  bool isEqual(Path other) {
    if (_count != other._count) {
      return false;
    }
    for (int i = 0; i < _count; i++) {
      if (pathList[i] != other.pathList[i]) {
        return false;
      }
    }
    return true;
  }

  Path cloneAppendList(final List<String> app) {
    final p = Path.empty();
    for (int i = 0; i < _count; i++) {
      p.push(pathList[i]);
    }
    for (int i = 0; i < app.length; i++) {
      p.push(app[i]);
    }
    return p;
  }

  Path cloneRename(final String newName) {
    final p = Path.empty();
    for (int i = 0; i < _count - 1; i++) {
      p.push(pathList[i]);
    }
    p.push(newName);
    return p;
  }

  Path cloneReversed() {
    final p = Path.empty();
    for (int i = _count - 1; i >= 0; i--) {
      p.push(pathList[i]);
    }
    return p;
  }

  Path cloneParentPath() {
    final p = Path.empty();
    for (int i = 0; i < _count - 1; i++) {
      p.push(pathList[i]);
    }
    return p;
  }

  factory Path.empty() {
    return Path([]);
  }

  factory Path.fromDotPath(final String dotPath) {
    return Path(dotPath.split('.'));
  }

  factory Path.fromList(final List<String> list) {
    return Path(list);
  }

  bool isInMap(final Map<String, dynamic> map) {
    if (_count == 0) {
      return false;
    }
    var m = map;
    for (int i = 0; i < _count; i++) {
      var x = m[pathList[i]];
      if (x == null) {
        return false;
      }
      m = x;
    }
    return true;
  }

  bool get hasParent {
    return (_count > 1);
  }

  int get length {
    return _count;
  }

  bool get isEmpty {
    return (_count == 0);
  }

  bool get isNotEmpty {
    return (_count > 0);
  }

  String peek(final int i) {
    if (i >= 0 && i < _count) {
      return pathList[i];
    }
    return "";
  }

  String get root {
    if (_count == 0) {
      return "";
    }
    return pathList[0];
  }

  String get last {
    if (_count == 0) {
      return "";
    }
    return pathList[_count - 1];
  }

  void push(final String p) {
    pathList[_count] = p;
    _count++;
  }

  String pop() {
    if (_count > 0) {
      _count--;
      return pathList[_count];
    }
    return "";
  }

  @override
  String toString() {
    StringBuffer sb = StringBuffer();
    for (int i = 0; i < _count; i++) {
      sb.write(pathList[i]);
      if (i < (_count - 1)) {
        sb.write(".");
      }
    }
    return sb.toString();
  }
}
