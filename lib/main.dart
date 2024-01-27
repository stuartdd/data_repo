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
import 'dart:async';
import 'dart:io';
import 'package:data_repo/Isolator.dart';
import 'package:data_repo/config_settings.dart';
import 'package:data_repo/data_container.dart';
import 'package:data_repo/treeNode.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_size/window_size.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_window_close/flutter_window_close.dart';

import 'dialogs.dart';
import 'path.dart';
import 'data_types.dart';
import 'config.dart';
import 'logging.dart';
import 'appState.dart';
import 'main_view.dart';
import 'detail_buttons.dart';

late final ConfigData _configData;
late final ApplicationState _applicationState;
late final Isolator _isolator;

final logger = Logger(100, true);

bool _inExitProcess = false;
int _exitReturnCode = -1;

ScreenSize screenSize = ScreenSize();

_screenSize(BuildContext context) {
  final pt = MediaQuery.of(context).padding.top;
  final bi = MediaQuery.of(context).viewInsets.bottom - MediaQuery.of(context).viewInsets.top;
  final height = MediaQuery.of(context).size.height - (bi + pt) - 3; // Stops the scroll bar on RHS
  final width = MediaQuery.of(context).size.width;
  screenSize.update(width, height);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Get basic startup data
    final applicationDefaultDir = await ApplicationState.getApplicationDefaultDir();
    final isDesktop = ApplicationState.appIsDesktop();
    // Read the config file and ans specify app or desktop
    _configData = ConfigData(applicationDefaultDir, defaultConfigFileName, isDesktop, logger.log);
    _isolator = Isolator(applicationDefaultDir, _configData.shouldIsolate);
    _applicationState = ApplicationState.fromFile(_configData.getAppStateFileLocal(), logger.log);

    if (isDesktop) {
      // if desktop then set title, screen pos and size.
      setWindowTitle("${_configData.title}: ${_configData.getDataFileName()}");
      const WindowOptions(
        minimumSize: Size(200, 200),
        titleBarStyle: TitleBarStyle.normal,
      );
      setWindowFrame(Rect.fromLTWH(_applicationState.screen.x.toDouble(), _applicationState.screen.y.toDouble(), _applicationState.screen.w.toDouble(), _applicationState.screen.h.toDouble()));
    }
  } catch (e) {
    debugPrint(e.toString());
    exit(1);
  }

  runApp(MyApp());

  if (!_isolator.locked) {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isolator.shouldStop() && _configData.shouldIsolate) {
        _exitReturnCode = 9;
      }
      if (_exitReturnCode >= 0) {
        _isolator.close();
        exit(_exitReturnCode);
      }
    });
  }
}

class MyApp extends StatelessWidget with WindowListener {
  MyApp({super.key});

  @override
  onWindowEvent(final String eventName) async {
    if (_configData.isDesktop()) {
      switch (eventName) {
        case 'maximize':
        case 'minimize':
          {
            _applicationState.saveScreenSizeAndPos = false;
            break;
          }
        case 'unmaximize':
          {
            _applicationState.saveScreenSizeAndPos = true;
            break;
          }
        case 'move':
        case 'resize':
          {
            final info = await getWindowInfo();
            _applicationState.updateScreenPos(info.frame.left, info.frame.top, info.frame.width, info.frame.height);
            break;
          }
        default:
          {
            debugPrint("Unhandled Window Event:$eventName");
          }
      }
    }
    super.onWindowEvent(eventName);
  }

  @override
  Widget build(final BuildContext context) {
    if (_configData.isDesktop()) {
      // if not an app, signup for windows events (onWindowEvent)
      windowManager.addListener(this);
    }
    if (_isolator.locked) {
      return MaterialApp(
        title: 'data_repo',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: _isolator.lockPage("${_configData.title} LOCKED"),
      );
    } else {
      return MaterialApp(
        title: 'data_repo',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: MyHomePage(
          title: _configData.title,
        ),
      );
    }
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) an
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _remoteServerAvailable = false;
  List<String> _serverFileList = List.empty();
  String _initialPassword = "";
  String _search = "";
  String _lastSearch = "";
  bool _dataWasUpdated = false;
  bool _dataRequiresSyncing = false;
  bool _checkReferences = false;
  bool _isEditDataDisplay = false;
  double _navBarHeight = 0;
  SuccessState _globalSuccessState = SuccessState(true);
  ScrollController _treeViewScrollController = ScrollController();
  DataContainer _loadedData = DataContainer.empty();
  MyTreeNode _treeNodeDataRoot = MyTreeNode.empty();
  MyTreeNode _filteredNodeDataRoot = MyTreeNode.empty();
  MyTreeNode _selectedTreeNode = MyTreeNode.empty();
  Path _selectedPath = Path.empty();
  String _currentSelectedGroupsPrefix = "";
  final PathPropertiesList _pathPropertiesList = PathPropertiesList(log: logger.log);
  final TextEditingController _searchEditingController = TextEditingController(text: "");
  final TextEditingController _passwordEditingController = TextEditingController(text: "");
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();

  Path _querySelect(Path sel, String dir) {
    Path p = Path.empty();
    if (sel.isEmpty) {
      return p;
    }
    final n = _filteredNodeDataRoot.findByPath(sel);
    if (n == null) {
      return p;
    }
    switch (dir) {
      case "right":
        {
          p = n.firstChild;
          break;
        }
      case "down":
        {
          p = n.down;
          break;
        }
      case "up":
        {
          p = n.up;
          break;
        }
    }
    return p;
  }

  Future<void> _implementLinkStateAsync(final String href, final String from) async {
    var urlCanLaunch = await canLaunchUrlString(href); //canLaunch is from url_launcher package
    if (urlCanLaunch) {
      await launchUrlString(href); //launch is from url_launcher package to launch URL
      setState(() {
        _globalSuccessState = SuccessState(true, message: "Link launched: $from", log: logger.log);
      });
    } else {
      setState(() {
        _globalSuccessState = SuccessState(false, message: "Link could not be launched", log: logger.log);
      });
    }
  }

  void _selectNodeState(final Path path) {
    setState(() {
      _selectNode(path);
    });
  }

  void _selectNode(final Path path) {
    var pa = path;
    var sn = _treeNodeDataRoot.findByPath(pa);
    while ((sn == null || sn.isLeaf) && pa.length > 1) {
      pa = pa.cloneParentPath();
      sn = _treeNodeDataRoot.findByPath(pa);
    }
    if (sn != null) {
      _selectedTreeNode = sn;
      _selectedPath = _selectedTreeNode.path;
      _selectedTreeNode.setRequired(true);
      _selectedTreeNode.setExpandedParentNodes(true);
    } else {
      logger.log("__SELECT__ Failed Path:'$path'");
      return;
    }

    Future.delayed(
      const Duration(milliseconds: 300),
      () {
        int tni = _selectedTreeNode.index - 3;
        if (tni < 0) {
          tni = 0;
        }
        final index = tni * (_configData.getAppThemeData().treeNodeHeight + 1);
        if (_treeViewScrollController.hasClients) {
          _treeViewScrollController.animateTo(index, duration: const Duration(milliseconds: 400), curve: Curves.ease);
        }
      },
    );
  }

  void _onUpdateConfig() {
    setState(() {
      if (_loadedData.isEmpty) {
        setWindowTitle("${_configData.title}: ${_configData.getDataFileName()}");
      } else {
        setWindowTitle("${_configData.title}: ${_loadedData.fileName}");
      }
      if (_loadedData.isNotEmpty && (_configData.getDataFileLocalPath() != _loadedData.localSourcePath || _configData.getGetDataFileUrl() != _loadedData.remoteSourcePath)) {
        Future.delayed(
          const Duration(milliseconds: 300),
          () {
            logger.log("__WARNING__ Data source has changed");
            showModalButtonsDialog(
              context,
              _configData.getAppThemeData(),
              "Data source has Changed",
              ["If you CONTINUE:", "Saving and Reloading", "will use OLD config data", "and UNSAVED config", "changes may be lost."],
              ["RESTART", "CONTINUE"],
              Path.empty(),
              (path, button) {
                if (button == "RESTART") {
                  setState(() {
                    _clearData("Config updated - RESTART");
                    logger.log("__RESTART__ Local file ${_configData.getDataFileLocalPath()}");
                    logger.log("__RESTART__ Remote file ${_configData.getGetDataFileUrl()}");
                    setWindowTitle("${_configData.title}: ${_configData.getDataFileName()}");
                  });
                } else {
                  logger.log("__CONFIG__ CONTINUE option chosen");
                }
              },
              () {
                _setFocus("_onUpdateConfig");
              },
            );
          },
        );
      }
    });
  }

