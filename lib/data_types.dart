import 'package:data_repo/data_load.dart';
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
enum DisplayType { simpleDisplay, positionalString, markDown }

const int maxIntValue = -1 >>> 1;

class DisplayTypeData {
  final DisplayType displayType;
  final String marker;
  final int markerLength;
  final String description;
  const DisplayTypeData({required this.displayType, required this.marker, required this.markerLength, required this.description});
}

const positionalStringMarker = ".pl";
const markDownMarker = ".md";

const DisplayTypeData simpleDisplayData = DisplayTypeData(displayType: DisplayType.simpleDisplay, marker: '', markerLength: 0, description: 'Simple Value [str,int,bool]');
const DisplayTypeData positionalStringData = DisplayTypeData(displayType: DisplayType.positionalString, marker: positionalStringMarker, markerLength: positionalStringMarker.length, description: 'Positional List');
const DisplayTypeData markDownData = DisplayTypeData(displayType: DisplayType.markDown, marker: markDownMarker, markerLength: markDownMarker.length, description: 'Markdown Text');
const Map<String, DisplayTypeData> displayTypeMap = {
  positionalStringMarker: positionalStringData,
  markDownMarker: markDownData,
};
// End Display type data
//

const optionsDataTypeEmpty = OptionsTypeData(String, "string", "empty");
//
// When renaming a data element the Options are derived from this class.
//
class OptionsTypeData {
  final Type elementType;
  final String key;
  final String description;
  final String suffix;
  final int min;
  final int max;
  const OptionsTypeData(this.elementType, this.key, this.description, {this.suffix = "", this.min = -maxIntValue, this.max = maxIntValue});

  factory OptionsTypeData.empty() {
    return optionsDataTypeEmpty;
  }

  static OptionsTypeData locateTypeInOptionsList(String key, List<OptionsTypeData> l, OptionsTypeData fallback) {
    for (int i = 0; i < l.length; i++) {
      if (l[i].key == key) {
        return l[i];
      }
    }
    return fallback;
  }

  bool notEqual(OptionsTypeData other) {
    return key != other.key;
  }

  bool equal(OptionsTypeData other) {
    return key == other.key;
  }

  @override
  String toString() {
    return "OptionsTypeData: Key:$key Suffix: $suffix Desc:$description";
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
        if (n.endsWith(x.key)) {
          return x;
        }
      }
      for (var x in _elementTypesOther) {
        if (n == x.key) {
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
const OptionsTypeData optionTypeDataString = OptionsTypeData(String, "String", "Text");
const OptionsTypeData optionTypeDataBool = OptionsTypeData(bool, "bool", "Yes or No", min: 2, max: 3);
const OptionsTypeData optionTypeDataDouble = OptionsTypeData(double, "double", "Decimal number");
const OptionsTypeData optionTypeDataInt = OptionsTypeData(int, "int", "Integer number");
// Values to identify special case String values as Positional Lists or Markdown
const OptionsTypeData optionTypeDataSimple = OptionsTypeData(String, positionalStringMarker, "Simple", suffix: positionalStringMarker);
const OptionsTypeData optionTypeDataPositional = OptionsTypeData(String, positionalStringMarker, "Positional List", suffix: positionalStringMarker);
const OptionsTypeData optionTypeDataMarkDown = OptionsTypeData(String, markDownMarker, "Multi Line Markdown", suffix: markDownMarker);
// Values for adding elements as groups or values
const OptionsTypeData optionTypeDataGroup = OptionsTypeData(String, "Group", "A Group Name", suffix: "", min: 2, max: 30);
const OptionsTypeData optionTypeDataValue = OptionsTypeData(String, "Value", "A Value Name", suffix: "", min: 2, max: 30);
// Value for function 'forTypeOrName(Type type, String name)' if no match found
const OptionsTypeData optionTypeDataNotFound = OptionsTypeData(String, "String", "Type Not Found");

const OptionsTypeData optionTypeDataBoolYes = OptionsTypeData(bool, "true", "Yes", min: 2, max: 3);
const OptionsTypeData optionTypeDataBoolNo = OptionsTypeData(bool, "false", "No", min: 2, max: 3);

const List<OptionsTypeData> _elementTypesNative = [
  optionTypeDataString,
  optionTypeDataBool,
  optionTypeDataDouble,
  optionTypeDataInt,
];

const List<OptionsTypeData> _elementTypesSpecial = [
  optionTypeDataPositional,
  optionTypeDataMarkDown,
];

const List<OptionsTypeData> _elementTypesOther = [
  optionTypeDataGroup,
  optionTypeDataValue,
];

const List<OptionsTypeData> optionsForRenameElement = [
  optionTypeDataPositional,
  optionTypeDataMarkDown,
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
enum ActionType {none, editStart, renameStart, select, delete, link, clip, copyNode, cutNode, pasteNode, group}

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
      case ActionType.editStart:
        {
          return "EDIT-START: $s";
        }
      case ActionType.group:
        {
          return "GROUP-SEL: $s";
        }
      case ActionType.renameStart:
        {
          return "RENAME-START: $s";
        }
      case ActionType.select:
        {
          return "SELECT: $s";
        }
      case ActionType.delete:
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
      case ActionType.copyNode:
        {
          return "COPY NODE: $s";
        }
      case ActionType.cutNode:
        {
          return "CUT NODE: $s";
        }
      case ActionType.pasteNode:
        {
          return "PASTE NODE: $s";
        }
    }
  }
}

class NodeCopyBin {
  final Path copyFromPath;
  final bool cut;
  late final bool hasData;
  final Map<String, dynamic> copyNode;
  NodeCopyBin(this.copyFromPath, this.cut, this.copyNode) {
    hasData = copyFromPath.isNotEmpty;
  }

  factory NodeCopyBin.empty() {
    return NodeCopyBin(Path.empty(), false, {});
  }

  bool isNotEmpty() {
    return copyFromPath.isNotEmpty;
  }

  @override
  String toString() {
    return "${cut?"CUT":"COPY"} ${copyFromPath.toString()}\n${DataLoad.mapToString(copyNode)}";
  }
}

class SuccessState {
  final String message;
  final String value;
  final bool _isSuccess;
  late final Exception? _exception;
  SuccessState(this._isSuccess, {this.message = "", this.value = "", Exception? exception, void Function(String)? log}) {
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

  @override
  String toString() {
    return toLogString(bold: false);
  }

  bool isDifferentFrom(SuccessState other) {
    if (isSuccess != other.isSuccess) {
      return true;
    }
    if (value != other.value) {
      return true;
    }
    if (message != other.message) {
      return true;
    }
    return false;
  }
}