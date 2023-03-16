import 'package:flutter/material.dart';
import 'package:split_view/split_view.dart';
import 'package:flutter_treeview/flutter_treeview.dart';
import 'data_load.dart';
import "path.dart";
import 'detail_widget.dart';

const double splitMinTree = 0.2;
const double splitMinDetail = 0.4;

class DisplayData {
  DisplayData(this.splitView, this.treeViewController, {this.isOk = true});
  final Widget splitView;
  final TreeViewController? treeViewController;
  final bool isOk;

  factory DisplayData.error(final Color color, final String message) {
    return DisplayData(
        Container(
          color: color,
          child: Center(child: Text(message, style: const TextStyle(fontFamily: 'Code128', fontSize: 30.0, color: Colors.black))),
        ),
        null,
        isOk: false);
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

/// Creates both Left and Right panes.
DisplayData createSplitView(
    final Map<String, dynamic>? originalData, // The original data from the file
    final String user, // The user (The root node name)
    final String filter, // The search text
    final String expand,
    final String selectedNode, // The first node in the root
    final bool horizontal, // Display horizontal or vertical split pane
    double initPos, // The split pane divider position
    MaterialColor materialColor, // The colour scheme
    final Function(String) onSelect, // Called when a tree node in selected
    final Function(double) onDivChange, // Called when the split pane divider is moved
    final Function(int) onSearchComplete, // Called when the search is complete
    final bool Function(DetailAction) onDataAction) {
  // Called when one of the detail buttons is pressed
  /// Left right or Top bottom
  final SplitViewMode splitViewMode = horizontal ? SplitViewMode.Horizontal : SplitViewMode.Vertical;
  final SplitViewController splitViewController = SplitViewController(weights: [initPos, 1 - initPos], limits: [WeightLimit(min: splitMinTree, max: 1.0), WeightLimit(min: splitMinDetail, max: 1.0)]);

  if (originalData == null) {
    return DisplayData.error(Colors.red, ("No data has been loaded"));
  }

  /// Create the tree
  final treeViewController = _buildTreeViewController(originalData, selectedNode, filter, expand, onSearchComplete);
  if (treeViewController.children.isEmpty) {
    return DisplayData.error(Colors.yellow, ("Search did not find any data"));
  }
  treeViewController.expandAll();

  final treeView = TreeView(
    controller: treeViewController,
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

  final Container treeContainer = Container(
    color: Colors.green,
    child: treeView,
  );

  /// Create the detail.
  final Container detailContainer;
  final node = DataLoad.findNodeForPath(originalData, selectedNode);
  if (node != null) {
    detailContainer = _createDetailContainer(node, selectedNode, materialColor, onDataAction);
  } else {
    detailContainer = Container(
      color: Colors.red,
      child: const Center(child: Text("Selected Node was not found in the data")),
    );
  }

  final splitView = SplitView(
    onWeightChanged: (value) {
      if (value.isNotEmpty) {
        onDivChange(value[0]!);
      }
    },
    controller: splitViewController,
    viewMode: splitViewMode,
    indicator: SplitIndicator(viewMode: splitViewMode),
    activeIndicator: SplitIndicator(
      viewMode: splitViewMode,
      isActive: true,
    ),
    children: [treeContainer, detailContainer],
  );
  return DisplayData(splitView, treeViewController);
}

TreeViewController _buildTreeViewController(Map<String, dynamic> data, final String selectedNode, final String filter, final String expand, final Function(int) onSearchComplete) {
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
  final c = _mapToNodeList(data, Path.empty(), map, expand, filter);
  onSearchComplete(c.length);

  if (c.isEmpty) {
    return TreeViewController(
      children: const [],
      selectedKey: '',
    );
  }

  return TreeViewController(
    children: c,
    selectedKey: selectedNode,
  );
}

Container _createDetailContainer(final Map<String, dynamic> selectedNode, final String selectedPath, final MaterialColor materialColor, final bool Function(DetailAction) dataAction) {
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

List<Node<dynamic>> _mapToNodeList(final Map<String, dynamic> data, final Path path, final Map<String, dynamic> filterList, final String expand, final String filter) {
  final List<Node<dynamic>> l = List.empty(growable: true);
  final expandLC = expand.toLowerCase();
  data.forEach((k, v) {
    if (v is Map<String, dynamic>) {
      path.push(k);
      if (path.isInMap(filterList)) {
        bool exp = false;
        if (filter == "") {
          exp = (path.getRoot().toLowerCase() == expandLC);
        } else {
          exp = true;
        }
        l.add(Node(key: path.toString(), label: k, expanded: exp, children: _mapToNodeList(v, path, filterList, expand, filter)));
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