  void _expandNodeState(final Path path) {
    setState(() {
      final n = _treeNodeDataRoot.findByPath(path);
      if (n != null) {
        n.expanded = !n.expanded;
        _selectNode(path);
      }
    });
  }

  void _setSearchExpressionState(final String st) {
    _lastSearch = "[$st]"; // Force search to run in build method!
    setState(() {
      _searchEditingController.text = st;
      _search = st;
    });
    Future.delayed(
      const Duration(milliseconds: 200),
      () {
        _selectNodeState(_selectedPath);
      },
    );
  }

  GroupCopyMoveSummary _checkNodeForGroupSelection(final Path from, final Path to, final bool isValue, final bool groupCopy) {
    if (groupCopy) {
      return GroupCopyMoveSummary(from, _loadedData.copyInto(to, from, isValue, dryRun: true), isValue);
    }
    return GroupCopyMoveSummary(from, _loadedData.remove(from, isValue, dryRun: true), isValue);
  }

  GroupCopyMoveSummaryList _summariseGroupSelection(final PathPropertiesList pathPropertiesList, final bool groupCopy) {
    final sb = List<GroupCopyMoveSummary>.empty(growable: true);
    final groups = pathPropertiesList.groupSelectsClone;
    if (groups.isEmpty) {
      return GroupCopyMoveSummaryList(sb);
    }
    for (var p in groups.keys) {
      final d = groups[p];
      if (d != null) {
        final v = _checkNodeForGroupSelection(Path.fromDotPath(p), _selectedPath, d.isValue, groupCopy);
        sb.add(v);
      }
    }
    return GroupCopyMoveSummaryList(sb);
  }

