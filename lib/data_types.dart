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
import 'package:flutter/material.dart';
import 'path.dart';

//
// Display type data distinguishes between a
//    Simple entry (String number boolean)
//    A positional value (Each char displayed with position)
//    Mark Down text
//    Other display types as required
// This data is structured so
//
enum DisplayType { simpleDisplay, positionalString, markDown, referenceString }

enum SimpleButtonActions { ok, select, cancel, validate, copy, move, delete, listRemove, listClear, link }

enum ActionType {
  // Actions implemented in main.dart _handleAction
  none,
  reload, // Reload the data, Confirms if data was updated
  restart, // Restart the application, Confirms if data was updated
  clearState, // Reset (delete) the saved state config json
  clearTheme, // Remove file specific theme from config
  save, // Save as it is (encrypted or un-encrypted)
  saveAlt, // Save unencrypted as encrypted OR save encrypted as un-encrypted
  flipSorted,
  addGroup, // Add a group entry to the data at the selected group
  addDetail, // Add a detail (leaf node) at the selected group
  editItemData, // Edit the current items data (value) and type (String int double bool...)
  renameItem, // Edit the current items name (key) and type (MarkDown, List, Reference...)
  about, // Display About dialogue
  settings, // Display settings dialogue
  chooseFile, // Display merged list of server and local files
  changePassword, // Change password if file is encrypted and restart
  removeLocal, // Remove local file and restart
  setSearch,
  checkReferences,
  createFile,
  select,
  querySelect,
  removeItem,
  link,
  clip,
  groupSelectClearAll,
  groupSelectAll,
  groupSelect,
  groupCopy,
  groupDelete,
  showLog,
}

const int maxIntValue = -1 >>> 1;

class DisplayTypeData {
  final DisplayType displayType;
  final String extension;
  final int extensionLength;
  final String description;
  const DisplayTypeData({required this.displayType, required this.extension, required this.extensionLength, required this.description});
}

const emptyString = "";
const extensionSeparator = ":";
const positionalStringExtension = "${extensionSeparator}pl";
const markDownExtension = "${extensionSeparator}md";
const referenceExtension = "${extensionSeparator}rf";
const linkExtension = "${extensionSeparator}ln";
const noExtension = "";

const DisplayTypeData simpleDisplayData = DisplayTypeData(displayType: DisplayType.simpleDisplay, extension: noExtension, extensionLength: noExtension.length, description: 'Simple Value [str,int,bool]');
const DisplayTypeData positionalStringData = DisplayTypeData(displayType: DisplayType.positionalString, extension: positionalStringExtension, extensionLength: positionalStringExtension.length, description: 'Positional List');
const DisplayTypeData referenceStringData = DisplayTypeData(displayType: DisplayType.referenceString, extension: referenceExtension, extensionLength: referenceExtension.length, description: 'Reference String');
const DisplayTypeData linkData = DisplayTypeData(displayType: DisplayType.referenceString, extension: referenceExtension, extensionLength: referenceExtension.length, description: 'Reference String');
const DisplayTypeData markDownData = DisplayTypeData(displayType: DisplayType.markDown, extension: markDownExtension, extensionLength: markDownExtension.length, description: 'Markdown Text');

// End Display type data
//
enum FunctionalType { errorType, emptyType, textType, boolType, doubleType, intType, positionalType, markdownType, linkType, referenceType, groupType, valueType, trueType, falseType }

class FunctionalTypeData {
  final Type native;
  final FunctionalType type;
  final String name;
  final String desc;
  final String hint;
  const FunctionalTypeData(this.native, this.type, this.name, this.desc, this.hint);
  /*
  Can the value 'fit' in the type!
  */
  String validateType(dynamic v) {
    switch (type) {
      case FunctionalType.groupType:
        {
          if (v is! Map) {
            return "Is not $desc";
          }
          break;
        }
      case FunctionalType.valueType:
      case FunctionalType.referenceType:
      case FunctionalType.linkType:
      case FunctionalType.markdownType:
      case FunctionalType.positionalType:
      case FunctionalType.textType:
      case FunctionalType.boolType:
      case FunctionalType.intType:
        {
          if (v.runtimeType != native) {
            return "Is not $desc";
          }
          break;
        }
      case FunctionalType.doubleType:
        {
          if (v.runtimeType != int && v.runtimeType != native) {
            return "Is not $desc";
          }
          break;
        }
      case FunctionalType.emptyType:
      case FunctionalType.errorType:
        {
          return "Is $desc type";
        }
      case FunctionalType.trueType:
        {
          if (v.runtimeType != native) {
            return "Is not $desc";
          }
          if (v != true) {
            return "Is Boolean but not $desc";
          }
          break;
        }
      case FunctionalType.falseType:
        {
          if (v.runtimeType != native) {
            return "Is not $desc";
          }
          if (v != false) {
            return "Is Boolean but not $desc";
          }
          break;
        }
    }
    return "";
  }
}

