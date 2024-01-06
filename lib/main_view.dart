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

import 'package:data_repo/config.dart';
import 'package:flutter/material.dart';
import 'package:split_view/split_view.dart';
import 'data_container.dart';
import "data_types.dart";
import 'detail_buttons.dart';
import "path.dart";
import "treeNode.dart";
import 'detail_widget.dart';

const double splitMinTree = 0.2;
const double splitMinDetail = 0.4;

class DisplaySplitView {
  DisplaySplitView(this.splitView, this.scrollController, {this.isOk = true});
  final Widget splitView;
  final ScrollController scrollController;
  final bool isOk;

  factory DisplaySplitView.error(final AppThemeData appThemeData, final String message) {
    return DisplaySplitView(
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
DisplaySplitView createSplitView(
    final DataContainer data,
    final MyTreeNode filteredTreeNodeDataRoot,
    final MyTreeNode unfilteredTreeNodeDataRoot,
    final MyTreeNode selectedTreeNode,
    final bool isEditDataDisplay,
    final bool horizontal, // Display horizontal or vertical split pane
    final double splitPaneDivPosition, // The split pane divider position
    final AppThemeData appThemeData, // The colour scheme
    final PathPropertiesList pathPropertiesList,
    final Function(Path) onSelect, // Called when a tree node in selected
    final Function(Path) onExpand, // Called when a tree node in selected
    final SuccessState Function(String) onResolve, // Called when a tree node in selected
    final Function(double) onDivChange, // Called when the split pane divider is moved
    final Path Function(DetailAction) onDataAction,
    final void Function(String) log,
    final int isSorted,
    final String rootNodeName) {
  // Called when one of the detail buttons is pressed
  /// Left right or Top bottom
  ///
  if (data.isEmpty) {
    log("__DATA:__ No data loaded");
    return DisplaySplitView.error(appThemeData, ("No data has been loaded"));
  }
  if (filteredTreeNodeDataRoot.isEmpty) {
    log("__DATA:__ No data to display");
    return DisplaySplitView.error(appThemeData, ("No data to display"));
  }

  final selectedPath = selectedTreeNode.path;
  final SplitViewMode splitViewMode = horizontal ? SplitViewMode.Horizontal : SplitViewMode.Vertical;
  final SplitViewController splitViewController = SplitViewController(weights: [splitPaneDivPosition, 1 - splitPaneDivPosition], limits: [WeightLimit(min: splitMinTree, max: 1.0), WeightLimit(min: splitMinDetail, max: 1.0)]);

  /// Create the detail.
  final Widget detailContainer;
  final node = data.getNodeFromJson(selectedPath);
  if (node != null) {
    detailContainer = _createDetailContainer(node, selectedPath, unfilteredTreeNodeDataRoot, isEditDataDisplay, isSorted, horizontal, pathPropertiesList, appThemeData, onDataAction, onResolve);
  } else {
    log("__DATA:__ Selected Node was not found in the data");
    return DisplaySplitView.error(appThemeData, ("Selected Node was not found in the data"));
  }

  final scrollController = ScrollController();
  final listView = MyTreeNodeWidgetList(
    filteredTreeNodeDataRoot,
    rootNodeName,
    selectedTreeNode,
    selectedPath,
    appThemeData,
    (selectedNodePath) {
      onSelect(selectedNodePath);
    },
    (expandNodePath) {
      onExpand(expandNodePath);
    },
    pathPropertiesList,
    appThemeData.treeNodeHeight,
    isSorted,
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

  return DisplaySplitView(splitView, scrollController);
}

void _insertDisplayValueListInOrder(List<DataValueDisplayRow> displayValueList, DataValueDisplayRow dvdr, int order) {
  if (order == 0) {
    displayValueList.add(dvdr);
  } else {
    final name = dvdr.name.toLowerCase();
    for (int i = 0; i < displayValueList.length; i++) {
      final x = displayValueList[i].name.toLowerCase().compareTo(name);
      if (x == order) {
        displayValueList.insert(i, dvdr);
        return;
      }
    }
    displayValueList.add(dvdr);
  }
}

const _sortIconName = ["Un-Sort", "Ascending", "Descending"];
const _sortIcon = [Icons.sort, Icons.flight_takeoff, Icons.flight_land];

Widget createNodeNavButtonBar(final Path selectedPath, final AppThemeData appThemeData, bool isEditDataDisplay, bool beforeDataLoaded, int sorted, final Path Function(DetailAction) dataAction) {
  final pathParent = selectedPath.hasParent ? selectedPath.cloneParentPath() : Path.empty();
  final pathRight = dataAction(DetailAction(ActionType.querySelect, false, selectedPath, additional: "right"));
  final pathUp = dataAction(DetailAction(ActionType.querySelect, false, selectedPath, additional: "up"));
  final pathDown = dataAction(DetailAction(ActionType.querySelect, false, selectedPath, additional: "down"));

  return Row(
    children: [
      DetailIconButton(
        onPressed: (button) {
          dataAction(DetailAction(ActionType.flipSorted, false, Path.empty()));
        },
        tooltip: _sortIconName[sorted + 1],
        iconData: _sortIcon[sorted + 1],
        appThemeData: appThemeData,
      ),
      DetailIconButton(
        key: GlobalKey(), // Ensure initState is called
        enabled: pathParent.isNotEmpty,
        onPressed: (button) {
          dataAction(DetailAction(ActionType.select, false, selectedPath.cloneFirst()));
        },
        tooltip: "Home",
        iconData: Icons.home,
        appThemeData: appThemeData,
      ),
      DetailIconButton(
        key: GlobalKey(), // Ensure initState is called
        enabled: pathParent.isNotEmpty,
        onPressed: (button) {
          dataAction(DetailAction(ActionType.select, false, pathParent));
        },
        tooltip: "Back (${pathParent.toString()})",
        iconData: Icons.north_west,
        appThemeData: appThemeData,
      ),
      DetailIconButton(
        key: GlobalKey(), // Ensure initState is called
        enabled: pathUp.isNotEmpty,
        onPressed: (button) {
          dataAction(DetailAction(ActionType.select, true, pathUp));
        },
        tooltip: "Up (${pathUp.toString()})",
        iconData: Icons.arrow_upward,
        appThemeData: appThemeData,
      ),
      DetailIconButton(
        key: GlobalKey(), // Ensure initState is called
        enabled: pathDown.isNotEmpty,
        onPressed: (button) {
          dataAction(DetailAction(ActionType.select, true, pathDown));
        },
        tooltip: "Down (${pathDown.toString()})",
        iconData: Icons.arrow_downward,
        appThemeData: appThemeData,
      ),
      DetailIconButton(
        key: GlobalKey(), // Ensure initState is called
        enabled: pathRight.isNotEmpty,
        onPressed: (button) {
          dataAction(DetailAction(ActionType.select, true, pathRight));
        },
        tooltip: "RightX (${pathRight.toString()})",
        iconData: Icons.subdirectory_arrow_right,
        appThemeData: appThemeData,
      ),
    ],
  );
}

Widget _createDetailContainer(final dynamic selectedNode, Path selectedPath, MyTreeNode treeNodeRoot, final bool isEditDataDisplay, final int sortOrder, final bool isHorizontal, PathPropertiesList pathPropertiesList, final AppThemeData appThemeData, final Path Function(DetailAction) dataAction, SuccessState Function(String) onResolve) {
  if (selectedNode is! Map<String, dynamic>) {
    throw JsonException(selectedPath, message: "Selected path should be a map");
  }
  List<DataValueDisplayRow> properties = _dataDisplayValueListFromJson(selectedNode, selectedPath, treeNodeRoot, sortOrder);
  return ListView(
    shrinkWrap: true,
    children: [
      for (int index = 0; index < properties.length; index++)
        DetailWidget(
          dataValueRow: properties[index],
          appThemeData: appThemeData,
          pathPropertiesList: pathPropertiesList,
          dataAction: dataAction,
          onResolve: onResolve,
          isEditDataDisplay: isEditDataDisplay,
          isHorizontal: isHorizontal,
        )
    ],
  );
}

List<DataValueDisplayRow> _dataDisplayValueListFromJson(Map<String, dynamic> json, Path path, MyTreeNode treeNodeRoot, int sortOrder) {
  List<DataValueDisplayRow> lm = List.empty(growable: true);
  List<DataValueDisplayRow> lv = List.empty(growable: true);
  for (var element in json.entries) {
    if (element.value is Map) {
      final p = treeNodeRoot.findByPath(path.cloneAppend(element.key));
      if (p != null) {
        _insertDisplayValueListInOrder(lm, DataValueDisplayRow(element.key, "", optionTypeDataGroup, false, path, (element.value as Map).length, path.cloneAppend(element.key)), sortOrder);
      }
    } else if (element.value is List) {
      final p = treeNodeRoot.findByPath(path.cloneAppend(element.key));
      if (p != null) {
        _insertDisplayValueListInOrder(lm, DataValueDisplayRow(element.key, "", optionTypeDataGroup, false, path, (element.value as List).length, path.cloneAppend(element.key)), sortOrder);
      }
    } else {
      _insertDisplayValueListInOrder(lv, DataValueDisplayRow(element.key, element.value.toString(), OptionsTypeData.staticFindOptionTypeFromNameAndType(element.value.runtimeType, element.key), true, path, 0, path.cloneAppend(element.key)), sortOrder);
    }
  }
  lm.addAll(lv);
  return lm;
}
