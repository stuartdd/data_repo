import 'package:data_repo/config.dart';
import 'package:flutter/material.dart';
import 'path.dart';

class MyTreeNode {
  late final String label;
  final String pathKey;
  final MyTreeNode? parent;

  final bool leaf;
  late final List<MyTreeNode> children;

  bool expanded = true;
  bool _required = true;
  int index = 0;

  MyTreeNode(this.pathKey, String labelIn, this.parent, this.leaf, {index = 0}) {
    label = labelIn.trim();
    children = List.empty(growable: true);
  }

  @override
  String toString() {
    return "Label:$label PathKey:$pathKey Leaf:$leaf Children:${children.length} Req:$required Exp:$expanded";
  }

  static MyTreeNode fromMap(final Map<String, dynamic> mapNode, {int sorted = 0}) {
    final treeNode = MyTreeNode.empty();
    _fromMapR(mapNode, treeNode, sorted);
    return treeNode;
  }

  static void _insertInOrder(List<MyTreeNode> list, MyTreeNode node , int order) {
    final nPathKey = node.pathKey.toLowerCase();
    for (int i=0; i<list.length;i++) {
      final x = list[i].pathKey.toLowerCase().compareTo(nPathKey);
      if (x == order) {
        list.insert(i, node);
        return;
      }
    }
    list.add(node);
  }

  static void _fromMapR(final Map<String, dynamic> mapNode, final MyTreeNode treeNode, int order) {
    mapNode.forEach((key, value) {
      final nn = MyTreeNode(key, key, treeNode, value is! Map);
      if (order == 0) {
        treeNode.children.add(nn);
      } else {
        _insertInOrder(treeNode.children,nn, order); // insertion sort
      }
      if (value is Map) {
        _fromMapR(value as Map<String, dynamic>, nn, order);
      }
    });
  }

  factory MyTreeNode.cloneWithoutChildren(final MyTreeNode n, final MyTreeNode? parent) {
    final nn = MyTreeNode(n.pathKey, n.label, parent, n.leaf);
    nn.expanded = n.expanded;
    nn.index = n.index;
    nn._required = n._required;
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

  MyTreeNode clone({final bool requiredOnly = false}) {
    final clonedParent = MyTreeNode.cloneWithoutChildren(this, null);
    _cloneWithParent(clonedParent, requiredOnly);
    return clonedParent;
  }

  void _cloneWithParent(MyTreeNode clonedParent, final bool requiredOnly) {
    for (var c in children) {
      if (requiredOnly) {
        if (c._required) {
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
      node._required = true;
    });
    return this;
  }

  MyTreeNode applyFilter(String filter, final bool toLowerCase, final bool Function(String, bool, MyTreeNode) match) {
    final String s;
    if (toLowerCase) {
      s = filter.trim().toLowerCase();
    } else {
      s = filter.trim();
    }

    if (s.isEmpty) {
      clearFilter();
      return this;
    }

    visitEachSubNode((node) {
      final b = match(s, toLowerCase, node);
      node._required = b;
      if (b) {
        node.visitEachParentNode((pn) {
          pn._required = true;
        });
      }
    });
    return clone(requiredOnly: true);
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
        return defaultTreeNodeIconDataBase + 1;
      }
      return defaultTreeNodeIconDataBase + 2;
    }
    return defaultTreeNodeIconDataBase;
  }

  bool get isRoot {
    return parent == null;
  }

  bool get isRequired {
    return _required;
  }

  bool get isNotRequired {
    return !_required;
  }

  void setRequired(bool req, {bool recursive = false}) {
    _required = req;
    if (recursive) {
      visitEachSubNode((sn) {
        sn._required = req;
      });
    }
  }

  bool get isNotEmpty {
    return children.isNotEmpty;
  }

  bool get isEmpty {
    return children.isEmpty;
  }

  bool get canExpand {
    return hasMapNodes;
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

  bool get hasMapNodes {
    if (children.isNotEmpty) {
      for (int i = 0; i < children.length; i++) {
        if (children[i].isNotLeaf) {
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

  void visitEachChildNode(final void Function(MyTreeNode) func) {
    for (var element in children) {
      func(element);
    }
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

Widget? buildNodeDefault(final MyTreeNode node, final String rootNodeName, final AppThemeData appThemeData, final double rowHeight, final bool selected, final bool hiLight, final Function(Path) onClick, final Function(Path) onExpand) {
  if (node.parentIsExpanded && node.isNotLeaf) {
    final pl = node.pathLen - 1;
    return Container(
      height: rowHeight,
      color: appThemeData.selectedAndHiLightColour(selected, hiLight),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          SizedBox(width: 20.0 * (pl)), // Indent
          IconButton(
              onPressed: () {
                onExpand(node.path);
              },
              tooltip: defaultTreeNodeToolTip[node.iconIndex],
              icon: appThemeData.treeNodeIcons[node.iconIndex]),
          TextButton(
            child: Text(
              (pl == 0 && rootNodeName.isNotEmpty) ? rootNodeName : node.label,
              style: node.canExpand ? appThemeData.tsTreeViewParentLabel : appThemeData.tsTreeViewLabel,
            ),
            onPressed: () {
              onClick(node.path);
            },
          ),
          node.hasLeafNodes
              ? IconButton(
                  onPressed: () {
                    onClick(node.path);
                  },
                  tooltip: defaultTreeNodeToolTip[defaultTreeNodeIconDataHasData],
                  icon: appThemeData.treeNodeIcons[defaultTreeNodeIconDataHasData])
              : const SizedBox(
                  width: 0,
                ),
        ],
      ),
    );
  }
  return null;
}

class MyTreeNodeWidgetList extends StatefulWidget {
  const MyTreeNodeWidgetList(this.rootNode, this.rootNodeName, this.selectedNode, this.selectedNodePath, this.appThemeData, this.onSelect, this.onExpand, this.pathListProperties, this.rowHeight, this.isSorted, {super.key, this.buildNode = buildNodeDefault});
  final Widget? Function(MyTreeNode, String, AppThemeData, double, bool, bool, Function(Path), Function(Path)) buildNode;
  final void Function(Path) onSelect;
  final void Function(Path) onExpand;
  final AppThemeData appThemeData;
  final MyTreeNode rootNode;
  final MyTreeNode selectedNode;
  final Path selectedNodePath;
  final PathPropertiesList pathListProperties;
  final double rowHeight;
  final int isSorted;
  final String rootNodeName;
  @override
  State<MyTreeNodeWidgetList> createState() => _MyTreeNodeWidgetListState();
}

class _MyTreeNodeWidgetListState extends State<MyTreeNodeWidgetList> {
  _MyTreeNodeWidgetListState();

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = List.empty(growable: true);
    int c = 0;
    final rnn = (widget.rootNode.children.length == 1) ? widget.rootNodeName : "";
    widget.rootNode.visitEachSubNode(
      (aNode) {
        final aNodePath = aNode.path;
        final isSelected = widget.selectedNodePath.isEqual(aNodePath);
        final w = widget.buildNode(
          aNode,
          rnn,
          widget.appThemeData,
          widget.rowHeight,
          isSelected,
          widget.pathListProperties.propertiesForPath(aNodePath).changed,
          (selectPath) {
            widget.onSelect(selectPath);
          },
          (expandPath) {
            widget.onExpand(expandPath);
          },
        );

        if (w != null) {
          if (isSelected) {
            widget.selectedNode.index = c;
          }
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
