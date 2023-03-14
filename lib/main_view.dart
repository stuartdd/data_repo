import 'package:flutter/material.dart';
import 'package:split_view/split_view.dart';
import 'package:flutter_treeview/flutter_treeview.dart';
import 'data_load.dart';
import 'detail_widget.dart';

const double splitMinTree = 0.2;
const double splitMinDetail = 0.4;

class Path {
  List<String> pathList = List.filled(9, "", growable: false);
  int index = 0;

  bool isInMap(Map<String, dynamic> map) {
    var m = map;
    for (int i = 0; i < index; i++) {
      var x = m[pathList[i]];
      if (x == null) {
        return false;
      }
      m = x;
    }
    return true;
  }

  void push(String p) {
    pathList[index] = p;
    index++;
  }

  String pop() {
    index--;
    if (index >= 0) {
      return pathList[index];
    }
    return "";
  }

  @override
  String toString() {
    StringBuffer sb = StringBuffer();
    for (int i = 0; i < index; i++) {
      sb.write(pathList[i]);
      if (i < (index - 1)) {
        sb.write(".");
      }
    }
    return sb.toString();
  }
}

List<Widget> createTextWidgetFromList(List<String> inlist, Function(String) onselect) {
  List<Widget> l = List.empty(growable: true);
  for (var value in inlist) {
    l.add(TextButton(
      child: Text(value),
      onPressed: () {
        onselect(value);
      },
    ));
  }
  return l;
}

Widget createSplitView(final Map<String, dynamic>? data, final String user, final String filter, final String selectedNode, final bool horizontal, double initPos, MaterialColor materialColor, final Function(String) onSelect, final Function(double) onDivChange, final Function(int) onSearchComplete, final bool Function(DetailAction) dataAction) {
  final SplitViewMode splitViewMode = horizontal ? SplitViewMode.Horizontal : SplitViewMode.Vertical;
  final SplitViewController controller = SplitViewController(weights: [initPos, 1 - initPos], limits: [WeightLimit(min: splitMinTree, max: 1.0), WeightLimit(min: splitMinDetail, max: 1.0)]);
  final Container treeContainer = _createTreeContainer(data, user, filter, onSelect, selectedNode, onSearchComplete);
  final Container detailContainer;
  if (data != null) {
    final node = DataLoad.findNodeForPath(data, selectedNode);
    if (node != null) {
      detailContainer = _createDetailContainer(node, selectedNode, materialColor, dataAction);
    } else {
      detailContainer = Container(
        color: Colors.red,
        child: const Center(child: Text("Selected Node was not found in the data")),
      );
    }
  } else {
    detailContainer = Container(
      color: Colors.red,
      child: const Center(child: Text("Data Not Loaded")),
    );
  }

  return SplitView(
    onWeightChanged: (value) {
      if (value.isNotEmpty) {
        onDivChange(value[0]!);
      }
    },
    controller: controller,
    viewMode: splitViewMode,
    indicator: SplitIndicator(viewMode: splitViewMode),
    activeIndicator: SplitIndicator(
      viewMode: splitViewMode,
      isActive: true,
    ),
    children: [treeContainer, detailContainer],
  );
}

Container _createTreeContainer(Map<String, dynamic>? data, String user, String filter, void Function(String) onSelect, final String selectedNode, final Function(int) onSearchComplete) {
  if (data == null) {
    return Container(
      color: Colors.red,
      child: const Center(child: Text("Data not loaded")),
    );
  }
  return Container(
    color: Colors.green,
    child: _buildTreeView(data, onSelect, selectedNode, filter, onSearchComplete),
  );
}

Container _createDetailContainer(Map<String, dynamic> selectedNode, String selectedPath, MaterialColor materialColor, bool Function(DetailAction) dataAction) {
  List<DataValueRow> properties = DataLoad.dataValueListFromJson(selectedNode, selectedPath);
  return Container(
    color: materialColor.shade500,
    child: Scrollbar(
      child: ListView(
        restorationId: 'list_demo_list_view',
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (int index = 0; index < properties.length; index++)
            DetailWidget(
              dataValueRow: properties[index],
              materialColor: materialColor,
              dataAction: dataAction,
            )
        ],
      ),
    ),
  );
}

Widget _buildTreeView(Map<String, dynamic> data, void Function(String) onSelect, final String selectedNode, filter, final Function(int) onSearchComplete) {
  var controller = _buildTreeViewController(data, selectedNode, filter, onSearchComplete);
  return TreeView(
    controller: controller,
    allowParentSelect: true,
    supportParentDoubleTap: true,
    theme: buildTreeViewTheme(),
    onNodeDoubleTap: (key) {
      onSelect(key);
    },
    onNodeTap: (key) {
      onSelect(key);
    },
  );
}

List<Node<dynamic>> _mapToNodeList(Map<String, dynamic> data, Path path, Map<String, dynamic> filterList) {
  final List<Node<dynamic>> l = List.empty(growable: true);
  data.forEach((k, v) {
    if (v is Map<String, dynamic>) {
      path.push(k);
      if (path.isInMap(filterList)) {
        l.add(Node(key: path.toString(), label: k, children: _mapToNodeList(v, path, filterList)));
      }
      path.pop();
    }
  });
  return l;
}

void _buildMapFromPathList(final Map<String, dynamic> map, final List<String> pathList) {
  if (pathList.isEmpty) {
    return;
  }
  for (int i = 0; i < pathList.length; i++) {
    Map<String, dynamic> root = map;
    var splitPath = pathList[i].split('|');
    if (splitPath.isNotEmpty) {
      for (int j = 0; j < splitPath.length; j++) {
        root.putIfAbsent(splitPath[j], () => <String, dynamic>{});
        root = root[splitPath[j]];
      }
    }
  }
}

TreeViewController _buildTreeViewController(Map<String, dynamic> data, final String selectedNode, String filter, final Function(int) onSearchComplete) {
  if (data.isEmpty) {
    return TreeViewController(
      children: [const Node(key: 'root', label: 'Empty Tree')],
      selectedKey: 'root',
    );
  }

  final List<String> list = List.empty(growable: true);
  final filterLc = filter.toLowerCase();
  final Map<String, dynamic> map = <String, dynamic>{};

  DataLoad.pathsForMapNodes(data, (path) {
    final lc = path.toLowerCase();
    if (lc.contains(filterLc)) {
      list.add(path);
    }
  });

  _buildMapFromPathList(map, list);
  final c = _mapToNodeList(data, Path(), map);
  onSearchComplete(c.length);

  if (c.isEmpty) {
    return TreeViewController(
      children: [const Node(key: 'root', label: 'No Data Found')],
      selectedKey: 'root',
    );
  }
  return TreeViewController(
    children: c,
    selectedKey: selectedNode,
  );
}

TreeViewTheme buildTreeViewTheme() {
  return TreeViewTheme(
    expanderTheme: ExpanderThemeData(
      type: ExpanderType.caret,
      modifier: ExpanderModifier.none,
      position: ExpanderPosition.start,
      color: Colors.red.shade800,
      size: 28,
    ),
    labelStyle: const TextStyle(
      fontSize: 20,
      letterSpacing: 0.3,
    ),
    parentLabelStyle: TextStyle(
      fontSize: 20,
      letterSpacing: 0.1,
      fontWeight: FontWeight.w800,
      color: Colors.red.shade600,
    ),
    iconTheme: IconThemeData(
      size: 28,
      color: Colors.grey.shade800,
    ),
    colorScheme: const ColorScheme.light(),
  );
}
