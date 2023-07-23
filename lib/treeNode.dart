import 'package:data_repo/config.dart';
import 'package:flutter/material.dart';
import 'path.dart';

class MyTreeNode {
  final String label;
  final String pathKey;
  final MyTreeNode? parent;
  final bool leaf;
  late final List<MyTreeNode> children;

  bool expanded = true;
  bool required = true;
  int index = 0;

  MyTreeNode(this.pathKey, this.label, this.parent, this.leaf, {index = 0}) {
    children = List.empty(growable: true);
  }

  @override
  String toString() {
    return "Label:$label PathKey:$pathKey Leaf:$leaf Children:${children.length} Req:$required";
  }

  static MyTreeNode fromMap(final Map<String, dynamic> mapNode) {
    debugPrint("IN:MyTreeNode fromMap");
    final treeNode = MyTreeNode.empty();
    _fromMapR(mapNode, treeNode);
    return treeNode;
  }

  static void _fromMapR(final Map<String, dynamic> mapNode, final MyTreeNode treeNode) {
    mapNode.forEach((key, value) {
      final nn = MyTreeNode(key, key, treeNode, value is! Map);
      treeNode.children.add(nn);
      if (value is Map) {
        _fromMapR(value as Map<String, dynamic>, nn);
      }
    });
  }

  factory MyTreeNode.cloneWithoutChildren(final MyTreeNode n, final MyTreeNode? parent) {
    final nn = MyTreeNode(n.pathKey, n.label, parent, n.leaf);
    nn.expanded = n.expanded;
    nn.index = n.index;
    nn.required = n.required;
    return nn;
  }

  factory MyTreeNode.empty() {
    return MyTreeNode("", "", null, false);
  }

  MyTreeNode firstSelectableNode() {
    for (int i = 0; i < children.length; i++) {
      if (children[i].isNotLeaf) {
        return children[i];
      }
    }
    return MyTreeNode("root", "root", null, false);
  }

  MyTreeNode clone(final bool requiredOnly) {
    final clonedParent = MyTreeNode.cloneWithoutChildren(this, null);
    _cloneWithParent(clonedParent, requiredOnly);
    return clonedParent;
  }

  void _cloneWithParent(MyTreeNode clonedParent, final bool requiredOnly) {
    for (var c in children) {
      if (requiredOnly) {
        if (c.required) {
          final clonedC = MyTreeNode.cloneWithoutChildren(c, clonedParent);
          clonedParent.children.add(clonedC);
          c._cloneWithParent(clonedC, requiredOnly);
        }
      } else {
        final clonedC = MyTreeNode.cloneWithoutChildren(c, clonedParent);
        clonedParent.children.add(clonedC);
        c._cloneWithParent(clonedC, requiredOnly);
      }
    }
  }

  MyTreeNode clearFilter() {
    visitEachSubNode((node) {
      node.required = true;
    });
    return this;
  }

  void setRequiredNodeAndSubNodes(bool req) {
    required = true;
    visitEachSubNode((sn) {
      sn.required = true;
    });
  }

  MyTreeNode applyFilter(String filter, final bool toLowerCase, final bool Function(String, bool, MyTreeNode) match) {
    final String s;
    if (toLowerCase) {
      s = filter.trim().toLowerCase();
    } else {
      s = filter.trim();
    }

    if (s.isEmpty) {
      return clearFilter();
    }

    visitEachSubNode((node) {
      final b = match(s, toLowerCase, node);
      node.required = b;
      if (b) {
        node.visitEachParentNode((pn) {
          pn.required = true;
        });
      }
    });

    return clone(true);
  }

  Path get up {
    if (parent == null) {
      return Path.empty();
    }
    if (parent!.children.isEmpty) {
      return Path.empty();
    }
    final c = parent!.children;
    for (var i = (c.length - 1); i >= 0; i--) {
      if (c[i].pathKey == pathKey) {
        if (i < 1) {
          return Path.empty();
        }
        if (c[i - 1].isNotLeaf) {
          return c[i - 1].path;
        }
        return Path.empty();
      }
    }
    return Path.empty();
  }

  Path get down {
    if (parent == null) {
      return Path.empty();
    }
    if (parent!.children.isEmpty) {
      return Path.empty();
    }
    final c = parent!.children;
    for (var i = 0; i < c.length; i++) {
      if (c[i].pathKey == pathKey) {
        if (i > (c.length - 2)) {
          return Path.empty();
        }
        if (c[i + 1].isNotLeaf) {
          return c[i + 1].path;
        }
        return Path.empty();
      }
    }
    return Path.empty();
  }

