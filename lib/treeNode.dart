import 'package:data_repo/config.dart';
import 'package:flutter/material.dart';
import 'path.dart';

class MyTreeNode {
  final String label;
  final String pathKey;
  final MyTreeNode? parent;
  final leaf;
  late final List<MyTreeNode> children;
  bool expanded = true;
  int index = 0;

  MyTreeNode(this.pathKey, this.label, this.parent, this.leaf, {index = 0}) {
    children = List.empty(growable: true);
  }

  @override
  String toString() {
    return "${path.toString()} $canExpand ${children.length}";
  }

  factory MyTreeNode.empty() {
    return MyTreeNode("", "", null, false);
  }

  int get iconIndex {
    if (canExpand) {
      if (expanded) {
        return 1;
      }
      return 2;
    }
    return 0;
  }

  bool get isNotEmpty {
    return children.isNotEmpty;
  }

  bool get isEmpty {
    return children.isEmpty;
  }

  bool get canExpand {
    if (children.isNotEmpty) {
      for (int i = 0; i < children.length; i++) {
        if (children[i].isNotEmpty) {
          return true;
        }
      }
    }
    return false;
  }

  bool get isLeaf {
    return leaf;
  }

  bool get isNotLeaf {
    return !leaf;
  }

  bool get parentIsExpanded {
    int c = 0;
    visitEachParent((p) {
      if (!p.expanded) {
        c++;
      }
    });
    return c == 0;
  }

  void expandAll(bool exp) {
    visitEachNode((node) {
      // if (node.isNotEmpty) {
      node.expanded = exp;
      // }
    });
  }

  int get pathLen {
    int count = 0;
    var pp = parent;
    while (pp != null) {
      count++;
      pp = pp.parent;
    }
    return count;
  }

  Path get path {
    final p = Path.empty();
    if (pathKey.isEmpty) {
      return p;
    }
    p.push(pathKey);
    var pp = parent;
    while (pp != null) {
      if (pp.pathKey.isNotEmpty) {
        p.push(pp.pathKey);
      }
      pp = pp.parent;
    }
    return p.cloneReversed();
  }

  bool searchMatch(String s) {
    if (s.isEmpty) {
      return true;
    }
    if (label.toLowerCase().contains(s.toLowerCase())) {
      return true;
    }
    return false;
  }

  MyTreeNode? findByLabel(String l) {
    if (isNotEmpty) {
      for (var element in children) {
        if (l == element.label) {
          return element;
        }
      }
    }
    return null;
  }

  MyTreeNode? findByPath(Path path) {
    if (path.isEmpty || isEmpty) {
      return null;
    }
    MyTreeNode n = this;
    MyTreeNode? nn;
    for (int i = 0; i < path.count; i++) {
      nn = n.findByLabel(path.peek(i));
      if (nn == null) {
        return null;
      }
      n = nn;
    }
    return n;
  }

  void visitEachNode(void Function(MyTreeNode) func) {
    for (var element in children) {
      func(element);
      if (element.isNotEmpty) {
        element.visitEachNode(func);
      }
    }
  }

  void visitEachParent(void Function(MyTreeNode) func) {
    var p = parent;
    while (p != null) {
      func(p);
      p = p.parent;
    }
  }

  static MyTreeNode fromMap(Map<String, dynamic> mapNode) {
    debugPrint("IN:MyTreeNode fromMap");
    final parent = MyTreeNode.empty();
    _fromMapR(mapNode, parent);
    return parent;
  }

  static void _fromMapR(Map<String, dynamic> mapNode, MyTreeNode parent) {
    mapNode.forEach((key, value) {
      final nn = MyTreeNode(key, key, parent, value is! Map);
      parent.children.add(nn);
      if (value is Map) {
        _fromMapR(value as Map<String, dynamic>, nn);
      }
    });
  }
}

Widget? buildNodeDefault(final int index, final MyTreeNode node, final AppThemeData appThemeData, final double rowHeight, final bool selected, final int pathLen,final bool hiLight, final Function(MyTreeNode, bool) onClick) {
  if (node.parentIsExpanded && node.isNotLeaf) {
    node.index = index;
    return Container(
      height: rowHeight,
      color: appThemeData.selectedHilightColour(selected, hiLight),
      child: Row(
        children: [
          SizedBox(width: 20.0 * (pathLen - 1)),
          IconButton(
              onPressed: () {
                if (node.canExpand) {
                  node.expanded = !node.expanded;
                }
                onClick(node, !node.canExpand);
              },
              icon: appThemeData.treeNodeIcons[node.iconIndex]),
          TextButton(
            child: Text(
              node.label,
              style: node.canExpand ? appThemeData.tsTreeViewParentLabel : appThemeData.tsTreeViewLabel,
            ),
            onPressed: () {
              onClick(node, true);
            },
          ),
        ],
      ),
    );
  }
  return null;
}

class MyTreeNodeWidgetList extends StatefulWidget {
  const MyTreeNodeWidgetList(this.nodes, this.selectedNode, this.appThemeData, this.rowHeight, this.onSelect, this.pathListProperties, {super.key, this.search = "", this.buildNode = buildNodeDefault, this.nodeNavigationBar, this.onSearchComplete});
  final Widget? Function(int, MyTreeNode, AppThemeData, double, bool, int, bool, Function(MyTreeNode, bool)) buildNode;
  final void Function(MyTreeNode) onSelect;
  final void Function(String, int)? onSearchComplete;
  final Widget? nodeNavigationBar;
  final AppThemeData appThemeData;
  final MyTreeNode nodes;
  final double rowHeight;
  final Path selectedNode;
  final PathPropertiesList pathListProperties;
  final String search;
  @override
  State<MyTreeNodeWidgetList> createState() => _MyTreeNodeWidgetListState();
}

class _MyTreeNodeWidgetListState extends State<MyTreeNodeWidgetList> {
  _MyTreeNodeWidgetListState();

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = List.empty(growable: true);
    if (widget.nodeNavigationBar != null) {
      children.add(widget.nodeNavigationBar!);
    }
    int c = 0;
    widget.nodes.visitEachNode(
      (aNode) {
        if (aNode.searchMatch(widget.search)) {
          final w = widget.buildNode(
            c,
            aNode,
            widget.appThemeData,
            widget.rowHeight,
            widget.selectedNode.isEqual(aNode.path),
            aNode.pathLen,
            widget.pathListProperties.propertiesForPath(aNode.path).changed,
            (node, select) {
              setState(() {
                widget.onSelect(node);
              });
            },
          );
          if (w != null) {
            children.add(w);
            children.add(Container(
              height: 1,
              color: widget.appThemeData.primary.shade800,
            ));
            c++;
          }
        }
      },
    );
    if (widget.onSearchComplete != null && widget.search.isNotEmpty) {
      widget.onSearchComplete!(widget.search, c);
    }
    return ListBody(
      children: children,
    );
  }
}
