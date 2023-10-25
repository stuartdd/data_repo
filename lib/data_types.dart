import 'package:flutter/cupertino.dart';
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

enum ActionType { none, reload, restart, clearState, save, saveAlt, flipSorted, addGroup, addDetail, editItemData, createFile, renameItem, select, querySelect, removeItem, link, clip, groupSelectClearAll, groupSelectAll, groupSelect, groupCopy, groupDelete, showLog }

const int maxIntValue = -1 >>> 1;

class DisplayTypeData {
  final DisplayType displayType;
  final String extension;
  final int extensionLength;
  final String description;
  const DisplayTypeData({required this.displayType, required this.extension, required this.extensionLength, required this.description});
}

const emptyString = "";
const positionalStringExtension = ":pl";
const markDownExtension = ":md";
const referenceExtension = ":rf";
const linkExtension = ":ln";
const noExtension = "";

const DisplayTypeData simpleDisplayData = DisplayTypeData(displayType: DisplayType.simpleDisplay, extension: noExtension, extensionLength: noExtension.length, description: 'Simple Value [str,int,bool]');
const DisplayTypeData positionalStringData = DisplayTypeData(displayType: DisplayType.positionalString, extension: positionalStringExtension, extensionLength: positionalStringExtension.length, description: 'Positional List');
const DisplayTypeData referenceStringData = DisplayTypeData(displayType: DisplayType.referenceString, extension: referenceExtension, extensionLength: referenceExtension.length, description: 'Reference String');
const DisplayTypeData linkData = DisplayTypeData(displayType: DisplayType.referenceString, extension: referenceExtension, extensionLength: referenceExtension.length, description: 'Reference String');
const DisplayTypeData markDownData = DisplayTypeData(displayType: DisplayType.markDown, extension: markDownExtension, extensionLength: markDownExtension.length, description: 'Markdown Text');

// End Display type data
//