const optionsDataTypeEmpty = OptionsTypeData(FunctionalTypeData(String, FunctionalType.emptyType, "empty", "Empty", "Contains nothing"));
const OptionsTypeData optionTypeDataNotFound = OptionsTypeData(FunctionalTypeData(String, FunctionalType.errorType, "error", "Error", "Type Not Found"));
const OptionsTypeData optionTypeDataString = OptionsTypeData(FunctionalTypeData(String, FunctionalType.textType, "text", "Text", "Text"));
const OptionsTypeData optionTypeDataBool = OptionsTypeData(FunctionalTypeData(bool, FunctionalType.boolType, "bool", "Boolean", "Yes or No"), initialValue: "true", min: 2, max: 3);
const OptionsTypeData optionTypeDataDouble = OptionsTypeData(FunctionalTypeData(double, FunctionalType.doubleType, "double", "Decimal", "Decimal number"), initialValue: "0.0");
const OptionsTypeData optionTypeDataInt = OptionsTypeData(FunctionalTypeData(int, FunctionalType.intType, "int", "Integer", "Integer number"), initialValue: "0");

// Values to identify special case String values as Positional Lists or Markdown
const OptionsTypeData optionTypeDataPositional = OptionsTypeData(FunctionalTypeData(String, FunctionalType.positionalType, "positional", "Text", "Positional List"), nameSuffix: positionalStringExtension, dataValueTypeFixed: true);
const OptionsTypeData optionTypeDataMarkDown = OptionsTypeData(FunctionalTypeData(String, FunctionalType.markdownType, "markdown", "Mark Down", "Multi Line Markdown"), nameSuffix: markDownExtension, dataValueTypeFixed: true);
const OptionsTypeData optionTypeDataLink = OptionsTypeData(FunctionalTypeData(String, FunctionalType.linkType, "Link", "Link", "Web link or url"), nameSuffix: linkExtension, dataValueTypeFixed: true);
const OptionsTypeData optionTypeDataReference = OptionsTypeData(FunctionalTypeData(String, FunctionalType.referenceType, "reference", "Reference", "Reference to another item"), nameSuffix: referenceExtension, dataValueTypeFixed: true);
// Values for adding elements as groups or values
const OptionsTypeData optionTypeDataGroup = OptionsTypeData(FunctionalTypeData(Map, FunctionalType.groupType, "group", "Group", "Contains a Group Name"), min: 2, max: 30, dataValueTypeFixed: true);
const OptionsTypeData optionTypeDataValue = OptionsTypeData(FunctionalTypeData(String, FunctionalType.valueType, "value", "Value", "Contains a Value Name"), min: 2, max: 30, dataValueTypeFixed: true);
// Value for function 'forTypeOrName(Type type, String name)' if no match found
const OptionsTypeData optionTypeDataBoolYes = OptionsTypeData(FunctionalTypeData(bool, FunctionalType.trueType, "true", "Yes", "A Yes value"), min: 2, max: 3);
const OptionsTypeData optionTypeDataBoolNo = OptionsTypeData(FunctionalTypeData(bool, FunctionalType.falseType, "false", "No", "A No value"), min: 2, max: 3);

// Don't add simpleDisplayData to this list.
const Map<String, OptionsTypeData> optionsTypeSuffixMap = {
  positionalStringExtension: optionTypeDataPositional,
  markDownExtension: optionTypeDataMarkDown,
  referenceExtension: optionTypeDataReference,
  linkExtension: optionTypeDataLink,
};

const Map<Type, OptionsTypeData> optionsTypeMap = {
  String: optionTypeDataString,
  int: optionTypeDataInt,
  double: optionTypeDataDouble,
  bool: optionTypeDataBool,
};

//
// When renaming a data element the Options are derived from this class.
//
class OptionsTypeData {
  final FunctionalTypeData fnType;
  final bool dataValueTypeFixed;
  final String nameSuffix;
  final String initialValue; // Extension for special sub types like positional markdown link and reference.
  final int min; // For length (string) or magnitude (int, double..)
  final int max;
  const OptionsTypeData(this.fnType, {this.initialValue = "", this.nameSuffix = noExtension, this.min = -maxIntValue, this.max = maxIntValue, this.dataValueTypeFixed = false});