  void _handleFutureAction(DetailAction detailActionData, int ms) {
    Future.delayed(Duration(milliseconds: ms), () async {
      if (mounted) {
        switch (detailActionData.action) {
          case ActionType.settings:
            {
              showConfigDialog(
                context,
                _configData,
                screenSize,
                _configData.getDataFileDir(),
                (validValue, detail) {
                  // Validate
                  return SettingValidation.ok();
                },
                (settingsControlList, save) {
                  // Commit
                  settingsControlList.commit(_configData, log: logger.log);
                  setState(() {
                    _configData.update();
                    if (save) {
                      _globalSuccessState = _configData.save(logger.log);
                    } else {
                      _globalSuccessState = SuccessState(true, message: "Config data NOT saved");
                    }
                  });
                },
                () {
                  return _dataWasUpdated ? "Must Save changes first" : "";
                },
                logger.log,
                () {
                  _setFocus("Settings");
                },
              );
              break;
            }
          case ActionType.chooseFile:
            {
              final localFileList = _configData.dir(
                fileExtensionDataList,
                [defaultConfigFileName, _configData.getAppStateFileName()],
                _serverFileList,
                (reasons, fatal) {
                  // Error - Path not found
                  Timer(
                    const Duration(microseconds: 200),
                    () {
                      showModalButtonsDialog(
                        context,
                        _configData.getAppThemeData(),
                        "Get File List Error",
                        reasons,
                        fatal ? ["Exit"] : ["OK"],
                        Path.empty(),
                        (path, button) {
                          if (fatal) {
                            _exitReturnCode = 1;
                          }
                        },
                        () {
                          _setFocus("Choose File");
                        },
                      );
                    },
                  );
                },
              );
              showFilesListDialog(
                context,
                _configData.getAppThemeData(),
                localFileList,
                true,
                (fileName) {
                  // OnSelect
                  if (fileName != _configData.getDataFileName()) {
                    _configData.setValueForJsonPath(dataFileLocalNamePath, fileName);
                    _configData.update(callOnUpdate: true);
                    logger.log("__CONFIG__ File name updated to:'$fileName'");
                    _configData.save(logger.log);
                  } else {
                    logger.log("__CONFIG__ File name not updated. No change");
                  }
                  _initialPassword = _passwordEditingController.text;
                  _passwordEditingController.text = "";
                  _loadDataState();
                },
                (action) {
                  // Create Local File
                  if (action == SimpleButtonActions.ok) {
                    _handleAction(DetailAction(ActionType.createFile, false, Path.empty()));
                  }
                },
                () {
                  // On Close - Refocus to Search or Password fields
                  _setFocus("showLocalFilesDialog");
                },
              );
              break;
            }
          case ActionType.about:
            {
              final aboutData = AboutData(
                "Data Repo",
                "Stuart Davies",
                _configData.authorEmail,
                _configData.buildDate,
                _configData.buildLocalPath,
                _configData.repoName,
                "Dart+Flutter",
                "GNU GENERAL PUBLIC LICENSE|Version 3|29 June 2007",
                "Manage structured data stored secularly in a local 'ReST' style web application.|Data can be stored using 64bit AES encryption.|A fallback copy is retained for when the server is not available.",
              );

              showMyAboutDialog(
                context,
                _configData.getAppThemeData().screenForegroundColour(true),
                _configData.getAppThemeData().secondary.lightest,
                screenSize,
                aboutData.getMD(),
                (dialogAction) {
                  _handleAction(dialogAction);
                },
                () {
                  _setFocus("About");
                },
              );
              break;
            }
          case ActionType.removeItem:
            {
              showModalButtonsDialog(context, _configData.getAppThemeData(), "Remove item", ["${detailActionData.valueName} '${detailActionData.getLastPathElement()}'"], ["OK", "Cancel"], detailActionData.path, _handleDeleteState, () {
                _setFocus("removeItem");
              });
              break;
            }
          case ActionType.showLog:
            {
              showLogDialog(
                context,
                _configData.getAppThemeData(),
                screenSize,
                logger,
                (dotPath) {
                  final p = Path.fromDotPath(dotPath);
                  if (p.isRational(_loadedData.dataMap)) {
                    _handleAction(DetailAction(ActionType.select, true, p.cloneParentPath()));
                    return true;
                  }
                  return false;
                },
                () {
                  _setFocus("Log");
                },
              );
              break;
            }
          case ActionType.saveAlt: // Save unencrypted as encrypted OR save encrypted as un-encrypted
            {
              showModalInputDialog(
                context,
                _configData.getAppThemeData(),
                screenSize,
                _loadedData.hasPassword ? "Confirm Password" : "New Password",
                "",
                [],
                optionsDataTypeEmpty,
                false,
                true,
                (button, pw, type) async {
                  if (button == SimpleButtonActions.ok) {
                    var usePw = pw;
                    if (_loadedData.hasPassword) {
                      // Confirm PW (Save un-encrypted)
                      logger.log("__SAVE__ Data as plain text");
                      usePw = "";
                    } else {
                      // New password (Save encrypted)
                      logger.log("__SAVE__ Data as ENCRYPTED text");
                    }
                    _saveDataStateAsync(_loadedData.dataToStringFormattedWithTs(usePw), usePw, false); // Don't save to remote!
                  }
                },
                (initial, value, initialType, valueType) {
                  // Validate
                  if (_loadedData.hasPassword) {
                    if (_loadedData.password != value) {
                      return "Invalid Password";
                    }
                  } else {
                    if (value.isEmpty) {
                      return "Password required";
                    }
                    if (value.length < 5) {
                      return "Password length";
                    }
                  }
                  return "";
                },
                () {
                  // Cancel and when dialog closed.
                  _setFocus("saveAlt");
                },
              );
              break;
            }
          case ActionType.groupCopy:
          case ActionType.groupDelete:
            {
              if (_pathPropertiesList.hasGroupSelects) {
                final groupCopy = detailActionData.action == ActionType.groupCopy;
                showCopyMoveDialog(
                  context,
                  _configData.getAppThemeData(),
                  _selectedPath,
                  _summariseGroupSelection(_pathPropertiesList, groupCopy),
                  groupCopy,
                  (action, intoPath) {
                    // onActionReturn
                    setState(() {
                      if (action == SimpleButtonActions.copy || action == SimpleButtonActions.move || action == SimpleButtonActions.delete) {
                        final groupMap = _pathPropertiesList.groupSelectsClone;
                        for (var k in groupMap.keys) {
                          // For copy and delete do each one in turn
                          if (action == SimpleButtonActions.copy || action == SimpleButtonActions.move) {
                            // for move and copy we must do a copy first
                            final resp = _loadedData.copyInto(intoPath, Path.fromDotPath(k), groupMap[k]!.isValue, dryRun: false);
                            if (resp.isEmpty) {
                              groupMap[k]!.done = true;
                              if (action == SimpleButtonActions.copy) {
                                // if not copy then move so we are not done, we need to delete after!
                                _dataWasUpdated = true;
                                _checkReferences = true;
                              }
                              _pathPropertiesList.setRenamed(intoPath.cloneAppend(Path.fromDotPath(k).last));
                              _pathPropertiesList.setRenamed(intoPath, shouldLog: false);
                            }
                          }
                        }

                        if (action == SimpleButtonActions.move || action == SimpleButtonActions.delete) {
                          for (var k in groupMap.keys) {
                            final resp = _loadedData.remove(Path.fromDotPath(k), groupMap[k]!.isValue, dryRun: false);
                            if (resp.isEmpty) {
                              groupMap[k]!.done = true;
                              _dataWasUpdated = true;
                              _checkReferences = true;
                              _pathPropertiesList.setRenamed(intoPath.cloneParentPath());
                            }
                          }
                        }

                        _pathPropertiesList.clearAllGroupSelectDone(
                          (path) {
                            if (path.isEmpty) {
                              return false;
                            }
                            return (_loadedData.getNodeFromJson(path) != null);
                          },
                        );

                        _reloadTreeFromMapAndCopyFlags();
                      }
                      if (action == SimpleButtonActions.listRemove) {
                        _pathPropertiesList.setGroupSelect(intoPath, false);
                      }
                      if (action == SimpleButtonActions.listClear) {
                        _pathPropertiesList.clearAllGroupSelect();
                      }
                    });
                    _handleAction(detailActionData);
                  },
                  (action, intoPath) {
                    // onActionClose. Node was selected in list.
                    if (action == SimpleButtonActions.select) {
                      setState(() {
                        _selectNode(intoPath);
                      });
                    }
                  },
                  () {
                    _setFocus("Move");
                  },
                );
              }
              break;
            }
          case ActionType.renameItem:
            {
              final title = detailActionData.valueName;
              showModalInputDialog(
                context,
                _configData.getAppThemeData(),
                screenSize,
                "Change $title '${detailActionData.getLastPathElement()}'",
                detailActionData.getDisplayValue(false),
                detailActionData.value ? optionGroupRenameElement : [],
                detailActionData.oldValueType,
                true,
                false,
                (action, text, type) {
                  if (action == SimpleButtonActions.ok) {
                    _handleRenameState(detailActionData, text, type);
                  }
                },
                (initial, value, initialType, valueType) {
                  //
                  // Validate a re-name
                  //
                  return _checkRenameOk(detailActionData, value, valueType);
                },
                () {
                  _setFocus("renameItem");
                },
              );
              break;
            }
          case ActionType.editItemData:
            {
              showModalInputDialog(
                context,
                _configData.getAppThemeData(),
                screenSize,
                "Update Value '${detailActionData.getLastPathElement()}'",
                detailActionData.oldValue,
                detailActionData.oldValueType.dataValueTypeFixed ? [] : optionGroupUpdateElement,
                detailActionData.oldValueType,
                false,
                false,
                (action, text, type) {
                  if (action == SimpleButtonActions.ok) {
                    _handleEditState(detailActionData, text, type);
                  } else {
                    if (action == SimpleButtonActions.link) {
                      _implementLinkStateAsync(text, detailActionData.path.last);
                    }
                  }
                },
                (initialTrimmed, valueTrimmed, initialType, valueType) {
                  //
                  // Validate a value type for Edit function
                  //
                  if (valueType.dataValueType == bool) {
                    final valueTrimmedLc = valueTrimmed.toLowerCase();
                    if (valueTrimmedLc == "yes" || valueTrimmedLc == "no" || valueTrimmedLc == "true" || valueTrimmedLc == "false") {
                      return "";
                    } else {
                      return "Must be 'Yes' or 'No";
                    }
                  }
                  if (valueType.dataValueType == String) {
                    if (valueType.equal(optionTypeDataReference)) {
                      if (valueTrimmed.isEmpty) {
                        return "Reference cannot be empty";
                      }
                      final ss = _checkSingleReference(Path.fromDotPath(valueTrimmed), valueTrimmed);
                      return ss.message;
                    }
                    if (valueTrimmed == initialTrimmed && initialTrimmed != "") {
                      return "";
                    }
                    final m = valueType.inRangeInt("Length", valueTrimmed.length);
                    if (m.isNotEmpty) {
                      return m;
                    }
                    return "";
                  }
                  if (valueType.dataValueType == double) {
                    try {
                      final d = double.parse(valueTrimmed);
                      return valueType.inRangeDouble("Value ", d);
                    } catch (e) {
                      return "That is not a ${valueType.description}";
                    }
                  }
                  if (valueType.dataValueType == int) {
                    try {
                      final i = int.parse(valueTrimmed);
                      return valueType.inRangeInt("Value ", i);
                    } catch (e) {
                      return "That is not a ${valueType.description}";
                    }
                  }
                  return "";
                },
                () {
                  _setFocus("editItemData");
                },
              );
              break;
            }
          case ActionType.addGroup:
            {
              showModalInputDialog(context, _configData.getAppThemeData(), screenSize, "New Group Owned by: ${_selectedPath.last}", "", [], optionsDataTypeEmpty, false, false, (action, text, type) {
                if (action == SimpleButtonActions.ok) {
                  _handleAddState(_selectedPath, text, optionTypeDataGroup);
                }
              }, (initial, value, initialType, valueType) {
                if (value.trim().isEmpty) {
                  return "Cannot be empty";
                }
                if (value.contains(".")) {
                  return "Cannot contain '.";
                }
                return "";
              }, () {
                _setFocus("addGroup");
              });
              break;
            }
          case ActionType.addDetail:
            {
              showModalInputDialog(context, _configData.getAppThemeData(), screenSize, "New Detail Name Owned by: ${_selectedPath.last}", "", [], optionsDataTypeEmpty, false, false, (action, text, type) {
                if (action == SimpleButtonActions.ok) {
                  _handleAddState(_selectedPath, text, optionTypeDataValue);
                }
              }, (initial, value, initialType, valueType) {
                if (value.trim().isEmpty) {
                  return "Cannot be empty";
                }
                if (value.contains(".")) {
                  return "Cannot contain '.";
                }
                return "";
              }, () {
                _setFocus("addDetail");
              });
              break;
            }
          case ActionType.createFile:
            {
              showFileNamePasswordDialog(
                context,
                _configData.getAppThemeData(),
                "New File",
                [
                  "Password if encryption is required:",
                  "Enter a valid file name:",
                  "File extension is added automatically.",
                  "Un-Encrypted extension = .json",
                  "Encrypted extension = .data",
                ],
                (action, fileName, password) {
                  final fn = _configData.getDataFileNameForCreate(fileName, password);
                  if (fn.toLowerCase() == defaultConfigFileName.toLowerCase()) {
                    return "Cannot use '$fileName'";
                  }
                  if (fn.toLowerCase() == _configData.getAppStateFileName().toLowerCase()) {
                    return "Cannot use '$fileName'";
                  }
                  if (_configData.localFileExists(fn)) {
                    return "${password.isNotEmpty ? "Encrypted" : ""} file '$fn' Exists";
                  }
                  if (action == SimpleButtonActions.ok) {
                    final content = DataContainer.staticDataToStringFormattedWithTs(_configData.getMinimumDataContentMap(), password, addTimeStamp: true, isNew: true);
                    final createFileName = _configData.getDataFileNameForCreate(fn, password, fullPath: true);
                    final success = DataContainer.saveToFile(createFileName, content, noClobber: true, log: logger.log);
                    _globalSuccessState = success;
                    if (success.isFail) {
                      logger.log("__CREATE__ Failed. ${success.message}");
                      Future.delayed(const Duration(milliseconds: 1), () {
                        if (mounted) {
                          showModalButtonsDialog(
                            context,
                            _configData.getAppThemeData(),
                            "Create File Failed",
                            ["Reason - ${success.message}", "No changes were made"],
                            ["Acknowledge"],
                            Path.empty(),
                            (path, button) {
                              setState(() {});
                            },
                            () {
                              _setFocus("createFile");
                            },
                          );
                        }
                      });
                    } else {
                      Future.delayed(const Duration(milliseconds: 1), () {
                        if (mounted) {
                          showModalButtonsDialog(context, _configData.getAppThemeData(), "Create File:", ["Make '$fn' your NEW file", "or", "Continue with EXISTING file"], ["NEW", "EXISTING"], Path.empty(), (path, button) {
                            setState(() {
                              if (button == "NEW") {
                                _configData.setValueForJsonPath(dataFileLocalNamePath, fn);
                                _configData.save(logger.log);
                                _configData.update(callOnUpdate: true);
                                _clearData("New Data File");
                              }
                            });
                          }, () {
                            _setFocus("createFile");
                          });
                        }
                      });
                    }
                  }
                  return "";
                },
                () {
                  _setFocus("createFile");
                },
              );
              break;
            }
          case ActionType.restart:
            if (_dataWasUpdated) {
              showModalButtonsDialog(context, _configData.getAppThemeData(), "Restart Alert", ["Restart - Discard changes", "Cancel - Don't Restart"], ["Restart", "Cancel"], Path.empty(), (p, sel) {
                if (sel == "RESTART") {
                  _clearDataState("Application RESTART");
                }
              }, () {
                _setFocus("restart");
              });
            } else {
              _clearDataState("Application RESTART");
            }
            break;
          case ActionType.reload:
            {
              if (_dataWasUpdated) {
                showModalButtonsDialog(context, _configData.getAppThemeData(), "Reload Alert", ["Reload - Discard changes", "Cancel - Don't Reload"], ["Reload", "Cancel"], Path.empty(), (p, sel) {
                  if (sel == "RELOAD") {
                    _loadDataState();
                  }
                }, () {
                  _setFocus("reload");
                });
              } else {
                _loadDataState();
              }
              break;
            }
          default:
            {
              debugPrint("UNHANDLED_ACTION '${detailActionData.toString()}'");
            }
        }
      }
    });
  }

