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

enum SimpleButtonActions { ok, cancel, validate, copy, move, delete, listRemove, listClear, link }

enum ActionType { none, reload, restart, save, saveAlt, flipSorted, addGroup, addDetail, editItemData, createFile, renameItem, select, querySelect, removeItem, link, clip, groupSelectClearAll, groupSelectAll, groupSelect, groupCopy, groupDelete }

const int maxIntValue = -1 >>> 1;

class DisplayTypeData {
  final DisplayType displayType;
  final String extension;
  final int extensionLength;
  final String description;
  const DisplayTypeData({required this.displayType, required this.extension, required this.extensionLength, required this.description});
}

const positionalStringExtension = ":pl";
const markDownExtension = ":md";
const referenceExtension = ":rf";
const simpleExtension = "";

const DisplayTypeData simpleDisplayData = DisplayTypeData(displayType: DisplayType.simpleDisplay, extension: simpleExtension, extensionLength: simpleExtension.length, description: 'Simple Value [str,int,bool]');
const DisplayTypeData positionalStringData = DisplayTypeData(displayType: DisplayType.positionalString, extension: positionalStringExtension, extensionLength: positionalStringExtension.length, description: 'Positional List');
const DisplayTypeData referenceStringData = DisplayTypeData(displayType: DisplayType.referenceString, extension: referenceExtension, extensionLength: referenceExtension.length, description: 'Reference String');
const DisplayTypeData markDownData = DisplayTypeData(displayType: DisplayType.markDown, extension: markDownExtension, extensionLength: markDownExtension.length, description: 'Markdown Text');

// Don't add simpleDisplayData to this list.
const Map<String, DisplayTypeData> displayTypeMap = {
  positionalStringExtension: positionalStringData,
  markDownExtension: markDownData,
  referenceExtension: referenceStringData,
};
// End Display type data
//

const optionsDataTypeEmpty = OptionsTypeData(String, "string", "empty", simpleExtension);

//
// When renaming a data element the Options are derived from this class.
//
class OptionsTypeData {
  final Type elementType; // Native 'dart' type
  final String uniqueKey; // Local type 'Group', 'positional' ,'String',,,
  final String description; // For the user
  final String suffix; // Extension for special sub types like positional markdown and reference.
  final int min;
  final int max;
  const OptionsTypeData(this.elementType, this.uniqueKey, this.description, this.suffix, {this.min = -maxIntValue, this.max = maxIntValue});

  static OptionsTypeData locateTypeInOptionsList(String uniqueKey, List<OptionsTypeData> l, OptionsTypeData fallback) {
    for (int i = 0; i < l.length; i++) {
      if (l[i].uniqueKey == uniqueKey) {
        return l[i];
      }
    }
    return fallback;
  }

  bool notEqual(OptionsTypeData other) {
    return uniqueKey != other.uniqueKey;
  }

  bool equal(OptionsTypeData other) {
    return uniqueKey == other.uniqueKey;
  }

  bool get isEmpty {
    return equal(optionsDataTypeEmpty);
  }

