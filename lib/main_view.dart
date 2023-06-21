import 'package:data_repo/config.dart';
import 'package:flutter/material.dart';
import 'package:split_view/split_view.dart';
import 'package:flutter_treeview/flutter_treeview.dart';
import 'data_load.dart';
import "data_types.dart";
import "path.dart";
import "treeNode.dart";
import 'detail_widget.dart';

const double splitMinTree = 0.2;
const double splitMinDetail = 0.4;

class DisplayData {
  DisplayData(this.splitView, this.scrollController, {this.isOk = true});
  final Widget splitView;
  final ScrollController scrollController;
  final bool isOk;

  factory DisplayData.error(final AppThemeData appThemeData, final String message) {
    return DisplayData(
        Container(
          color: appThemeData.error,
          child: Center(child: Text(message, style: appThemeData.tsLarge)),
        ),
        ScrollController(),
        isOk: false);
  }
}

class MyTreeWidget extends StatelessWidget {
  final String path;
  final String label;
  final BuildContext context;
  const MyTreeWidget(this.path, this.label, this.context, {super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Text("MyTreeWidget:$label")],
    );
  }
}

/// Creates both Left and Right panes.
DisplayData createSplitView(
    final Map<String, dynamic> originalData, // The original data from the file TODO Remove originalData. Use rootTreeNode instead
    final MyTreeNode rootTreeNode,
    final String user, // The user (The root node name)
    final String filter, // The search text
    final Path selectedPath, // The currently selected path
    final bool isEditDataDisplay,
    final bool horizontal, // Display horizontal or vertical split pane
    double initPos, // The split pane divider position
    AppThemeData appThemeData, // The colour scheme
    PathList hiLightedPath,
    final Function(Path) onSelect, // Called when a tree node in selected
    final Function(double) onDivChange, // Called when the split pane divider is moved
    final Function(int) onSearchComplete, // Called when the search is complete
    final bool Function(DetailAction) onDataAction,
    final Widget Function(BuildContext, Node<dynamic>) buildNode,
    final void Function(String) log) {
  // Called when one of the detail buttons is pressed
  /// Left right or Top bottom
  final SplitViewMode splitViewMode = horizontal ? SplitViewMode.Horizontal : SplitViewMode.Vertical;
  final SplitViewController splitViewController = SplitViewController(weights: [initPos, 1 - initPos], limits: [WeightLimit(min: splitMinTree, max: 1.0), WeightLimit(min: splitMinDetail, max: 1.0)]);

  if (originalData.isEmpty) {
    log("__DATA:__ No data loaded");
    return DisplayData.error(appThemeData, ("No data has been loaded"));
  }

  /// Create the detail.
  final Widget detailContainer;
  final node = DataLoad.findLastMapNodeForPath(originalData, selectedPath);
  if (node != null) {
    detailContainer = _createDetailContainer(node, selectedPath, isEditDataDisplay, horizontal, hiLightedPath, appThemeData, onDataAction);
  } else {
    detailContainer = Container(
      color: appThemeData.error.shade900,
      child: const Center(child: Text("Selected Node was not found in the data")),
    );
  }
  final scrollController = ScrollController();
  final scroller = SingleChildScrollView(
    controller: scrollController,
    child: MyTreeNodeWidgetList(
      rootTreeNode,
      selectedPath,
      appThemeData,
      appThemeData.treeNodeHeight,
      (selectedNode) {
        onSelect(selectedNode.path);
      },
    ),
  );

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
    children: [
      scroller,
      detailContainer,
    ],
  );

  return DisplayData(splitView, scrollController);
}

List<DataValueDisplayRow> _dataDisplayValueListFromJson(Map<String, dynamic> json, Path path) {
  List<DataValueDisplayRow> lm = List.empty(growable: true);
  List<DataValueDisplayRow> lv = List.empty(growable: true);
  for (var element in json.entries) {
    if (element.value is Map) {
      lm.add(DataValueDisplayRow(element.key, "", optionTypeDataGroup, false, path, (element.value as Map).length));
    } else if (element.value is List) {
      lm.add(DataValueDisplayRow(element.key, "", optionTypeDataGroup, false, path, (element.value as List).length));
    } else {
      lv.add(DataValueDisplayRow(element.key, element.value.toString(), OptionsTypeData.forTypeOrName(element.value.runtimeType, element.key), true, path, 0));
    }
  }
  lm.addAll(lv);
  return lm;
}

ListView _createDetailContainer(final Map<String, dynamic> selectedNode, Path selectedPath, final bool isEditDataDisplay, final bool isHorizontal, PathList hiLightedPaths, final AppThemeData appThemeData, final bool Function(DetailAction) dataAction) {
  List<DataValueDisplayRow> properties = _dataDisplayValueListFromJson(selectedNode, selectedPath);
  properties.sort(
    (a, b) {
      return a.name.compareTo(b.name);
    },
  );
  return ListView(
    shrinkWrap: true,
    restorationId: 'list_demo_list_view',
    padding: const EdgeInsets.symmetric(vertical: 8),
    children: [
      for (int index = 0; index < properties.length; index++)
        DetailWidget(
          dataValueRow: properties[index],
          appThemeData: appThemeData,
          hiLightedPaths: hiLightedPaths,
          dataAction: dataAction,
          isEditDataDisplay: isEditDataDisplay,
          isHorizontal: isHorizontal,
        )
    ],
  );
}

TreeViewController _buildTreeViewController(final Map<String, dynamic> data, final Path selectedNode, final String filter, final String expand, final Function(int) onSearchComplete) {
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
    selectedKey: selectedNode.toString(),
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
        l.add(Node(key: path.toString(), label: " $k", expanded: exp, children: _mapToNodeList(v, path, filterList, expand, filter)));
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

// TreeViewTheme buildTreeViewTheme(final AppThemeData appThemeData) {
//   return TreeViewTheme(
//     expanderTheme: const ExpanderThemeData(
//       type: ExpanderType.arrow,
//       modifier: ExpanderModifier.circleOutlined,
//       position: ExpanderPosition.start,
//       size: 20,
//     ),
//     labelStyle: appThemeData.tsTreeViewLabel,
//     parentLabelStyle: appThemeData.tsTreeViewParentLabel,
//     colorScheme: ColorScheme.fromSeed(seedColor: appThemeData.primary),
//     verticalSpacing: 5,
//   );
// }