  Path _handleAction(DetailAction detailActionData) {
    switch (detailActionData.action) {
      case ActionType.querySelect:
        {
          return _querySelect(detailActionData.path, detailActionData.additional);
        }
      case ActionType.clearTheme:
        {
          final resp = _configData.clearThemeForFile(_configData.getDataFileName());
          if (resp.isEmpty) {
            _globalSuccessState = SuccessState(true, message: "__CONFIG:__ Theme: ${_configData.getDataFileName()} removed", log: logger.log);
            _configData.save(logger.log);
          } else {
            _globalSuccessState = SuccessState(false, message: "__CONFIG:__ $resp", log: logger.log);
          }
          return Path.empty();
        }
      case ActionType.link:
        {
          _implementLinkStateAsync(detailActionData.oldValue, detailActionData.path.last);
          return Path.empty();
        }
      case ActionType.save: // Save as it is (encrypted or un-encrypted)
        {
          _saveDataStateAsync(_loadedData.dataToStringFormattedWithTs(_loadedData.password), _loadedData.password, true);
          return Path.empty();
        }
      case ActionType.checkReferences:
        {
          setState(() {
            _checkReferences = true;
          });
          break;
        }
      case ActionType.clearState:
        {
          setState(() {
            _applicationState.deleteAppStateConfigFile();
            _applicationState.clear(_configData.isDesktop());
          });
          break;
        }
      case ActionType.groupSelectAll:
        {
          setState(() {
            _selectedTreeNode.visitEachChildNode((sn) {
              _pathPropertiesList.setGroupSelect(sn.path, sn.isLeaf);
            });
          });
          break;
        }
      case ActionType.groupSelectClearAll:
        {
          setState(() {
            _pathPropertiesList.clearAllGroupSelect();
          });
          break;
        }
      case ActionType.flipSorted:
        {
          setState(() {
            _applicationState.flipDataSorted;
            _reloadTreeFromMapAndCopyFlags();
            _selectNode(_selectedPath);
          });
          break;
        }
      case ActionType.clip:
        {
          setState(() {
            _globalSuccessState = SuccessState(true, message: "Copied to clipboard");
          });
          break;
        }
      case ActionType.select:
        {
          setState(() {
            _selectNode(detailActionData.path);
          });
          break;
        }
      case ActionType.groupSelect:
        {
          setState(() {
            _pathPropertiesList.setGroupSelect(detailActionData.path, detailActionData.value);
          });
          break;
        }
      case ActionType.none:
        {
          break;
        }
      default:
        {
          _handleFutureAction(detailActionData, 250);
        }
    }
    return Path.empty();
  }

  Future<void> _saveDataStateAsync(final String content, final String pw, final bool saveToRemote) async {
    final newFileName = _configData.getDataFileNameForSaveAs(pw); // May change extension!
    final currentFileName = _configData.getDataFileName();
    final bool noClobber;
    if (newFileName != currentFileName) {
      noClobber = true;
      if (_configData.localFileExists(newFileName)) {
        _globalSuccessState = SuccessState(false, message: "File $newFileName already exists");
        return;
      }
    } else {
      noClobber = false;
    }
    final localSaveState = DataContainer.saveToFile(_configData.getDataFileNameForSaveAs(pw, fullPath: true), content, noClobber: noClobber, log: logger.log);
    int success = 0;
    final String lm;
    final String rm;
    if (localSaveState.isSuccess) {
      success++;
      lm = "Local Save OK";
    } else {
      lm = "Local Save FAIL";
    }
    if (saveToRemote) {
      final remoteSaveState = await DataContainer.sendHttpPost(_configData.getPostDataFileUrl(), content, log: logger.log);
      if (remoteSaveState.isSuccess) {
        success++;
        rm = "Remote Save OK";
      } else {
        rm = "Remote Save FAIL";
      }
    } else {
      rm = "";
    }
    setState(() {
      logger.log("__SAVE:__ $lm. $rm");
      if (success == 2) {
        _dataRequiresSyncing = false;
      }
      if (success != 0) {
        _dataWasUpdated = false;
        _pathPropertiesList.clear();
        _globalSuccessState = SuccessState(true, message: "$lm. $rm");
      } else {
        _globalSuccessState = SuccessState(false, message: "$lm. $rm");
      }
    });
  }

  void _loadDataState() async {
    FileDataPrefix fileDataPrefixRemote = FileDataPrefix.empty();
    FileDataPrefix fileDataPrefixLocal = FileDataPrefix.empty();
    FileDataPrefix fileDataPrefixFinal = FileDataPrefix.empty();

    //
    // Are we reloading the existing data? If yes is there existing data?
    //
    final String localPath;
    final String remotePath;
    final String fileName;
    final String pw;
    if (_loadedData.isEmpty) {
      pw = _initialPassword;
      localPath = _configData.getDataFileLocalPath();
      remotePath = _configData.getGetDataFileUrl();
      fileName = _configData.getDataFileName();
    } else {
      pw = _loadedData.password;
      localPath = _loadedData.localSourcePath;
      remotePath = _loadedData.remoteSourcePath;
      fileName = _loadedData.fileName;
    }
    //
    // Try to load the remote data.
    //
    final successReadRemote = await DataContainer.receiveHttpGet(remotePath, timeoutMillis: _configData.getDataFetchTimeoutMillis());
    if (successReadRemote.isSuccess) {
      fileDataPrefixRemote = FileDataPrefix.fromFileContent(successReadRemote.value.trim(), "Remote", log: logger.log);
    } else {
      fileDataPrefixRemote = FileDataPrefix.error("Remote load failed", log: logger.log);
    }

    //
    // Try to load the local data.
    // If the local data is later than remote data or remote load failed, use the local data.
    //
    final successReadLocal = DataContainer.loadFromFile(localPath);
    if (successReadLocal.isSuccess) {
      fileDataPrefixLocal = FileDataPrefix.fromFileContent(successReadLocal.value.trim(), "Local", log: logger.log);
    } else {
      fileDataPrefixLocal = FileDataPrefix.error("Local load failed", log: logger.log);
    }

    fileDataPrefixFinal = fileDataPrefixLocal.selectWithNoErrorOrLatest(fileDataPrefixRemote, log: logger.log);
    //
    // File is now loaded!
    //
    if (fileDataPrefixFinal.error) {
      setState(() {
        _globalSuccessState = SuccessState(false, message: "__LOAD__ Error: ${fileDataPrefixFinal.errorReason}", log: logger.log);
      });
      return;
    }

    if (fileDataPrefixFinal.encrypted && pw.isEmpty) {
      setState(() {
        _globalSuccessState = SuccessState(false, message: "__LOAD__ No Password Provided", log: logger.log);
      });
      return;
    }

    final DataContainer data;
    try {
      data = DataContainer(fileDataPrefixFinal.content, fileDataPrefixFinal, successReadRemote.path, successReadLocal.path, fileName, () {
        return _configData.canSaveAltFile();
      }, pw, log: logger.log);
    } catch (r) {
      setState(() {
        if (r is Exception) {
          _globalSuccessState = SuccessState(false, message: "__LOAD__ Data file could not be parsed", exception: r, log: logger.log);
        } else {
          if (pw.isEmpty) {
            _globalSuccessState = SuccessState(false, message: "__LOAD__ $r", log: logger.log);
          } else {
            _globalSuccessState = SuccessState(false, message: "__LOAD__ ${r.runtimeType.toString()}. Please try again!", log: logger.log);
          }
        }
      });
      return;
    }

    if (data.isEmpty) {
      setState(() {
        _globalSuccessState = SuccessState(false, message: "__LOAD__ Data file does not contain any data", log: logger.log);
      });
      return;
    }
    _loadedData = data;

    setState(() {
      _dataRequiresSyncing = fileDataPrefixLocal.isNotEqual(fileDataPrefixRemote);
      if (_dataRequiresSyncing) {
        logger.log("__FILE_DATA:__ Warning: Data requires synchronisation");
      }
      _dataWasUpdated = false;
      _checkReferences = true;
      _pathPropertiesList.clear();
      _treeNodeDataRoot = MyTreeNode.fromMap(_loadedData.dataMap, sorted: _applicationState.isDataSorted);
      _treeNodeDataRoot.setExpandedSubNodes(true);
      _treeNodeDataRoot.clearFilter();
      _filteredNodeDataRoot = MyTreeNode.empty();
      _selectedTreeNode = _treeNodeDataRoot.firstSelectableNode();
      _selectedPath = _selectedTreeNode.path;
      _globalSuccessState = SuccessState(true, message: "${fileDataPrefixFinal.encrypted ? "Encrypted" : ""} [${fileDataPrefixFinal.tag}] File: ${_loadedData.timeStampString}", log: logger.log);
    });
  }

