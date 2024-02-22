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
  removeLocalFile, // Remove local file and restart
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

enum FunctionalType { errorType, emptyType, textType, boolType, doubleType, intType, positionalType, markdownType, linkType, referenceType, trueType, falseType, groupType }

const int maxIntValue = -1 >>> 1;

const emptyString = "";
const extensionSeparator = ":";
const positionalStringExtension = "${extensionSeparator}pl";
const markDownExtension = "${extensionSeparator}md";
const referenceExtension = "${extensionSeparator}rf";
const linkExtension = "${extensionSeparator}ln";
const noExtension = "";

const functionalTypeDataNotFound = FunctionalTypeData(String, FunctionalType.errorType, true, "", "error", noExtension, "Error", "Type Not Found", -maxIntValue, maxIntValue);
const functionalTypeDataUndefined = FunctionalTypeData(String, FunctionalType.emptyType, true, "", "empty", noExtension, "Undefined", "Undefined type", -maxIntValue, maxIntValue);
const functionalTypeDataGroup = FunctionalTypeData(String, FunctionalType.groupType, false, "", "String", noExtension, "Group", "Contains other elements", -maxIntValue, maxIntValue);

const functionalTypeDataText = FunctionalTypeData(String, FunctionalType.textType, true, "", "String", noExtension, "Text", "Single line of Text", -maxIntValue, maxIntValue);
const functionalTypeDataBool = FunctionalTypeData(bool, FunctionalType.boolType, false, "true", "bool", noExtension, "Boolean", "Yes or No", 2, 3);
const functionalTypeDataDouble = FunctionalTypeData(double, FunctionalType.doubleType, false, "0.0", "double", noExtension, "Decimal", "Decimal number", -maxIntValue, maxIntValue);
const functionalTypeDataInt = FunctionalTypeData(int, FunctionalType.intType, false, "0", "int", noExtension, "Integer", "Integer number", -maxIntValue, maxIntValue);

// Values to identify special case String values as Positional, References, Links or Markdown. All MUST be strings.
const functionalTypeDataPositional = FunctionalTypeData(String, FunctionalType.positionalType, true, "", "positional", positionalStringExtension, "Positional", "Positional List", -maxIntValue, maxIntValue);
const functionalTypeDataMarkDown = FunctionalTypeData(String, FunctionalType.markdownType, true, "", "markdown", markDownExtension, "Mark Down", "Multi Line Markdown", -maxIntValue, maxIntValue);
const functionalTypeDataLink = FunctionalTypeData(String, FunctionalType.linkType, true, "", "Link", linkExtension, "Link", "Web link or url", -maxIntValue, maxIntValue);
const functionalTypeDataReference = FunctionalTypeData(String, FunctionalType.referenceType, true, "", "reference", referenceExtension, "Reference", "Reference to another item", -maxIntValue, maxIntValue);

// Only used for Options when setting boolean values.
const functionalTypeDataBoolYes = FunctionalTypeData(bool, FunctionalType.trueType, true, "", "true", noExtension, "Yes", "A Yes value", 2, 3);
const functionalTypeDataBoolNo = FunctionalTypeData(bool, FunctionalType.falseType, true, "", "false", noExtension, "No", "A No value", 2, 3);

// Don't add simpleDisplayData to this list.
const Map<String, FunctionalTypeData> _functionalTypeSuffixMap = {
  positionalStringExtension: functionalTypeDataPositional,
  markDownExtension: functionalTypeDataMarkDown,
  referenceExtension: functionalTypeDataReference,
  linkExtension: functionalTypeDataLink,
};

const Map<Type, FunctionalTypeData> _functionalNativeTypeMap = {
  String: functionalTypeDataText,
  int: functionalTypeDataInt,
  double: functionalTypeDataDouble,
  bool: functionalTypeDataBool,
};

const List<FunctionalTypeData> optionForRenameDataElement = [
  functionalTypeDataPositional,
  functionalTypeDataMarkDown,
  functionalTypeDataReference,
  functionalTypeDataLink,
  functionalTypeDataText,
];

const List<FunctionalTypeData> optionForUpdateDataElement = [
  functionalTypeDataText,
  functionalTypeDataBool,
  functionalTypeDataDouble,
  functionalTypeDataInt,
];

const List<FunctionalTypeData> optionGroupUYesNo = [
  functionalTypeDataBoolYes,
  functionalTypeDataBoolNo,
];

class FunctionalTypeData {
  final Type nativeType;
  final FunctionalType functionalType;
  final bool cannotChangeNativeType;
  final String initialValue;
  final String typeName;
  final String suffix;
  final String displayName;
  final String typeHint;
  final int min; // For length (string) or magnitude (int, double..)
  final int max;
  const FunctionalTypeData(this.nativeType, this.functionalType, this.cannotChangeNativeType, this.initialValue, this.typeName, this.suffix, this.displayName, this.typeHint, this.min, this.max);