  static OptionsTypeData staticFindOptionTypeInList(Type type, String elementName, List<OptionsTypeData> l, OptionsTypeData fallback) {
    final toFind = staticFindOptionTypeFromNameAndType(type, elementName);
    if (toFind != optionTypeDataNotFound) {
      for (int i = 0; i < l.length; i++) {
        if (l[i].fnType.type == toFind.fnType.type) {
          return toFind;
        }
      }
    }
    return fallback;
  }

  static OptionsTypeData staticFindOptionTypeFromNameAndType(Type? type, String elementName) {
    final en = elementName.trim().toLowerCase();
    for (var suf in optionsTypeSuffixMap.keys) {
      if (en.endsWith(suf)) {
        return optionsTypeSuffixMap[suf]!;
      }
    }
    if (type != null) {
      if (optionsTypeMap.containsKey(type)) {
        return optionsTypeMap[type]!;
      }
    }
    return optionTypeDataNotFound;
  }

  /*
  Can the value 'fit' in the type!
  */
  String validateType(dynamic value) {
    return fnType.validateType(value);
  }

  bool notEqual(OptionsTypeData other) {
    return fnType.type != other.fnType.type || fnType.native != other.fnType.native;
  }

  bool equal(OptionsTypeData other) {
    return !notEqual(other);
  }

  bool get isEmpty {
    return equal(optionsDataTypeEmpty);
  }

  String get displayName {
    return fnType.desc;
  }

  bool get hasSuffix {
    return nameSuffix.isNotEmpty;
  }

  bool get hasNoSuffix {
    return nameSuffix.isEmpty;
  }

  bool get isRef {
    return nameSuffix == referenceExtension;
  }

  bool get isNotRef {
    return nameSuffix != referenceExtension;
  }

  @override
  String toString() {
    if (nameSuffix.isNotEmpty) {
      return "FunctionalType:'${fnType.type}' Fixed:[$dataValueTypeFixed] FunctionalSuffix:[$nameSuffix] Native:[${fnType.native}]  Fixed:[$dataValueTypeFixed] Hint:${fnType.hint}";
    }
    return "FunctionalType:'${fnType.type}' Native:[${fnType.native}] Hint:${fnType.hint}";
  }

  String inRangeInt(String pref, int n) {
    if (n < min) {
      return "$pref must be above $min";
    } else {
      if (n > max) {
        return "$pref must be below $max";
      }
    }
    return "";
  }

  String inRangeDouble(String pref, double n) {
    return inRangeInt(pref, n.toInt());
  }

  factory OptionsTypeData.toTrueFalseOptionsType(String value) {
    final vlc = value.trim().toLowerCase();
    if (vlc == "true" || vlc == "yes" || vlc == "1") {
      return optionTypeDataBoolYes;
    }
    return optionTypeDataBoolNo;
  }
}

// Values for Native types

const List<OptionsTypeData> optionGroupNative = [
  optionTypeDataString,
  optionTypeDataBool,
  optionTypeDataDouble,
  optionTypeDataInt,
];

const List<OptionsTypeData> optionGroupSpecial = [
  optionTypeDataPositional,
  optionTypeDataMarkDown,
  optionTypeDataReference,
  optionTypeDataLink,
];

const List<OptionsTypeData> optionGroupOther = [
  optionTypeDataGroup,
  optionTypeDataValue,
];

const List<OptionsTypeData> optionGroupRenameElement = [
  optionTypeDataPositional,
  optionTypeDataMarkDown,
  optionTypeDataReference,
  optionTypeDataString,
];

const List<OptionsTypeData> optionGroupUpdateElement = [
  optionTypeDataString,
  optionTypeDataBool,
  optionTypeDataDouble,
  optionTypeDataInt,
];

const List<OptionsTypeData> optionGroupUYesNo = [
  optionTypeDataBoolYes,
  optionTypeDataBoolNo,
];

//
// An action from a GUI component serviced by the maim State full GUI.
//

class MenuOptionDetails {
  final IconData Function() _getIcon;
  late final bool _enabled;
  late final Color? separatorColour;
  final String _title;
  final String _subTitle;
  final ActionType action;
  MenuOptionDetails(this._title, this._subTitle, this.action, this._getIcon, {bool enabled = true, this.separatorColour}) {
    _enabled = enabled;
  }