  void _clearDataState(String reason) async {
    setState(() {
      _clearData(reason);
    });
  }

  void _clearData(String reason) async {
    _loadedData = DataContainer.empty();
    _isEditDataDisplay = false;
    _initialPassword = "";
    _search = "";
    _lastSearch = "";
    _dataWasUpdated = false;
    _dataRequiresSyncing = false;
    _pathPropertiesList.clear();
    _globalSuccessState = SuccessState(true, message: reason);
    _currentSelectedGroupsPrefix = "";
    logger.log("__DATA_CLEARED__ $reason");
  }

  void _reloadTreeFromMapAndCopyFlags() {
    final temp = MyTreeNode.fromMap(_loadedData.dataMap, sorted: _applicationState.isDataSorted);
    temp.visitEachSubNode((node) {
      final refNode = _treeNodeDataRoot.findByPath(node.path);
      if (refNode != null) {
        node.setRequired(refNode.isRequired);
        if (node.canExpand) {
          node.expanded = refNode.expanded;
        }
      }
    });
    _treeNodeDataRoot = temp;
  }

  void _handleAddState(final Path path, final String name, final OptionsTypeData type) async {
    setState(() {
      if (name.length < 2) {
        _globalSuccessState = SuccessState(false, message: "__ADD__ Name is too short", log: logger.log);
        return;
      }
      final mapNodes = path.pathNodes(_loadedData.dataMap);
      if (mapNodes.error) {
        _globalSuccessState = SuccessState(false, message: "__ADD__ Path not found", log: logger.log);
        return;
      }
      if (mapNodes.lastNodeIsData) {
        _globalSuccessState = SuccessState(false, message: "__ADD__ Cannot add to a data node", log: logger.log);
        return;
      }
      if (mapNodes.lastNodeAsMap!.containsKey(name)) {
        _globalSuccessState = SuccessState(false, message: "__ADD__ Name already exists", log: logger.log);
        return;
      }
      switch (type) {
        case optionTypeDataValue:
          mapNodes.lastNodeAsMap![name] = emptyString;
          _dataWasUpdated = true;
          _checkReferences = true;
          _pathPropertiesList.setUpdated(path, shouldLog: false);
          _pathPropertiesList.setRenamed(path.cloneAppend(name), shouldLog: false);
          _pathPropertiesList.setUpdated(path.cloneAppend(name), shouldLog: false);
          _reloadTreeFromMapAndCopyFlags();
          _selectNode(path);
          _globalSuccessState = SuccessState(true, message: "Data node '$name' added", log: logger.log);
          break;
        case optionTypeDataGroup:
          final Map<String, dynamic> m = {};
          mapNodes.lastNodeAsMap![name] = m;
          _dataWasUpdated = true;
          _checkReferences = true;
          _pathPropertiesList.setUpdated(path, shouldLog: false);
          _pathPropertiesList.setRenamed(path.cloneAppend(name), shouldLog: false);
          _pathPropertiesList.setUpdated(path.cloneAppend(name), shouldLog: false);
          _reloadTreeFromMapAndCopyFlags();
          _selectNode(path.cloneAppend(name));
          _globalSuccessState = SuccessState(true, message: "Group Node '$name' added", log: logger.log);
          break;
      }
    });
  }

  String _checkRenameOk(DetailAction detailActionData, String newNameNoSuffix, OptionsTypeData newType) {
    if (detailActionData.oldValueType != newType) {
      if (detailActionData.oldValueType == optionTypeDataMarkDown) {
        if (detailActionData.additional.contains('\n')) {
          return "Remove multiple lines";
        }
      }
    }
    if (newNameNoSuffix.length < 2) {
      return "New Name is too short";
    }
    if (newNameNoSuffix.contains(".")) {
      return "New Name Cannot contain '.'";
    }
    final newName = "$newNameNoSuffix${newType.nameSuffix}";
    if (detailActionData.oldValue != newName) {
      final mapNodes = detailActionData.path.pathNodes(_loadedData.dataMap);
      if (mapNodes.error) {
        return "Path not found";
      }
      if (mapNodes.alreadyContainsName(newName)) {
        return "Name already exists";
      }
    }
    return "";
  }

  void _handleRenameState(DetailAction detailActionData, String newNameNoSuffix, OptionsTypeData newType) {
    final newName = "$newNameNoSuffix${newType.nameSuffix}";
    final oldName = detailActionData.oldValue;
    if (oldName != newName) {
      setState(() {
        if (newNameNoSuffix.length < 2) {
          _globalSuccessState = SuccessState(false, message: "__RENAME__ New Name is too short");
          return;
        }
        final mapNodes = detailActionData.path.pathNodes(_loadedData.dataMap);
        if (mapNodes.error) {
          _globalSuccessState = SuccessState(false, message: "__RENAME__ Path not found");
          return;
        }
        if (!mapNodes.lastNodeHasParent) {
          _globalSuccessState = SuccessState(false, message: "__RENAME__ Cannot rename root node");
          return;
        }
        if (mapNodes.alreadyContainsName(newName)) {
          _globalSuccessState = SuccessState(false, message: "__RENAME__ Name already exists");
          return;
        }

        mapNodes.lastNodeParent!.remove(oldName);
        mapNodes.lastNodeParent![newName] = mapNodes.lastNodeAsData;

        _dataWasUpdated = true;
        _checkReferences = true;

        var newPath = detailActionData.path.cloneRename(newName);
        var parentPath = newPath.cloneParentPath();
        _pathPropertiesList.setRenamed(newPath);
        _pathPropertiesList.setRenamed(parentPath, shouldLog: false);
        _reloadTreeFromMapAndCopyFlags();
        _selectNode(parentPath);
        _globalSuccessState = SuccessState(true, message: "Node '$oldName' renamed $newName", log: logger.log);
      });
    }
  }

  Path _handleDelete(final Path path) {
    final mapNodes = path.pathNodes(_loadedData.dataMap);
    if (mapNodes.error) {
      _globalSuccessState = SuccessState(false, message: "__DELETE__ Path not found");
      return Path.empty();
    }
    if (!mapNodes.lastNodeHasParent) {
      _globalSuccessState = SuccessState(false, message: "__DELETE__ Cannot delete root node");
      return Path.empty();
    }
    final parentPath = path.cloneParentPath();
    if (parentPath.isEmpty) {
      _globalSuccessState = SuccessState(false, message: "__DELETE__ Parent path is empty");
      return parentPath;
    }
    final parentNode = mapNodes.lastNodeParent;
    parentNode!.remove(path.last);
    return parentPath;
  }

  void _handleDeleteState(final Path path, final String response) async {
    if (response == "OK") {
      setState(() {
        final parentPath = _handleDelete(path);
        if (parentPath.isEmpty) {
          return;
        }
        _dataWasUpdated = true;
        _checkReferences = true;
        _pathPropertiesList.setUpdated(parentPath);
        _reloadTreeFromMapAndCopyFlags();
        _selectNode(parentPath);
        _globalSuccessState = SuccessState(true, message: "Removed: '${path.last}'");
      });
    }
  }

