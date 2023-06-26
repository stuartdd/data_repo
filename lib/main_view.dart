import 'dart:io';

import 'package:data_repo/config.dart';
import 'package:flutter/material.dart';
import 'package:split_view/split_view.dart';
import 'package:flutter_treeview/flutter_treeview.dart';
import 'data_load.dart';
import "data_types.dart";
import 'detail_buttons.dart';
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
    final double initPos, // The split pane divider position
    final AppThemeData appThemeData, // The colour scheme
    final NodeCopyBin nodeCopyBin,
    PathList hiLightedPath,
    final Function(Path) onSelect, // Called when a tree node in selected
    final Function(double) onDivChange, // Called when the split pane divider is moved
    final bool Function(DetailAction) onDataAction,
    final Widget Function(BuildContext, Node<dynamic>) buildNode,
    final void Function(String, int) searchResults,
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
    detailContainer = _createDetailContainer(node, selectedPath, isEditDataDisplay, horizontal, hiLightedPath, appThemeData, nodeCopyBin, onDataAction);
  } else {
    detailContainer = Container(
      color: appThemeData.error.shade900,
      child: const Center(child: Text("Selected Node was not found in the data")),
    );
  }
  int counter = -1;
  final scrollController = ScrollController();
  final listView = MyTreeNodeWidgetList(
    rootTreeNode,
    selectedPath,
    appThemeData,
    appThemeData.treeNodeHeight,
    (selectedNode) {
      onSelect(selectedNode.path);
    },
    search: filter,
    onSearchComplete: (searchExpression, rowCount) {
      if (searchExpression.isNotEmpty) {
        searchResults(searchExpression, rowCount);
      }
    },
    nodeNavigationBar: _createNodeNavButtonBar(selectedPath, nodeCopyBin, appThemeData, onDataAction),
  );

  final scroller = SingleChildScrollView(
    controller: scrollController,
    child: listView,
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

Widget _createNodeNavButtonBar(final Path selectedPath, final NodeCopyBin nodeCopyBin, final AppThemeData appThemeData, final bool Function(DetailAction) dataAction) {
  final canCopy = selectedPath.hasParent();
  final canPaste = nodeCopyBin.isNotEmpty() && nodeCopyBin.copyFromPath.isNotEqual(selectedPath);
  return Row(
    children: [
      DetailIconButton(
        onPressed: () {
          dataAction(DetailAction(ActionType.select, false, Path.empty()));
        },
        tooltip: "Home",
        icon: const Icon(Icons.home),
        appThemeData: appThemeData,
      ),
      DetailIconButton(
        show: selectedPath.hasParent(),
        onPressed: () {
          dataAction(DetailAction(ActionType.select, false, selectedPath.parentPath()));
        },
        tooltip: "Up one level",
        icon: const Icon(Icons.arrow_upward),
        appThemeData: appThemeData,
      ),
      DetailIconButton(
        show: canCopy,
        onPressed: () {
          dataAction(DetailAction(ActionType.copyNode, false, selectedPath));
        },
        tooltip: "Copy This Node",
        icon: const Icon(Icons.copy),
        appThemeData: appThemeData,
      ),
      DetailIconButton(
        show: canCopy,
        onPressed: () {
          dataAction(DetailAction(ActionType.cutNode, false, selectedPath));
        },
        tooltip: "Cut This Node",
        icon: const Icon(Icons.cut),
        appThemeData: appThemeData,
      ),
      DetailIconButton(
        show: canPaste,
        onPressed: () {
          dataAction(DetailAction(ActionType.pasteNode, false, selectedPath));
        },
        tooltip: "Paste into ${selectedPath.getLast()}",
        icon: const Icon(Icons.paste),
        appThemeData: appThemeData,
      ),
    ],
  );
}

Widget _createDetailContainer(final Map<String, dynamic> selectedNode, Path selectedPath, final bool isEditDataDisplay, final bool isHorizontal, PathList hiLightedPaths, final AppThemeData appThemeData, NodeCopyBin copyBin, final bool Function(DetailAction) dataAction) {
  List<DataValueDisplayRow> properties = _dataDisplayValueListFromJson(selectedNode, selectedPath);
  properties.sort(
    (a, b) {
      return a.name.compareTo(b.name);
    },
  );
  return ListView(
    shrinkWrap: true,
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
