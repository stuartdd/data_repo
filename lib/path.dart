/*
 * Copyright (C) 2023 Stuart Davies (stuartdd)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

const _updatedNotForUnDo = "~";
const pathSeparator = '.';
const initialPathCapacity = 9;

class PathProperties {
  String renamedFrom = "";
  String updatedFrom = "";
  bool groupSelect = false;
  bool isValue = false;
  bool done = false;

  PathProperties(this.updatedFrom, this.groupSelect, this.isValue, this.renamedFrom);

  factory PathProperties.empty() {
    return PathProperties("", false, false, "");
  }

  @override
  String toString() {
    return "rename:$renamed updated:$updated group:$groupSelect";
  }

  void clear() {
    renamedFrom = "";
    updatedFrom = "";
    groupSelect = false;
    isValue = false;
    done = false;
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

  List<String> cloneKeys() {
    final List<String> keys = [];
    for (var k in _list.keys) {
      keys.add(k);
    }
    return keys;
  }

  void clearAllGroupSelect() {
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

  void clearAllGroupSelectDone(final bool Function(Path p) testRequired) {
    for (var k in cloneKeys()) {
      final v = _list[k];
      if (v != null) {
        if (v.done && v.groupSelect) {
          v.done = false;
          v.groupSelect = false;
        }
        if (v.isEmpty) {
          _list.remove(k);
        }
      }
    }
    for (var k in cloneKeys()) {
      final v = _list[k];
      if (v != null) {
        if (testRequired(Path.fromDotPath(k))) {
          _list.remove(k);
        }
      }
    }
    if (log != null) {
      log!("__NODE__ DONE SELECTION CLEARED");
    }
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

  int get countGroupSelects {
    int counter = 0;
    for (var v in _list.values) {
      if (v.groupSelect) {
        counter++;
      }
    }
    return counter;
  }

  void setGroupSelect(final Path p, final bool isValue) {
    final ps = p.toString();
    final pfp = _propertiesForPath(ps);
    pfp.groupSelect = !pfp.groupSelect;
    if (pfp.groupSelect) {
      pfp.isValue = isValue;
    } else {
      pfp.isValue = false;
    }
    if (log != null) {
      log!("__NODE__ GROUP [$p] ${pfp.groupSelect ? 'YES' : 'NO'} ${pfp.isValue ? 'Value' : 'Group'}");
    }
    if (pfp.isEmpty) {
      _list.remove(ps);
    } else {
      _list[ps] = pfp;
    }
  }

  void setRenamed(final Path p, {String from = _updatedNotForUnDo, bool shouldLog = true}) {
    final ps = p.toString();
    final pfp = _propertiesForPath(ps);
    if (!pfp.canUndoRename) {
      pfp.renamedFrom = from;
    }
    if (shouldLog && log != null) {
      log!("__NODE__ RENAME [$p] ${pfp.renamed ? 'YES' : 'NO'}");
    }
    _list[ps] = pfp;
  }

  void setUpdated(final Path p, {String from = _updatedNotForUnDo, bool shouldLog = true}) {
    final ps = p.toString();
    final pfp = _propertiesForPath(ps);
    if (!pfp.canUndoUpdate) {
      pfp.updatedFrom = from;
    }
    if (shouldLog && log != null) {
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

/*
A list of map nodes, one for each path entry from the root node to the 'last' path node..
 */
class PathNodes {
  final List<dynamic> nodes;
  final bool error;
  PathNodes(this.nodes, this.error);

  factory PathNodes.from(final Map<String, dynamic> map, final Path path) {
    if (path.isEmpty) {
      return PathNodes([], true);
    }
    if (map.isEmpty) {
      return PathNodes([], true);
    }
    var nn = map;
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
      if (parentOfLastNode!.containsKey(name)) {
        return true;
      }
    }
    return false;
  }

  /*
  Is the last node a Map node Map<String, dynamic> or a data node <dynamic>.
   */
  bool get lastNodeIsMap {
    if (nodes.isEmpty) {
      return false;
    }
    return (nodes[nodes.length - 1] is Map<String, dynamic>);
  }

  Map<String, dynamic>? get lastNodeAsMap {
    if (lastNodeIsMap) {
      return nodes[nodes.length - 1] as Map<String, dynamic>;
    }
    return null;
  }
  /*
  Is the last node a Map node Map<String, dynamic> or a data node <dynamic>.
   */
  bool get lastNodeIsData {
    if (nodes.isEmpty) {
      return false;
    }
    return ((nodes[nodes.length - 1] is! Map) && (nodes[nodes.length - 1] is! List));
  }

  dynamic get lastNodeAsData {
    if (lastNodeIsData) {
      return nodes[nodes.length - 1];
    }
    return null;
  }



  /*
  Is the last node the root node.
  If it is then it will not have a parent node.
   */
  bool get lastNodeIsRoot {
    return (nodes.length < 2);
  }

  Map<String, dynamic>? get parentOfLastNode {
    if (nodes.length > 1) {
      return nodes[nodes.length - 2] as Map<String, dynamic>;
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

/*
Represents a node in a Map of Maps.
 */
class Path {
  static const String substituteElement = "*";
  final List<String> pathList = List.filled(initialPathCapacity, "", growable: false);
  int _count = 0;

  Path(List<String> list) {
    _count = 0;
    final len = (list.length > initialPathCapacity) ? initialPathCapacity : list.length;
    for (int i = 0; i < len; i++) {
      if (list[i].isNotEmpty) {
        pathList[i] = list[i];
        _count++;
      } else {
        break;
      }
    }
  }

  PathNodes pathNodes(final Map<String, dynamic> m) {
    return PathNodes.from(m, this);
  }

  String get asMarkdownLink {
    return "[${toString()}](${toString()})";
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

  Path cloneAppend(final String app) {
    final p = Path.empty();
    for (int i = 0; i < _count; i++) {
      p.push(pathList[i]);
    }
    p.push(app);
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

  Path cloneSub(String replace, {String replaceElement = substituteElement}) {
    final p = Path.empty();
    for (int i = 0; i < _count; i++) {
      final pe = pathList[i];
      if (pe == replaceElement) {
        if (replace.isNotEmpty) {
          p.push(replace);
        }
      } else {
        p.push(pe);
      }
    }
    return p;
  }

  Path cloneFirst() {
    if (length < 1) {
      return Path.empty();
    }
    return Path([pathList[0]]);
  }

  factory Path.empty() {
    return Path([]);
  }

  factory Path.fromDotPath(final String dotPath) {
    return Path(dotPath.split(pathSeparator));
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

  /*
  As the first path element is the root. a Single path must be the root node
   */
  bool get hasParent {
    return (_count > 1);
  }

  int get length {
    return _count;
  }

  bool get isEmpty {
    return (_count == 0);
  }

  bool isRational(Map<String, dynamic> map) {
    if (isEmpty) {
      return false;
    }
    if (map[pathList[0]] == null) {
      return false;
    }
    return true;
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
        sb.write(pathSeparator);
      }
    }
    return sb.toString();
  }
}