  @override
  String toString() {
    return "OptionsTypeData: uniqueKey:$uniqueKey Suffix: $suffix Desc:$description";
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

  factory OptionsTypeData.forTypeOrName(Type type, String name) {
    final n = name.trim();
    if (n.isNotEmpty) {
      for (var x in _elementTypesSpecial) {
        if (n.endsWith(x.suffix)) {
          return x;
        }
      }
      for (var x in _elementTypesOther) {
        if (n == x.uniqueKey) {
          return x;
        }
      }
    }
    for (var x in _elementTypesNative) {
      if (type == x.elementType) {
        return x;
      }
    }
    return optionTypeDataNotFound;
  }

  factory OptionsTypeData.toTrueFalse(String value) {
    final vlc = value.trim().toLowerCase();
    if (vlc == "true" || vlc == "yes" || vlc == "1") {
      return optionTypeDataBoolYes;
    }
    return optionTypeDataBoolNo;
  }
}

// Values for Native types
const OptionsTypeData optionTypeDataString = OptionsTypeData(String, "", "Text", simpleExtension);
const OptionsTypeData optionTypeDataBool = OptionsTypeData(bool, "bool", "Yes or No", simpleExtension, min: 2, max: 3);
const OptionsTypeData optionTypeDataDouble = OptionsTypeData(double, "double", "Decimal number", simpleExtension);
const OptionsTypeData optionTypeDataInt = OptionsTypeData(int, "int", "Integer number", simpleExtension);
// Values to identify special case String values as Positional Lists or Markdown
const OptionsTypeData optionTypeDataSimple = OptionsTypeData(String, "text", "Simple", simpleExtension);
const OptionsTypeData optionTypeDataPositional = OptionsTypeData(String, "positional", "Positional List",positionalStringExtension);
const OptionsTypeData optionTypeDataMarkDown = OptionsTypeData(String, "markdown", "Multi Line Markdown", markDownExtension);
const OptionsTypeData optionTypeDataReference = OptionsTypeData(String, "reference", "Reference to another item", referenceExtension);
// Values for adding elements as groups or values
const OptionsTypeData optionTypeDataGroup = OptionsTypeData(String, "Group", "A Group Name", simpleExtension, min: 2, max: 30);
const OptionsTypeData optionTypeDataValue = OptionsTypeData(String, "Value", "A Value Name", simpleExtension, min: 2, max: 30);
// Value for function 'forTypeOrName(Type type, String name)' if no match found
const OptionsTypeData optionTypeDataNotFound = OptionsTypeData(String, "String", "Type Not Found", simpleExtension);

const OptionsTypeData optionTypeDataBoolYes = OptionsTypeData(bool, "true", "Yes", simpleExtension, min: 2, max: 3);
const OptionsTypeData optionTypeDataBoolNo = OptionsTypeData(bool, "false", "No", simpleExtension, min: 2, max: 3);

const List<OptionsTypeData> _elementTypesNative = [
  optionTypeDataString,
  optionTypeDataBool,
  optionTypeDataDouble,
  optionTypeDataInt,
];

const List<OptionsTypeData> _elementTypesSpecial = [
  optionTypeDataPositional,
  optionTypeDataMarkDown,
  optionTypeDataReference,
];

const List<OptionsTypeData> _elementTypesOther = [
  optionTypeDataGroup,
  optionTypeDataValue,
];

const List<OptionsTypeData> optionsForRenameElement = [
  optionTypeDataPositional,
  optionTypeDataMarkDown,
  optionTypeDataReference,
  optionTypeDataSimple,
];

const List<OptionsTypeData> optionsForUpdateElement = [
  optionTypeDataString,
  optionTypeDataBool,
  optionTypeDataDouble,
  optionTypeDataInt,
];

const List<OptionsTypeData> optionsForAddElement = [
  optionTypeDataGroup,
  optionTypeDataValue,
];

const List<OptionsTypeData> optionsForYesNo = [
  optionTypeDataBoolYes,
  optionTypeDataBoolNo,
];

const List<OptionsTypeData> optionsEditElementValue = [];

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

  String getLastPathElement() {
    return path.last;
  }

  String getDisplayValue(bool editMode) {
    return oldValue.substring(0, oldValue.length - oldValueType.suffix.length);
  }

  String get valueName {
    return value ? "Value" : "Group";
  }

  @override
  String toString() {
    final s = "Type:'${value ? "Value" : "Map"}' Path:'$path' V1:'$oldValue' ";
    switch (action) {
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
  final String fileContent;
  final bool _isSuccess;
  late final Exception? _exception;
  SuccessState(this._isSuccess, {this.message = "", this.fileContent = "", this.path = "", Exception? exception, void Function(String)? log}) {
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

  String toStatusString() {
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
          return "OK: $m";
        }
        return "OK";
      }
    }
  }

  @override
  String toString() {
    return toLogString(bold: false);
  }
}