const optionsDataTypeEmpty = OptionsTypeData(String, "string", "empty");
const OptionsTypeData optionTypeDataNotFound = OptionsTypeData(String, "error", "Type Not Found");
const OptionsTypeData optionTypeDataString = OptionsTypeData(String, "text", "Text", functionalTypeName: "Text");
const OptionsTypeData optionTypeDataBool = OptionsTypeData(bool, "bool", "Yes or No", initialValue: "true", min: 2, max: 3, functionalTypeName: "Boolean");
const OptionsTypeData optionTypeDataDouble = OptionsTypeData(double, "double", "Decimal number", initialValue: "0.0", functionalTypeName: "Decimal");
const OptionsTypeData optionTypeDataInt = OptionsTypeData(int, "int", "Integer number", initialValue: "0", functionalTypeName: "Integer");
// Values to identify special case String values as Positional Lists or Markdown
const OptionsTypeData optionTypeDataPositional = OptionsTypeData(String, "positional", "Positional List", nameSuffix: positionalStringExtension, dataValueTypeFixed: true, functionalTypeName: "List");
const OptionsTypeData optionTypeDataMarkDown = OptionsTypeData(String, "markdown", "Multi Line Markdown", nameSuffix: markDownExtension, dataValueTypeFixed: true, functionalTypeName: "MD");
const OptionsTypeData optionTypeDataLink = OptionsTypeData(String, "link", "Web link or url", nameSuffix: linkExtension, dataValueTypeFixed: true, functionalTypeName: "Web Link");
const OptionsTypeData optionTypeDataReference = OptionsTypeData(String, "reference", "Reference to another item", nameSuffix: referenceExtension, dataValueTypeFixed: true, functionalTypeName: "Reference");
// Values for adding elements as groups or values
const OptionsTypeData optionTypeDataGroup = OptionsTypeData(String, "group", "A Group Name", min: 2, max: 30, dataValueTypeFixed: true);
const OptionsTypeData optionTypeDataValue = OptionsTypeData(String, "value", "A Value Name", min: 2, max: 30, dataValueTypeFixed: true);
// Value for function 'forTypeOrName(Type type, String name)' if no match found
const OptionsTypeData optionTypeDataBoolYes = OptionsTypeData(bool, "true", "Yes", min: 2, max: 3);
const OptionsTypeData optionTypeDataBoolNo = OptionsTypeData(bool, "false", "No", min: 2, max: 3);

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
  final Type dataValueType; // Native 'dart' type
  final bool dataValueTypeFixed;
  final String functionalType; // Local type 'group', 'positional' ,'String',,,
  final String functionalTypeName; // Local type 'group', 'positional' ,'String',,,
  final String description; // For the user
  final String nameSuffix;
  final String initialValue; // Extension for special sub types like positional markdown link and reference.
  final int min; // For length (string) or magnitude (int, double..)
  final int max;
  const OptionsTypeData(this.dataValueType, this.functionalType, this.description, {this.functionalTypeName = "", this.initialValue = "", this.nameSuffix = noExtension, this.min = -maxIntValue, this.max = maxIntValue, this.dataValueTypeFixed = false});

  static OptionsTypeData staticFindOptionTypeInList(Type type, String elementName, List<OptionsTypeData> l, OptionsTypeData fallback) {
    final toFind = staticFindOptionTypeFromNameAndType(type, elementName);
    if (toFind != optionTypeDataNotFound) {
      for (int i = 0; i < l.length; i++) {
        if (l[i].functionalType == toFind.functionalType) {
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
    if (type!=null) {
      if (optionsTypeMap.containsKey(type)) {
        return optionsTypeMap[type]!;
      }
    }
    return optionTypeDataNotFound;
  }

  bool notEqual(OptionsTypeData other) {
    return functionalType != other.functionalType || dataValueType != other.dataValueType;
  }

  bool equal(OptionsTypeData other) {
    return !notEqual(other);
  }

  bool get isEmpty {
    return equal(optionsDataTypeEmpty);
  }

  String get displayName {
    return functionalTypeName.isEmpty? functionalType : functionalTypeName;
  }

  bool get hasSuffix {
    return nameSuffix.isNotEmpty;
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
      return "FunctionalType:'$functionalType' Fixed:[$dataValueTypeFixed] FunctionalSuffix:[$nameSuffix] DataValueType:[$dataValueType]  Fixed:[$dataValueTypeFixed] Desc:$description";
    }
    return "FunctionalType:'$functionalType' DataValueType:[$dataValueType] Desc:$description";
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
  final String _s1;
  final String _s2;
  final ActionType action;
  MenuOptionDetails(this._s1, this._s2, this.action, this._getIcon, {bool enabled = true}) {
    _enabled = enabled;
  }

  String s1(final List<String> x) {
    if (_s1.isEmpty) {
      return "";
    }
    return _sub(_s1, x);
  }

  IconData? get icon {
    return _getIcon();
  }

  bool get enabled {
    return _enabled;
  }

  String s2(final List<String> x) {
    if (_s2.isEmpty) {
      return "";
    }
    return _sub(_s2, x);
  }

  bool get hasSubText {
    return _s2.isNotEmpty;
  }

  String _sub(String s, final List<String> x) {
    for (int i = 0; i < x.length; i++) {
      s = s.replaceAll("%{$i}", x[i]);
    }
    return s;
  }
}

class DetailAction {
  final ActionType action;
  final bool value;
  final Path path;
  final String oldValue;
  final OptionsTypeData oldValueType;
  final bool Function(String, String, String)? onCompleteActionNullable;
  final String additional;
  DetailAction(this.action, this.value, this.path, {this.oldValue = "", this.oldValueType = optionsDataTypeEmpty, this.onCompleteActionNullable, this.additional = ""});

  factory DetailAction.actionOnly(ActionType action) {
    return DetailAction(action, false, Path.empty());
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
        if (m.isNotEmpty) {
          return "FAIL: $m";
        }
        return "FAIL";
      } else {
        if (m.isNotEmpty) {
          return "${prefix}OK:$m";
        }
        return "${prefix}OK:";
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