  void _handleEditState(DetailAction detailActionData, String newValue, OptionsTypeData type) {
    if (detailActionData.oldValue != newValue || detailActionData.oldValueType != type) {
      setState(() {
        final mapNodes = detailActionData.path.pathNodes(_loadedData.dataMap);
        if (mapNodes.error) {
          _globalSuccessState = SuccessState(false, message: "__EDIT__ Path not found");
          return;
        }
        if (!mapNodes.lastNodeIsData) {
          _globalSuccessState = SuccessState(false, message: "__EDIT__ Cannot edit a map node");
          return;
        }
        if (!mapNodes.lastNodeHasParent) {
          _globalSuccessState = SuccessState(false, message: "__EDIT__ Cannot edit a root node");
          return;
        }
        final parentNode = mapNodes.lastNodeParent;
        final key = detailActionData.path.last;
        _dataWasUpdated = true;
        _checkReferences = true;
        final nvTrim = newValue.trim();
        try {
          if (type.dataValueType == bool) {
            final lvTrimLc = nvTrim.toLowerCase();
            parentNode![key] = (lvTrimLc == "true" || lvTrimLc == "yes" || nvTrim == "1");
          } else {
            if (type.dataValueType == double || type.dataValueType == int) {
              try {
                final iv = int.parse(nvTrim);
                parentNode![key] = iv;
              } catch (e) {
                try {
                  final dv = double.parse(nvTrim);
                  parentNode![key] = dv;
                } catch (e) {
                  parentNode![key] = nvTrim;
                }
              }
            } else {
              parentNode![key] = nvTrim;
            }
          }
          _pathPropertiesList.setUpdated(detailActionData.path);
          _pathPropertiesList.setUpdated(detailActionData.path.cloneParentPath(), shouldLog: false);
          _reloadTreeFromMapAndCopyFlags();
          _selectNode(detailActionData.path.cloneParentPath());
          _globalSuccessState = SuccessState(true, message: "Item ${detailActionData.getLastPathElement()} updated");
        } catch (e, s) {
          debugPrintStack(stackTrace: s);
        }
      });
    }
  }

  SuccessState handleOnResolve(String value) {
    final type = OptionsTypeData.staticFindOptionTypeFromNameAndType(null, value);
    if (type != optionTypeDataNotFound) {
      return SuccessState(false, message: "Cannot reference '${type.displayName}' data", value: value);
    }
    final p = Path.fromDotPath(value);
    if (p.isEmpty) {
      return SuccessState(false, message: "Invalid Path", value: value);
    }
    final n = _loadedData.getNodeFromJson(p);
    if (n == null) {
      return SuccessState(false, message: "Not Found", value: value);
    }
    if (n is Map) {
      return SuccessState(false, message: "Not Data Node", value: value);
    }
    if (_isEditDataDisplay) {
      return SuccessState(true, message: "", value: value);
    }
    if (n is bool) {
      return n ? SuccessState(true, message: "", value: "Yes") : SuccessState(true, message: "", value: "No");
    }
    return SuccessState(true, message: "", value: n.toString());
  }

  Future<bool> _handleShouldExit() async {
    if (_inExitProcess) {
      return false;
    }
    _inExitProcess = true;
    try {
      bool shouldExit = true;
      if (_dataWasUpdated) {
        await showModalButtonsDialog(
          context,
          _configData.getAppThemeData(),
          "Alert",
          ["Data has been updated", "Press SAVE keep changes", "Press CANCEL remain in the App", "Press EXIT to leave without saving"],
          ["SAVE", "CANCEL", "EXIT"],
          Path.empty(),
          (path, button) async {
            if (button == "SAVE") {
              await _saveDataStateAsync(_loadedData.dataToStringFormattedWithTs(_loadedData.password), _loadedData.password, true);
            }
            if (button == "CANCEL") {
              shouldExit = false;
              setState(() {
                _globalSuccessState = SuccessState(true, message: "Exit Cancelled");
              });
            }
          },
          () {
            _setFocus("Exit");
          },
        );
      }
      if (shouldExit) {
        _exitReturnCode = 0;
      }
      return shouldExit;
    } finally {
      _inExitProcess = false;
    }
  }

  SuccessState _checkSingleReference(Path path, dynamic node) {
    if (node is! String) {
      return SuccessState(false, message: "Must be a String node");
    }
    final value = node.toString();
    final ss = OptionsTypeData.staticFindOptionTypeFromNameAndType(null, value);
    if (ss.hasSuffix) {
      return SuccessState(false, message: "Cannot ref ${ss.displayName}");
    }
    final p = Path.fromDotPath(value);
    if (p.isEmpty) {
      return SuccessState(false, message: "Reference is required ${ss.displayName}");
    }
    final n = _loadedData.getNodeFromJson(p);
    if (n == null) {
      return SuccessState(false, message: "Item Not found");
    } else {
      if (n is Map || n is List) {
        return SuccessState(false, message: "Is not a value Item");
      }
    }

    // final ss = OptionsTypeData.staticFindOptionTypeFromNameAndType(null, path.last);
    // if (ss.hasSuffix) {
    //   return SuccessState(false,message:"Cannot ref to ${ss.displayName}");
    // } else {
    // }
    return SuccessState(true);
  }

  bool _matchSearchForFilter(String searchFor, bool tolowerCase, MyTreeNode searchThisNode) {
    if (tolowerCase) {
      return (searchThisNode.label.toLowerCase().contains(searchFor));
    }
    return (searchThisNode.label.contains(searchFor));
  }

