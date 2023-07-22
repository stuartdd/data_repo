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
          color: appThemeData.error.med,
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
    final Map<String, dynamic> jsonDataMap, // The original data from the file TODO Remove jsonDataMap. Use rootTreeNode instead
    final MyTreeNode treeNodeDataRoot,
    final MyTreeNode selectedTreeNode,
    final bool isEditDataDisplay,
    final bool horizontal, // Display horizontal or vertical split pane
    final double splitPaneDivPosition, // The split pane divider position
    final AppThemeData appThemeData, // The colour scheme
    final NodeCopyBin nodeCopyBin,
    final PathPropertiesList pathPropertiesList,
    final Function(Path) onSelect, // Called when a tree node in selected
    final Function(double) onDivChange, // Called when the split pane divider is moved
    final Path Function(DetailAction) onDataAction,
    final Widget Function(BuildContext, Node<dynamic>) buildNode,
    final void Function(String) log) {
  // Called when one of the detail buttons is pressed
  /// Left right or Top bottom
  ///
  if (jsonDataMap.isEmpty) {
    log("__DATA:__ No data loaded");
    return DisplayData.error(appThemeData, ("No data has been loaded"));
  }
  if (treeNodeDataRoot.isEmpty) {
    log("__DATA:__ No data to dispaly");
    return DisplayData.error(appThemeData, ("No data to display"));
  }

  final selectedPath = selectedTreeNode.path;
  final SplitViewMode splitViewMode = horizontal ? SplitViewMode.Horizontal : SplitViewMode.Vertical;
  final SplitViewController splitViewController = SplitViewController(weights: [splitPaneDivPosition, 1 - splitPaneDivPosition], limits: [WeightLimit(min: splitMinTree, max: 1.0), WeightLimit(min: splitMinDetail, max: 1.0)]);

  /// Create the detail.
  final Widget detailContainer;
  final node = DataLoad.getNodeFromJson(jsonDataMap, selectedPath);
  if (node != null) {
    detailContainer = _createDetailContainer(node, selectedPath, isEditDataDisplay, horizontal, pathPropertiesList, appThemeData, nodeCopyBin, onDataAction);
  } else {
    detailContainer = Container(
      color: appThemeData.error.darkest,
      child: const Center(child: Text("Selected Node was not found in the data")),
    );
  }

  final scrollController = ScrollController();
  final listView = MyTreeNodeWidgetList(
    treeNodeDataRoot,
    selectedTreeNode,
    selectedPath,
    appThemeData,
    appThemeData.treeNodeHeight,
    (selectedNode) {
      onSelect(selectedNode.path);
    },
    pathPropertiesList,
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

Widget createNodeNavButtonBar(final Path selectedPath, final NodeCopyBin nodeCopyBin, final AppThemeData appThemeData, bool isEditDataDisplay, bool beforeDataLoaded, final Path Function(DetailAction) dataAction) {

  final pathUp = dataAction(DetailAction(ActionType.querySelect, false, selectedPath, additional: "up"));
  final pathDown = dataAction(DetailAction(ActionType.querySelect, false, selectedPath, additional: "down"));
  final pathRight = dataAction(DetailAction(ActionType.querySelect, false, selectedPath, additional: "right"));
  final pathParent = selectedPath.hasParent ? selectedPath.cloneParentPath() : Path.empty();
  return Row(
    children: [
      DetailIconButton(
        onPressed: () {
          dataAction(DetailAction(ActionType.select, false, Path.empty()));
        },
        tooltip: "Home",
        iconData: Icons.home,
        appThemeData: appThemeData,
      ),
      DetailIconButton(
        enabled: pathParent.isNotEmpty,
        onPressed: () {
          dataAction(DetailAction(ActionType.select, false, pathParent));
        },
        tooltip: "Back (${pathParent.toString()})",
        iconData: Icons.north_west,
        appThemeData: appThemeData,
      ),
      DetailIconButton(
        enabled: pathUp.isNotEmpty,
        onPressed: () {
          dataAction(DetailAction(ActionType.select, true, pathUp));
        },
        tooltip: "Up (${pathUp.toString()})",
        iconData: Icons.arrow_upward,
        appThemeData: appThemeData,
      ),
      DetailIconButton(
        enabled: pathDown.isNotEmpty,
        onPressed: () {
          dataAction(DetailAction(ActionType.select, true, pathDown));
        },
        tooltip: "Down (${pathDown.toString()})",
        iconData: Icons.arrow_downward,
        appThemeData: appThemeData,
      ),
      DetailIconButton(
        enabled: pathRight.isNotEmpty,
        onPressed: () {
          dataAction(DetailAction(ActionType.select, true, pathRight));
        },
        tooltip: "Right (${pathRight.toString()})",
        iconData: Icons.subdirectory_arrow_right,
        appThemeData: appThemeData,
      ),
    ],
  );
}

Widget _createDetailContainer(final dynamic selectedNode, Path selectedPath, final bool isEditDataDisplay, final bool isHorizontal, PathPropertiesList pathPropertiesList, final AppThemeData appThemeData, NodeCopyBin copyBin, final Path Function(DetailAction) dataAction) {
  if (selectedNode is! Map<String, dynamic>) {
    throw JsonException(selectedPath, message: "Selected path should be a map");
  }
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
          pathPropertiesList: pathPropertiesList,
          dataAction: dataAction,
          isEditDataDisplay: isEditDataDisplay,
          isHorizontal: isHorizontal,
        )
    ],
  );
}