  factory MenuOptionDetails.separator(Color separatorColour, {bool enabled = true}) {
    return MenuOptionDetails("", "", ActionType.none, () {
      return Icons.add;
    }, enabled: enabled, separatorColour: separatorColour);
  }

  bool get isNotGroup {
    return separatorColour == null;
  }

  bool get isGroup {
    return separatorColour != null;
  }

  String title(final List<String> x) {
    return _sub(_title, x);
  }

  IconData? get icon {
    return _getIcon();
  }

  bool get enabled {
    return _enabled;
  }

  String subTitle(final List<String> x) {
    return _sub(_subTitle, x);
  }

  bool get hasSubText {
    return _subTitle.isNotEmpty;
  }

  String _sub(String s, final List<String> x) {
    if (s.isEmpty) {
      return "";
    }
    for (int i = 0; i < x.length; i++) {
      s = s.replaceAll("%{$i}", x[i]);
    }
    return s;
  }
}

//
// Passed to the _handleAction function in main.dart
//
class DetailAction {
  final ActionType action;
  final bool value; // Value or group node
  final Path path; // Path to the Tree node
  final String oldValue; // The value as a String
  final OptionsTypeData oldValueType; // The type details of the node
  final String additional; // Some additional data if required
  final bool Function(String, String, String)? onCompleteActionNullable;
  DetailAction(this.action, this.value, this.path, {this.oldValue = "", this.oldValueType = optionsDataTypeEmpty, this.onCompleteActionNullable, this.additional = ""});

  factory DetailAction.actionOnly(ActionType action) {
    return DetailAction(action, false, Path.empty());
  }

  factory DetailAction.actionAndString(ActionType action, String additional) {
    return DetailAction(action, false, Path.empty(), additional: additional);
  }

  String getLastPathElement() {
    return path.last;
  }

  String getDisplayValue(bool editMode) {
    return oldValue.substring(0, oldValue.length - oldValueType.nameSuffix.length);
  }

  String get valueName {
    return value ? "Value" : "Group";
  }

  @override
  String toString() {
    final s = "Type:'${value ? "Value" : "Map"}' Path:'$path' V1:'$oldValue' ";
    switch (action) {
      case ActionType.setSearch:
        {
          return "SET_SEARCH";
        }
      case ActionType.changePassword:
        {
          return "CHANGE_PW";
        }
      case ActionType.removeLocal:
        {
          return "REMOVE_LOCAL";
        }
      case ActionType.clearTheme:
        {
          return "CLEAR_THEME";
        }
      case ActionType.settings:
        {
          return "SETTINGS";
        }
      case ActionType.chooseFile:
        {
          return "CHOOSE_FILE";
        }
      case ActionType.checkReferences:
        {
          return "CHECK_REF";
        }
      case ActionType.about:
        {
          return "ABOUT";
        }
      case ActionType.showLog:
        {
          return "SHOW_LOG: $s";
        }
      case ActionType.clearState:
        {
          return "CLEAR_STATE: $s";
        }
      case ActionType.none:
        {
          return "NONE: $s";
        }
      case ActionType.flipSorted:
        {
          return "NONE: $s";
        }
      case ActionType.querySelect:
        {
          return "QUERY_SELECT: $s";
        }
      case ActionType.reload:
        {
          return "RELOAD: $s";
        }
      case ActionType.restart:
        {
          return "RESTART: $s";
        }
      case ActionType.save:
        {
          return "SAVE: $s";
        }
      case ActionType.saveAlt:
        {
          return "SAVE-ALT: $s";
        }
      case ActionType.editItemData:
        {
          return "EDIT: $s";
        }
      case ActionType.groupSelect:
        {
          return "GROUP-SEL: $s";
        }
      case ActionType.groupCopy:
        {
          return "GROUP-COPY: $s";
        }
      case ActionType.groupSelectClearAll:
        {
          return "GROUP-SELECT-CLEAR-ALL: $s";
        }
      case ActionType.groupSelectAll:
        {
          return "GROUP-SELECT-ALL: $s";
        }
      case ActionType.groupDelete:
        {
          return "GROUP-DELETE: $s";
        }
      case ActionType.renameItem:
        {
          return "RENAME: $s";
        }
      case ActionType.select:
        {
          return "SELECT: $s";
        }
      case ActionType.removeItem:
        {
          return "DELETE: $s";
        }
      case ActionType.link:
        {
          return "LINK: $s";
        }
      case ActionType.clip:
        {
          return "CLIP: $s";
        }
      case ActionType.addGroup:
        {
          return "ADD-GROUP: $s";
        }
      case ActionType.createFile:
        {
          return "CREATE_FILE: $s";
        }
      case ActionType.addDetail:
        {
          return "ADD-DETAIL: $s";
        }
    }
  }
}