  void _setFocus(String x) {
    if (!_isEditDataDisplay) {
      Future.delayed(
        const Duration(milliseconds: 500),
        () {
          if (!Navigator.of(context).canPop()) {
            // Only do this is an Alert Dialogue is NOT visible
            if (_loadedData.isEmpty) {
              _passwordFocusNode.requestFocus();
            } else {
              if (_configData.isDesktop()) {
                _searchFocusNode.requestFocus();
              }
            }
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _screenSize(context);

    if (_loadedData.isNotEmpty) {
      _configData.themeContext = _configData.getDataFileName();
    } else {
      _configData.themeContext = defaultThemeReplace;
    }

    final AppThemeData appThemeData = _configData.getAppThemeData();
    final screenForeground = appThemeData.screenForegroundColour(true);
    final appBackgroundColor = appThemeData.screenBackgroundColor;
    final appBackgroundErrorColor = appThemeData.screenBackgroundErrorColor;

    _configData.onUpdate = _onUpdateConfig;

    FlutterWindowClose.setWindowShouldCloseHandler(() async {
      await _handleShouldExit();
      return false;
    });

    if (_loadedData.isNotEmpty) {
      if (_search != _lastSearch || _filteredNodeDataRoot.isEmpty) {
        _lastSearch = _search;
        _filteredNodeDataRoot = _treeNodeDataRoot.applyFilter(_search, true, _matchSearchForFilter);
      } else {
        _filteredNodeDataRoot = _treeNodeDataRoot.clone(requiredOnly: true);
      }
    }

    if (_filteredNodeDataRoot.isEmpty) {
      _isEditDataDisplay = false;
    } else {
      if (_search.isNotEmpty) {
        _applicationState.addLastFind(_search, 10);
      }
    }

    if (_checkReferences) {
      int count = 0;
      _loadedData.visitEachSubNode((key, path, node) {
        if (key.endsWith(referenceExtension)) {
          final ss = _checkSingleReference(path, node);
          if (ss.isFail) {
            count++;
            logger.log("## __REF_ERROR__ ${path.asMarkdownLink} ${ss.message}");
          }
        }
      });
      if (count != 0 && _loadedData.warning.isEmpty) {
        _loadedData.warning = "__REF_ERROR__";
      }
      _checkReferences = false;
    }

    if (_loadedData.warning.isNotEmpty) {
      _loadedData.warning = "";
      _handleAction(DetailAction.actionOnly(ActionType.showLog));
    }

    // final remoteFileListButton = DetailIconButtonManager(
    //   iconData: Icons.cloud_download,
    //   tooltip: 'Choose Remote File',
    //   visible: false,
    //   appThemeData: appThemeData,
    //   onPressed: (button) async {
    //     // Load the file list from the server...
    //     final remoteFileList = await _configData.remoteDir(
    //       ["data", "json"],
    //       (failReason) {
    //         // Fail
    //         showModalButtonsDialog(
    //           context,
    //           _configData.getAppThemeData(),
    //           "Configuration Error",
    //           ["Element: '$getListDataUrlPath'", "Value: ${_configData.getListDataUrl()}", "", failReason],
    //           ["OK"],
    //           Path.empty(),
    //           (path, response) {},
    //           () {
    //             _setFocus("_configData.remoteDir");
    //           },
    //         );
    //       },
    //     );
    //     if (remoteFileList.isEmpty) {
    //       return;
    //     }
    //     Future.delayed(
    //       const Duration(microseconds: 200),
    //       () {
    //         showFilesListDialog(
    //           context,
    //           _configData.getAppThemeData(),
    //           remoteFileList,
    //           false,
    //           (fileName) {
    //             if (fileName != _configData.getDataFileName()) {
    //               _configData.setValueForJsonPath(dataFileLocalNamePath, fileName);
    //               _configData.update(callOnUpdate: true);
    //               logger.log("__CONFIG__ File name updated to:'$fileName'");
    //               _configData.save(logger.log);
    //             } else {
    //               logger.log("__CONFIG__ File name not updated. No change");
    //             }
    //             _initialPassword = _passwordEditingController.text;
    //             _passwordEditingController.text = "";
    //             _loadDataState();
    //           },
    //           (action) {
    //             if (action == SimpleButtonActions.ok) {
    //               _handleAction(DetailAction(ActionType.createFile, false, Path.empty()));
    //             }
    //           },
    //           () {
    //             _setFocus("showLocalFilesDialog");
    //           },
    //         );
    //       },
    //     );
    //   },
    // );
    // remoteFileListButton.setVisible(_remoteServerAvailable);

    final indicatorIconManager = IndicatorIconManager(
      const [Icons.access_time_filled, Icons.access_time],
      color: _configData.getAppThemeData().screenForegroundColour(true),
      period: 500,
      padding: const EdgeInsets.all(5),
      size: (_configData.appBarHeight / 3.5) * 2,
      onClick: (c, iii) {
        _handleAction(DetailAction.actionOnly(ActionType.showLog));
      },
      getState: (c, widget) {
        if ((c % 20) == 0 && c > 0 || c == 2) {
          DataContainer.testHttpGet(_configData.getRemoteTestFileUrl(), (response) {
            if (response.isEmpty) {
              logger.log("__REMOTE__ Test file loaded OK");
              widget.setVisible(false);
              if (!_remoteServerAvailable) {
                setState(()  {
                  _serverFileList = List.empty(growable: true);
                  _remoteServerAvailable = true;
                  _configData.remoteDir(fileExtensionDataList, (message) {
                    debugPrint("ERROR: $message");
                  },(file) {
                    _serverFileList.add(file);
                    debugPrint("ADD: $file");
                  },);
                });
              }
            } else {
              logger.log("__REMOTE__ $response");
              widget.setVisible(true);
              if (_remoteServerAvailable) {
                setState(() {
                  _serverFileList = List.empty();
                  _remoteServerAvailable = false;
                });
              }
            }
          }, prefix: "TestFile: '${_configData.getRemoteTestFileName}'  ");
        }
        return c + 1;
      },
    );

    final DisplaySplitView displayData = createSplitView(_loadedData, _filteredNodeDataRoot, _treeNodeDataRoot, _selectedTreeNode, _isEditDataDisplay, _configData.isDesktop(), _applicationState.screen.divPos, appThemeData, _pathPropertiesList, _selectNodeState, _expandNodeState, (value) {
      return handleOnResolve(value);
    }, (divPos) {
      // On divider change
      _applicationState.updateDividerPosState(divPos);
    }, (detailActionData) {
      // On selected detail page action
      return _handleAction(detailActionData);
    }, logger.log, _applicationState.isDataSorted, _configData.getRootNodeName(), _configData.getDataFileName(), _search);
    _treeViewScrollController = displayData.scrollController;

    final List<Widget> toolBarItems = List.empty(growable: true);
    toolBarItems.add(
      DetailIconButton(
        iconData: Icons.close,
        tooltip: 'Exit application',
        onPressed: (button) async {
          await _handleShouldExit();
        },
        appThemeData: appThemeData,
      ),
    );

    if (_loadedData.isEmpty) {
      _navBarHeight = 0;
      toolBarItems.add(Container(
        color: appThemeData.primary.med,
        child: inputTextField(
          appThemeData.tsLarge,
          _configData.getAppThemeData().textSelectionThemeData,
          _configData.getAppThemeData().darkMode,
          _passwordEditingController,
          focusNode: _passwordFocusNode,
          width: screenSize.width / 3,
          height: _configData.getAppThemeData().textInputFieldHeight,
          hint: "Password:",
          isPw: true,
          onChange: (v) {},
          onSubmit: (v) {
            _initialPassword = v;
            _passwordEditingController.text = "";
            _loadDataState();
          },
        ),
      ));

      toolBarItems.add(DetailIconButton(
        appThemeData: appThemeData,
        iconData: Icons.file_open,
        tooltip: 'Load Current File',
        onPressed: (button) {
          _initialPassword = _passwordEditingController.text;
          _passwordEditingController.text = "";
          _loadDataState();
        },
      ));

      // toolBarItems.add(DetailIconButton(
      //     appThemeData: appThemeData,
      //     iconData: Icons.rule_folder,
      //     tooltip: 'Choose Local File',
      //     onPressed: (button) {
      //       showFilesListDialog(
      //         context,
      //         _configData.getAppThemeData(),
      //         localFileList,
      //         true,
      //         (fileName) {
      //           // OnSelect
      //           if (fileName != _configData.getDataFileName()) {
      //             _configData.setValueForJsonPath(dataFileLocalNamePath, fileName);
      //             _configData.update(callOnUpdate: true);
      //             logger.log("__CONFIG__ File name updated to:'$fileName'");
      //             _configData.save(logger.log);
      //           } else {
      //             logger.log("__CONFIG__ File name not updated. No change");
      //           }
      //           _initialPassword = _passwordEditingController.text;
      //           _passwordEditingController.text = "";
      //           _loadDataState();
      //         },
      //         (action) {
      //           // Create Local File
      //           if (action == SimpleButtonActions.ok) {
      //             _handleAction(DetailAction(ActionType.createFile, false, Path.empty()));
      //           }
      //         },
      //         () {
      //           // On Close - Refocus to Search or Password fields
      //           _setFocus("showLocalFilesDialog");
      //         },
      //       );
      //     }));
      //     toolBarItems.add(remoteFileListButton.widget);
      toolBarItems.add(DetailIconButton(
        onPressed: (button) {
          _handleAction(DetailAction.actionOnly(ActionType.chooseFile));
        },
        iconData: _remoteServerAvailable ? Icons.cloud_download : Icons.rule_folder,
        tooltip: _remoteServerAvailable ? "Choose Remote and Local" : "Choose Local Only",
        appThemeData: appThemeData,
      ));
    } else {
      //
      // Data is loaded
      //
      _navBarHeight = _configData.appBarHeight;
      toolBarItems.add(DetailIconButton(
        appThemeData: appThemeData,
        iconData: _isEditDataDisplay ? Icons.search : Icons.edit,
        tooltip: _isEditDataDisplay ? 'Search Mode' : "Edit Mode",
        onPressed: (button) {
          setState(() {
            _isEditDataDisplay = !_isEditDataDisplay;
          });
        },
      ));
      if (_dataWasUpdated) {
        toolBarItems.add(DetailIconButton(
          appThemeData: appThemeData,
          iconData: Icons.save,
          tooltip: "Save",
          onPressed: (button) {
            _isEditDataDisplay = false;
            _handleAction(DetailAction(ActionType.save, false, Path.empty()));
          },
        ));
      }
      if (_dataRequiresSyncing && !_dataWasUpdated) {
        toolBarItems.add(DetailIconButton(
          appThemeData: appThemeData,
          iconData: Icons.sync,
          tooltip: "Synchronise data",
          onPressed: (button) {
            _handleAction(DetailAction(ActionType.save, false, Path.empty()));
          },
        ));
      }
      if (_isEditDataDisplay) {
        toolBarItems.add(VerticalDivider(
          color: screenForeground,
        ));
        toolBarItems.add(DetailIconButton(
          onPressed: (button) {
            _handleAction(DetailAction(ActionType.groupSelectAll, false, _selectedPath));
          },
          tooltip: "Invert Selection",
          iconData: Icons.select_all,
          appThemeData: appThemeData,
        ));
        final canPaste = _pathPropertiesList.hasGroupSelects;
        if (canPaste) {
          toolBarItems.add(DetailIconButton(
            onPressed: (button) {
              _handleAction(DetailAction(ActionType.groupSelectClearAll, false, _selectedPath));
            },
            tooltip: "Clear ALL Selected",
            iconData: Icons.deselect,
            appThemeData: appThemeData,
          ));
          toolBarItems.add(DetailIconButton(
            onPressed: (button) {
              _handleAction(DetailAction(ActionType.groupCopy, false, _selectedPath));
            },
            tooltip: "Copy to ${_selectedPath.last}",
            iconData: Icons.file_copy,
            appThemeData: appThemeData,
          ));
          toolBarItems.add(DetailIconButton(
            onPressed: (button) {
              _handleAction(DetailAction(ActionType.groupDelete, false, _selectedPath));
            },
            tooltip: "Delete Data",
            iconData: Icons.delete,
            appThemeData: appThemeData,
          ));
        }
      } else {
        toolBarItems.add(
          Container(
            color: appThemeData.primary.med,
            child: inputTextField(
              appThemeData.tsMedium,
              _configData.getAppThemeData().textSelectionThemeData,
              _configData.getAppThemeData().darkMode,
              _searchEditingController,
              focusNode: _searchFocusNode,
              width: screenSize.width / 3,
              height: _configData.getAppThemeData().textInputFieldHeight,
              hint: "Search:",
              onChange: (v) {},
              onSubmit: (v) {
                _setSearchExpressionState(v);
              },
            ),
          ),
        );
        toolBarItems.add(
          DetailIconButton(
            appThemeData: appThemeData,
            iconData: Icons.search,
            tooltip: 'Search',
            onPressed: (button) {
              _setSearchExpressionState(_searchEditingController.text);
            },
          ),
        );
        toolBarItems.add(
          DetailIconButton(
            appThemeData: appThemeData,
            iconData: Icons.manage_search,
            tooltip: 'Previous Searches',
            onPressed: (button) async {
              await showSearchDialog(
                context,
                _configData.getAppThemeData(),
                _applicationState.getLastFindList(),
                (selected) {
                  if (selected.isNotEmpty) {
                    _setSearchExpressionState(selected);
                  }
                },
                () {
                  _setFocus("Search");
                },
              );
            },
          ),
        );
        toolBarItems.add(
          DetailIconButton(
            appThemeData: appThemeData,
            iconData: Icons.search_off,
            tooltip: 'Clear Search',
            onPressed: (button) {
              _setSearchExpressionState("");
            },
          ),
        );
      }
    }

    _setFocus("Build");
    final positionedTopFixed = _configData.appBarIconTop;
    final positionedLeft = screenSize.width - (_configData.iconSize + _configData.iconGap);

    final settings = _loadedData.isNotEmpty
        ? const SizedBox(width: 0)
        : Positioned(
            left: positionedLeft,
            top: positionedTopFixed,
            child: DetailIconButton(
              iconData: Icons.settings,
              tooltip: 'Settings',
              onPressed: (button) {
                _handleAction(DetailAction.actionOnly(ActionType.settings));
              },
              appThemeData: appThemeData,
            ));

    final showMenu = _loadedData.isEmpty
        ? const SizedBox(width: 0)
        : Positioned(
            left: positionedLeft,
            top: positionedTopFixed,
            child: DetailIconButton(
              iconData: Icons.menu,
              appThemeData: appThemeData,
              onPressed: (button) {
                showOptionsDialog(
                  context,
                  _configData.getAppThemeData(),
                  _selectedPath,
                  [
                    MenuOptionDetails("Done", "", ActionType.none, () {
                      return Icons.arrow_back;
                    }),
                    MenuOptionDetails("Add NEW Group", "Add a new group to '%{3}'", ActionType.addGroup, enabled: _isEditDataDisplay, () {
                      return Icons.add_box_outlined;
                    }),
                    MenuOptionDetails("Add NEW Detail", "Add a new detail to group '%{3}'", ActionType.addDetail, enabled: _isEditDataDisplay, () {
                      return Icons.add;
                    }),
                    MenuOptionDetails("Clear Select", "Clear ALL selected", ActionType.groupSelectClearAll, enabled: _isEditDataDisplay, () {
                      return Icons.deselect;
                    }),
                    MenuOptionDetails("Validate references", "Check validity of reference elements", ActionType.checkReferences, enabled: _isEditDataDisplay, () {
                      return Icons.check_circle_outline;
                    }),
                    MenuOptionDetails.separator(appThemeData.hiLight.med, enabled: _isEditDataDisplay),
                    MenuOptionDetails("Sync Data", "Save '%{4}' to Local and Remote Storage %{0}", ActionType.save, () {
                      return Icons.lock_open;
                    }),
                    MenuOptionDetails("Save %{1}", "Save '%{5}' to Local Storage only %{1}", ActionType.saveAlt, () {
                      return _loadedData.hasPassword ? Icons.lock_open : Icons.lock;
                    }, enabled: _loadedData.canSaveAltFile()),
                    MenuOptionDetails("Create data file", "Create a new data file", ActionType.createFile, () {
                      return _dataWasUpdated ? Icons.disabled_by_default_outlined : Icons.post_add;
                    }, enabled: !_dataWasUpdated),
                    MenuOptionDetails("Reload data file", "Reload %{4}", ActionType.reload, () {
                      return Icons.refresh;
                    }),
                    MenuOptionDetails.separator(appThemeData.hiLight.med),
                    MenuOptionDetails("About", "App Information", ActionType.about, () {
                      return Icons.info_outline;
                    }),
                    MenuOptionDetails("Settings", "Configure the app", ActionType.settings, () {
                      return Icons.settings;
                    }),
                    MenuOptionDetails.separator(appThemeData.error.med),
                    MenuOptionDetails("Reset Saved State", "Clears Previous searches etc.", ActionType.clearState, () {
                      return Icons.cleaning_services;
                    }),
                    MenuOptionDetails("Clear theme ", "Clears theme for file: ${_configData.getDataFileName()}.", ActionType.clearTheme, () {
                      return Icons.delete_sweep_outlined;
                    }),
                    MenuOptionDetails("Restart application", "Restart this application", ActionType.restart, () {
                      return Icons.restart_alt;
                    }),
                  ],
                  [
                    _loadedData.hasPassword ? 'ENCRYPTED' : 'UN-ENCRYPTED',
                    _loadedData.hasPassword ? 'UN-ENCRYPTED' : 'ENCRYPTED',
                    "",
                    _selectedPath.last,
                    _loadedData.fileName,
                    _configData.getDataFileNameAlt(),
                  ],
                  (selectedAction, path) {
                    _handleAction(DetailAction(selectedAction, true, path));
                  },
                  () {
                    _setFocus("Options");
                  },
                );
              },
            ),
          );

    // _currentSelectedGroupsPrefix is displayed in the status area if 1 or more groups are selected
    final newCount = _pathPropertiesList.countGroupSelects;
    if (newCount > 0) {
      _currentSelectedGroupsPrefix = "SEL[$newCount]: ";
    } else {
      _currentSelectedGroupsPrefix = "";
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
          maintainBottomViewPadding: true,
          child: SingleChildScrollView(
              child: Stack(
            children: [
              Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  // Center is a layout widget. It takes a single child and positions it
                  // in the middle of the parent.
                  children: [
                    Container(
                      height: _configData.appBarHeight,
                      color: appBackgroundColor,
                      child: Row(children: toolBarItems),
                    ),
                    _configData.getAppThemeData().horizontalLine,
                    _loadedData.isEmpty
                        ? const SizedBox(height: 0)
                        : _filteredNodeDataRoot.isEmpty
                            ? const SizedBox(height: 0)
                            : Container(
                                height: _navBarHeight,
                                color: appBackgroundColor,
                                child: createNodeNavButtonBar(_selectedPath, appThemeData, _isEditDataDisplay, _loadedData.isEmpty, _applicationState.isDataSorted, (detailActionData) {
                                  return _handleAction(detailActionData);
                                }),
                              ),
                    _loadedData.isEmpty ? const SizedBox(height: 0) : _configData.getAppThemeData().horizontalLine,
                    Container(
                      height: screenSize.height - (_configData.appBarHeight + _configData.appBarHeight + _navBarHeight),
                      color: appBackgroundColor,
                      child: displayData.splitView,
                    ),
                    _configData.getAppThemeData().horizontalLine,
                    Container(
                      height: _configData.appBarHeight,
                      color: _globalSuccessState.isSuccess ? appBackgroundColor : appBackgroundErrorColor,
                      child: Row(
                        children: [
                          indicatorIconManager.widget,
                          DetailIconButton(
                            appThemeData: appThemeData,
                            iconData: Icons.view_timeline,
                            tooltip: 'Log',
                            onPressed: (button) {
                              _handleAction(DetailAction.actionOnly(ActionType.showLog));
                            },
                          ),
                          Text(
                            _globalSuccessState.toStatusString(_currentSelectedGroupsPrefix),
                            style: appThemeData.tsMedium,
                          )
                        ],
                      ),
                    ),
                  ]),
              settings,
              showMenu,
            ],
          ))),
    );
  }
}
