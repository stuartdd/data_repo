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
const OptionsTypeData optionTypeDataString = OptionsTypeData(String, "String", "Single line text");
const OptionsTypeData optionTypeDataBool = OptionsTypeData(bool, "bool", "Yes or No", min: 2, max: 3);
const OptionsTypeData optionTypeDataDouble = OptionsTypeData(double, "double", "Decimal number");
const OptionsTypeData optionTypeDataInt = OptionsTypeData(int, "int", "Integer number");
// Values to identify special case String values as Positional Lists or Markdown
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
  optionTypeDataString,
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
enum ActionType { none, editStart, renameStart, select, delete, link, clip }

class DetailAction {
  final ActionType action;
  final bool value;
  final Path path;
  final String oldValue;
  final OptionsTypeData oldValueType;
  final bool Function(String, String, String) onCompleteAction;
  final String additional;
  DetailAction(this.action, this.value, this.path, this.oldValue, this.oldValueType, this.onCompleteAction, {this.additional = ""});

  String getLastPathElement() {
    return path.getLast();
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
    }
  }
}