class GroupCopyMoveSummaryList {
  final List<GroupCopyMoveSummary> list;
  GroupCopyMoveSummaryList(this.list);

  int get length {
    return list.length;
  }

  bool get isNotEmpty {
    return list.isNotEmpty;
  }

  bool get isEmpty {
    return list.isEmpty;
  }

  bool get hasNoErrors {
    for (var gs in list) {
      if (gs.isError) {
        return false;
      }
    }
    return true;
  }

  bool get hasErrors {
    for (var gs in list) {
      if (gs.isError) {
        return true;
      }
    }
    return false;
  }
}

class GroupCopyMoveSummary {
  final Path copyFromPath;
  final String error;
  final bool isValue;
  late final String name;
  late final String parent;

  GroupCopyMoveSummary(this.copyFromPath, this.error, this.isValue) {
    name = copyFromPath.last;
    parent = copyFromPath.cloneParentPath().toString();
  }

  factory GroupCopyMoveSummary.empty() {
    return GroupCopyMoveSummary(Path.empty(), "", false);
  }

  bool get isNotEmpty {
    return copyFromPath.isNotEmpty;
  }

  bool get isEmpty {
    return copyFromPath.isEmpty;
  }

  bool get isError {
    return error.isNotEmpty;
  }

  @override
  String toString() {
    return "CopyMoveSummary: $copyFromPath Error: $error.";
  }
}

class SuccessState {
  final String message;
  final String path;
  final String value;
  final bool _isSuccess;
  late final Exception? _exception;
  SuccessState(this._isSuccess, {this.message = "", this.value = "", this.path = "", Exception? exception, void Function(String)? log}) {
    _exception = exception;
    if (log != null) {
      if (_exception != null) {
        if (message.isEmpty) {
          log("__EXCEPTION:__ ${_exception.toString()}");
        } else {
          log("__EXCEPTION:__ $message. ${_exception.toString()}");
        }
      } else {
        if (!_isSuccess) {
          log("__FAIL:__ '$message'");
        } else {
          if (message.isNotEmpty) {
            log("__OK:__ $message");
          }
        }
      }
    }
  }

  bool get hasException {
    return (_exception != null);
  }

  bool get isSuccess {
    if (hasException) {
      return false;
    }
    return _isSuccess;
  }

  bool get isFail {
    return !isSuccess;
  }

  Exception? get exception {
    return _exception;
  }

  String toLogString({bool bold = true}) {
    final bb = bold ? "__" : "";
    if (_exception != null) {
      if (message.isEmpty) {
        return "${bb}EXCEPTION:$bb ${_exception.toString()}";
      } else {
        return "${bb}EXCEPTION:$bb $message. ${_exception.toString()}";
      }
    } else {
      if (isFail) {
        if (message.isNotEmpty) {
          return "${bb}FAIL:$bb $message";
        }
        return "${bb}FAIL$bb";
      } else {
        if (message.isNotEmpty) {
          return "${bb}OK:$bb $message";
        }
        return "${bb}OK$bb";
      }
    }
  }

  String toStatusString(String prefix) {
    final m = message.trim().replaceFirst("__", " ").replaceFirst("__", ':');
    if (_exception != null) {
      if (m.isEmpty) {
        return "EXCEPTION: ${_exception.toString()}";
      } else {
        return "EXCEPTION: $m. ${_exception.toString()}";
      }
    } else {
      if (isFail) {
        return "${prefix}FAIL:$m";
      } else {
        return "${prefix}OK:$m";
      }
    }
  }

  @override
  String toString() {
    return toLogString(bold: false);
  }
}

class ScreenSize {
  double _width = 0;
  double _height = 0;
  ScreenSize();

  void update(double w, double h) {
    _width = w;
    _height = h;
  }

  double widthA(double adjustW) {
    return _width + adjustW;
  }

  double heightA(double adjustH) {
    return _height + adjustH;
  }

  double get width {
    return _width;
  }

  double get height {
    return _height;
  }

  Size size(double adjustW, double adjustH) {
    return Size(widthA(adjustW), heightA(adjustH));
  }
}