  Path get firstChild {
    if (isNotEmpty) {
      if (children[0].isNotLeaf) {
        return children[0].path;
      }
    }
    return Path.empty();
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

  bool get isRoot {
    return parent == null;
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

  bool get hasLeafNodes {
    if (children.isNotEmpty) {
      for (int i = 0; i < children.length; i++) {
        if (children[i].isLeaf) {
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
    visitEachParentNode((p) {
      if (!p.expanded) {
        c++;
      }
    });
    return c == 0;
  }

  void expandAll(final bool exp) {
    visitEachSubNode((node) {
      node.expanded = exp;
    });
  }

  void expandParent(final bool exp) {
    visitEachParentNode((node) {
      node.expanded = exp;
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

  bool searchMatch(final String s) {
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

  MyTreeNode? findByPath(final Path path) {
    if (path.isEmpty || isEmpty) {
      return null;
    }
    MyTreeNode n = this;
    MyTreeNode? nn;
    for (int i = 0; i < path.length; i++) {
      nn = n.findByLabel(path.peek(i));
      if (nn == null) {
        return null;
      }
      n = nn;
    }
    return n;
  }

  void visitEachSubNode(final void Function(MyTreeNode) func) {
    for (var element in children) {
      func(element);
      if (element.isNotEmpty) {
        element.visitEachSubNode(func);
      }
    }
  }

  void visitEachLeafNode(final void Function(MyTreeNode) func) {
    for (var element in children) {
      if (element.isLeaf) {
        func(element);
      } else {
        if (element.isNotEmpty) {
          element.visitEachLeafNode(func);
        }
      }
    }
  }

  void visitEachParentNode(final void Function(MyTreeNode) func) {
    var p = parent;
    while (p != null) {
      func(p);
      p = p.parent;
    }
  }
}

Widget? buildNodeDefault(final int index, final MyTreeNode node, final AppThemeData appThemeData, final double rowHeight, final bool selected, final int pathLen, final bool hiLight, final Function(MyTreeNode, bool) onClick) {
  if (node.parentIsExpanded && node.isNotLeaf) {
    node.index = index;
    return Container(
      height: rowHeight,
      color: appThemeData.selectedAndHiLightColour(selected, hiLight),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        textBaseline: TextBaseline.alphabetic,
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
          node.hasLeafNodes
              ? IconButton(
                  onPressed: () {
                    onClick(node, true);
                  },
                  icon: appThemeData.treeNodeIcons[appThemeData.treeNodeIcons.length - 1])
              : const SizedBox(
                  width: 0,
                ),
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
  const MyTreeNodeWidgetList(this.rootNode, this.selectedNode, this.selectedNodePath, this.appThemeData, this.rowHeight, this.onSelect, this.pathListProperties, {super.key, this.buildNode = buildNodeDefault});
  final Widget? Function(int, MyTreeNode, AppThemeData, double, bool, int, bool, Function(MyTreeNode, bool)) buildNode;
  final void Function(MyTreeNode) onSelect;
  final AppThemeData appThemeData;
  final MyTreeNode rootNode;
  final double rowHeight;
  final MyTreeNode selectedNode;
  final Path selectedNodePath;
  final PathPropertiesList pathListProperties;
  @override
  State<MyTreeNodeWidgetList> createState() => _MyTreeNodeWidgetListState();
}

class _MyTreeNodeWidgetListState extends State<MyTreeNodeWidgetList> {
  _MyTreeNodeWidgetListState();

  @override
  Widget build(BuildContext context) {

    final List<Widget> children = List.empty(growable: true);
    int c = 0;
    widget.rootNode.visitEachSubNode(
      (aNode) {
        final aNodePath = aNode.path;
        final w = widget.buildNode(
          c,
          aNode,
          widget.appThemeData,
          widget.rowHeight,
          widget.selectedNodePath.isEqual(aNodePath),
          aNode.pathLen,
          widget.pathListProperties.propertiesForPath(aNodePath).changed,
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
            color: widget.appThemeData.primary.med,
          ));
          c++;
        }
      },
    );
    return ListBody(
      children: children,
    );
  }
}