  factory FunctionalTypeData.toTrueFalseOptionsType(String value) {
    final vlc = value.trim().toLowerCase();
    if (vlc == "true" || vlc == "yes" || vlc == "1") {
      return functionalTypeDataBoolYes;
    }
    return functionalTypeDataBoolNo;
  }

  static FunctionalTypeData staticFindFunctionalTypeFromSuffixOrType(Type? nativeType, String elementNameWithSuffix) {
    // Find by suffix first
    final en = elementNameWithSuffix.trim().toLowerCase();
    for (var suf in _functionalTypeSuffixMap.keys) {
      if (en.endsWith(suf)) {
        return _functionalTypeSuffixMap[suf]!;
      }
    }
    // Not a known suffix so use native type
    if (nativeType != null) {
      if (_functionalNativeTypeMap.containsKey(nativeType)) {
        return _functionalNativeTypeMap[nativeType]!;
      }
    }
    return functionalTypeDataNotFound;
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

  bool get hasSuffix {
    return suffix.isNotEmpty;
  }

  bool get hasNoSuffix {
    return suffix.isEmpty;
  }

  bool get isNotString {
    return nativeType != String;
  }

  bool get canChangeNativeType {
    return isNotString || hasSuffix;
  }

  bool get isEmptyType {
    return functionalType == FunctionalType.emptyType;
  }

  bool get isRefType {
    return functionalType == FunctionalType.referenceType;
  }

  bool get isLinkType {
    return functionalType == FunctionalType.linkType;
  }

  bool isNotEqual(FunctionalTypeData other) {
    return functionalType != other.functionalType || nativeType != other.nativeType;
  }

  bool isEqual(FunctionalTypeData other) {
    return !isNotEqual(other);
  }

  @override
  String toString() {
    if (suffix.isNotEmpty) {
      return "FunctionalType:'$functionalType' Fixed:[$cannotChangeNativeType] FunctionalSuffix:[$suffix] Native:[$nativeType]  Fixed:[$cannotChangeNativeType] Hint:$typeHint";
    }
    return "FunctionalType:'$functionalType' Native:[$nativeType] Hint:$typeHint";
  }

  String inRangeDouble(String pref, double n) {
    return inRangeInt(pref, n.toInt());
  }
}

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
  final String currentValue; // The value as a String
  final FunctionalTypeData currentValueType; // The type details of the node
  final bool isValueData; // Value or group node
  final Path path; // Path to the Tree node
  final String additional; // Some additional data if required
  final bool Function(String, String, String)? onCompleteActionNullable;
  DetailAction(this.action, this.isValueData, this.path, {this.currentValue = "", this.currentValueType = functionalTypeDataUndefined, this.onCompleteActionNullable, this.additional = ""});

  factory DetailAction.actionOnly(ActionType action) {
    return DetailAction(action, false, Path.empty());
  }

  factory DetailAction.actionAndPath(ActionType action, Path path) {
    return DetailAction(action, false, path);
  }

  factory DetailAction.actionAndString(ActionType action, String additional) {
    return DetailAction(action, false, Path.empty(), additional: additional);
  }

  String validateTypeChange(String nameNoSuffix, dynamic content, final FunctionalTypeData oldType, final FunctionalTypeData newType) {
    if (newType != currentValueType) {
      if (oldType.functionalType == FunctionalType.markdownType) {
        if (content == null) {
          return "Value is null";
        }
        if (content is! String) {
          return "Value is not text";
        }
        for (var c in content.runes) {
          debugPrint("Char $c ${String.fromCharCode(c)}");
          if (c < 32) {
            return "Value has multiple lines";
          }
        }
      }
    }
    return "";
  }

  String getDisplayValue(bool editMode) {
    if (editMode) {
      debugPrint("getDisplayValue:Path.Last: ${path.last}");
      return path.last.substring(0, path.last.length - currentValueType.suffix.length);
    }
    debugPrint("getDisplayValue:CurrentValue: ${currentValueType.suffix.length} $currentValue");
    return currentValue.substring(0, currentValue.length - currentValueType.suffix.length);
  }

  String get valueName {
    if (isValueData) {
      return currentValueType.cannotChangeNativeType ? "${currentValueType.displayName} Type" : "Name";
    } else {
      return "Group";
    }
  }

  @override
  String toString() {
    final s = "Type:'${isValueData ? "Value" : "Map"}' Path:'$path' V1:'$currentValue' ";
    switch (action) {
      case ActionType.setSearch:
        {
          return "SET_SEARCH";
        }
      case ActionType.changePassword:
        {
          return "CHANGE_PW";
        }
      case ActionType.removeLocalFile:
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
