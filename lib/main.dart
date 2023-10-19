import 'dart:async';
import 'dart:io';
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

final logger = Logger(50, true);

bool _inExitProcess = false;

void closer(final int returnCode) async {
  exit(returnCode);
}

ScreenSize screenSize = ScreenSize();

_screenSize(BuildContext context) {
  final pt = MediaQuery.of(context).padding.top;
  final bi = MediaQuery.of(context).viewInsets.bottom - MediaQuery.of(context).viewInsets.top;
  final height = MediaQuery.of(context).size.height - (bi + pt) - 2;
  final width = MediaQuery.of(context).size.width;
  screenSize.update(width, height);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final applicationDefaultDir = await ApplicationState.getApplicationDefaultDir();
    final isDesktop = ApplicationState.appIsDesktop();

    _configData = ConfigData(applicationDefaultDir, defaultConfigFileName, isDesktop, logger.log);
    _applicationState = ApplicationState.readAppStateConfigFile(_configData.getAppStateFileLocal(), logger.log);
    if (isDesktop) {
      setWindowTitle("${_configData.getTitle()}: ${_configData.getDataFileName()}");
      const WindowOptions(
        minimumSize: Size(200, 200),
        titleBarStyle: TitleBarStyle.normal,
      );
      setWindowFrame(Rect.fromLTWH(_applicationState.screen.x.toDouble(), _applicationState.screen.y.toDouble(), _applicationState.screen.w.toDouble(), _applicationState.screen.h.toDouble()));
    }
  } catch (e) {
    debugPrint(e.toString());
    closer(1);
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget with WindowListener {
  MyApp({super.key});

  @override
  onWindowEvent(final String eventName) async {
    switch (eventName) {
      case 'close':
        {
          return;
        }
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
          if (_configData.isDesktop()) {
            final info = await getWindowInfo();
            _applicationState.updateScreenPos(info.frame.left, info.frame.top, info.frame.width, info.frame.height);
          }

          break;
        }
      default:
        {
          debugPrint("Unhandled Window Event:$eventName");
        }
    }
    super.onWindowEvent(eventName);
  }

  @override
  Widget build(final BuildContext context) {
    if (_configData.isDesktop()) {
      windowManager.addListener(this);
    }

    return MaterialApp(
      title: 'data_repo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MyHomePage(
        title: _configData.getTitle(),
      ),
    );
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
  String _initialPassword = "";
  String _search = "";
  String _lastSearch = "";
  bool _dataWasUpdated = false;
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
  int _currentSelectedGroups = 0;
  String _currentSelectedGroupsPrefix = "";

  final PathPropertiesList _pathPropertiesList = PathPropertiesList(log: logger.log);
  final TextEditingController searchEditingController = TextEditingController(text: "");
  final TextEditingController passwordEditingController = TextEditingController(text: "");

  Path querySelect(Path sel, String dir) {
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

  Future<void> _implementLinkState(final String href, final String from) async {
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

  void selectNode({final Path? path}) {
    if (path != null) {
      final n = _treeNodeDataRoot.findByPath(path);
      if (n == null) {
        _selectedTreeNode = _treeNodeDataRoot.firstSelectableNode();
        logger.log("__ERROR__ Selected node [$path] was not found");
      } else {
        if (n.isLeaf) {
          final pp = path.cloneParentPath();
          final n = _treeNodeDataRoot.findByPath(pp);
          if (n == null) {
            _selectedTreeNode = _treeNodeDataRoot.firstSelectableNode();
            logger.log("__ERROR__ Selected node [$path] was a data node");
          } else {
            if (n.isNotRequired) {
              n.setRequired(true, recursive: true);
            }
            _selectedTreeNode = n;
          }
        } else {
          if (n.isNotRequired) {
            n.setRequired(true, recursive: true);
          }
          _selectedTreeNode = n;
        }
      }
    }
    _selectedPath = _selectedTreeNode.path;
    _selectedTreeNode.expandParent(true);

    Future.delayed(
      const Duration(milliseconds: 300),
      () {
        int tni = _selectedTreeNode.index - 3;
        if (tni < 0) {
          tni = 0;
        }
        final index = tni * (_configData.getAppThemeData().treeNodeHeight + 1);
        _treeViewScrollController.animateTo(index, duration: const Duration(milliseconds: 400), curve: Curves.ease);
      },
    );
  }

  void _onUpdateConfig() {
    setState(() {
      if (_loadedData.isEmpty) {
        setWindowTitle("${_configData.getTitle()}: ${_configData.getDataFileName()}");
      } else {
        setWindowTitle("${_configData.getTitle()}: ${_loadedData.fileName}");
      }
      if (_loadedData.isNotEmpty && (_configData.getDataFileLocal() != _loadedData.localSourcePath || _configData.getGetDataFileUrl() != _loadedData.remoteSourcePath)) {
        Future.delayed(
          const Duration(milliseconds: 300),
          () {
            logger.log("__WARNING__ Data source has changed");
            showModalButtonsDialog(context, _configData.getAppThemeData(), "Data source has Changed", ["If you CONTINUE:", "Saving and Reloading", "will use OLD config data", "and UNSAVED config", "changes may be lost."], ["RESTART", "CONTINUE"], Path.empty(), (path, button) {
              if (button == "RESTART") {
                setState(() {
                  _clearData("Config updated - RESTART");
                  logger.log("__RESTART__ Local file ${_configData.getDataFileLocal()}");
                  logger.log("__RESTART__ Remote file ${_configData.getGetDataFileUrl()}");
                  setWindowTitle("${_configData.getTitle()}: ${_configData.getDataFileName()}");
                });
              } else {
                logger.log("__CONFIG__ CONTINUE option chosen");
              }
            });
          },
        );
      }
    });
  }

  void _selectNodeState(final Path path) {
    setState(() {
      selectNode(path: path);
    });
  }

  void _expandNodeState(final Path path) {
    setState(() {
      final n = _treeNodeDataRoot.findByPath(path);
      if (n != null) {
        n.expanded = !n.expanded;
        selectNode(path: path);
      }
    });
  }

  void _setSearchExpressionState(final String st) {
    if (st == _search) {
      return;
    }
    _lastSearch = "[$_search]"; // Need search and _lastSearch to be different so filter is applied
    if (st.isEmpty) {
      logger.log("__SEARCH__ cleared");
      selectNode();
    }
    setState(() {
      searchEditingController.text = st;
      _search = st;
    });
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

  Path _handleAction(DetailAction detailActionData) {
    switch (detailActionData.action) {
      case ActionType.showLog:
        {
          Timer(const Duration(milliseconds: 500), () {
            showLogDialog(context, _configData.getAppThemeData(), screenSize, logger, (dotPath) {
              final p = Path.fromDotPath(dotPath);
              if (p.isRational(_loadedData.dataMap)) {
                _handleAction(DetailAction(ActionType.select, true, p.cloneParentPath()));
                return true;
              }
              return false;
            });
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
            _reloadAndCopyFlags();
            selectNode();
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
      case ActionType.groupCopy:
      case ActionType.groupDelete:
        {
          if (_pathPropertiesList.hasGroupSelects) {
            Timer(const Duration(milliseconds: 500), () {
              if (mounted) {
                final groupCopy = detailActionData.action == ActionType.groupCopy;
                showCopyMoveDialog(
                  context,
                  _configData.getAppThemeData(),
                  _selectedPath,
                  _summariseGroupSelection(_pathPropertiesList, groupCopy),
                  groupCopy,
                  (action, intoPath) {
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
                              _pathPropertiesList.setRenamed(intoPath.cloneAppendList([Path.fromDotPath(k).last]));
                              _pathPropertiesList.setRenamed(intoPath);
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

                        _reloadAndCopyFlags();
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
                    if (action == SimpleButtonActions.select) {
                      _selectNodeState(intoPath);
                    }
                  },
                );
              }
            });
          }
          break;
        }
      case ActionType.removeItem:
        {
          showModalButtonsDialog(context, _configData.getAppThemeData(), "Remove item", ["${detailActionData.valueName} '${detailActionData.getLastPathElement()}'"], ["OK", "Cancel"], detailActionData.path, _handleDeleteState);
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
          _selectNodeState(detailActionData.path);
          selectNode();
          break;
        }
      case ActionType.querySelect:
        {
          return querySelect(detailActionData.path, detailActionData.additional);
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
            optionGroupUpdateElement,
            detailActionData.oldValueType,
            false,
            false,
            (action, text, type) {
              if (action == SimpleButtonActions.ok) {
                _handleEditState(detailActionData, text, type);
              } else {
                if (action == SimpleButtonActions.link) {
                  _implementLinkState(text, detailActionData.path.last);
                }
              }
            },
            (initialTrimmed, valueTrimmed, initialType, valueType) {
              //
              // Validate a value type for Edit function
              //
              if (valueType.elementType == bool) {
                final valueTrimmedLc = valueTrimmed.toLowerCase();
                if (valueTrimmedLc == "yes" || valueTrimmedLc == "no" || valueTrimmedLc == "true" || valueTrimmedLc == "false") {
                  return "";
                } else {
                  return "Must be 'Yes' or 'No";
                }
              }
              if (valueType.elementType == String) {
                if (valueTrimmed == initialTrimmed && initialTrimmed != "") {
                  return "";
                }
                final m = valueType.inRangeInt("Length", valueTrimmed.length);
                if (m.isNotEmpty) {
                  return m;
                }
                return "";
              }
              if (valueType.elementType == double) {
                try {
                  final d = double.parse(valueTrimmed);
                  return valueType.inRangeDouble("Value ", d);
                } catch (e) {
                  return "That is not a ${valueType.description}";
                }
              }
              if (valueType.elementType == int) {
                try {
                  final i = int.parse(valueTrimmed);
                  return valueType.inRangeInt("Value ", i);
                } catch (e) {
                  return "That is not a ${valueType.description}";
                }
              }
              return "";
            },
          );
          break;
        }
      case ActionType.link:
        {
          _implementLinkState(detailActionData.oldValue, detailActionData.path.last);
          break;
        }
      case ActionType.addGroup:
        {
          Timer(const Duration(milliseconds: 1), () {
            if (mounted) {
              showModalInputDialog(context, _configData.getAppThemeData(), screenSize, "New Group Name", "", [], optionsDataTypeEmpty, false, false, (action, text, type) {
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
              });
            }
          });
          break;
        }
      case ActionType.addDetail:
        {
          Timer(const Duration(milliseconds: 1), () {
            if (mounted) {
              showModalInputDialog(context, _configData.getAppThemeData(), screenSize, "New Detail Name", "", [], optionsDataTypeEmpty, false, false, (action, text, type) {
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
              });
            }
          });
          break;
        }
      case ActionType.createFile:
        {
          Timer(const Duration(milliseconds: 1), () {
            if (mounted) {
              showFileNamePasswordDialog(context, _configData.getAppThemeData(), "New File", [
                "Password if encryption is required:",
                "Enter a valid file name:",
                "File extension is added automatically.",
                "Un-Encrypted extension = .json",
                "Encrypted extension = .data",
              ], (action, fileName, password) {
                final fn = password.isEmpty ? "$fileName.json" : "$fileName.data";
                if (fn.toLowerCase() == defaultConfigFileName.toLowerCase()) {
                  return "Cannot use '$fileName'";
                }
                if (fn.toLowerCase() == _configData.getAppStateFileName().toLowerCase()) {
                  return "Cannot use '$fileName'";
                }
                if (_configData.localFileExists(fn).isNotEmpty) {
                  return "${password.isNotEmpty ? "Encrypted" : ""} file '$fn' Exists";
                }
                if (action == SimpleButtonActions.ok) {
                  final content = DataContainer.staticDataToStringFormattedWithTs(_configData.getMinimumDataContentMap(), password, addTimeStamp: true, isNew: true);
                  final success = DataContainer.saveToFile(_configData.getDataFileLocalAlt(fn), content);
                  _globalSuccessState = success;
                  if (success.isFail) {
                    logger.log("__CREATE__ Failed. ${success.message}");
                    Timer(const Duration(milliseconds: 1), () {
                      if (mounted) {
                        showModalButtonsDialog(context, _configData.getAppThemeData(), "Create File Failed", ["Reason - ${success.message}", "No changes were made"], ["Acknowledge"], Path.empty(), (path, button) {
                          setState(() {});
                        });
                      }
                    });
                  } else {
                    Timer(const Duration(milliseconds: 1), () {
                      if (mounted) {
                        showModalButtonsDialog(context, _configData.getAppThemeData(), "Create File:", ["Make this your NEW file", "or", "Continue with EXISTING file"], ["NEW", "EXISTING"], Path.empty(), (path, button) {
                          setState(() {
                            if (button == "NEW") {
                              _configData.setValueForJsonPath(dataFileLocalNamePath, fn);
                              _configData.save(logger.log);
                              _configData.update(callOnUpdate: true);
                              _clearData("New Data File");
                            }
                          });
                        });
                      }
                    });
                  }
                }
                return "";
              });
            }
          });
          break;
        }
      case ActionType.restart:
        if (_dataWasUpdated) {
          Timer(const Duration(milliseconds: 1), () {
            if (mounted) {
              showModalButtonsDialog(context, _configData.getAppThemeData(), "Restart Alert", ["Restart - Discard changes", "Cancel - Don't Restart"], ["Restart", "Cancel"], Path.empty(), (p, sel) {
                if (sel == "RESTART") {
                  _clearDataState("Application RESTART");
                }
              });
            }
          });
        } else {
          _clearDataState("Application RESTART");
        }
        break;
      case ActionType.reload:
        {
          if (_dataWasUpdated) {
            Timer(const Duration(milliseconds: 1), () {
              if (mounted) {
                showModalButtonsDialog(context, _configData.getAppThemeData(), "Reload Alert", ["Reload - Discard changes", "Cancel - Don't Reload"], ["Reload", "Cancel"], Path.empty(), (p, sel) {
                  if (sel == "RELOAD") {
                    _loadDataState();
                  }
                });
              }
            });
          } else {
            _loadDataState();
          }
          break;
        }
      case ActionType.save:
        {
          _saveDataState(_loadedData.dataToStringFormattedWithTs(_loadedData.password));
          break;
        }
      case ActionType.saveAlt:
        {
          Timer(const Duration(milliseconds: 1), () {
            if (mounted) {
              showModalInputDialog(context, _configData.getAppThemeData(), screenSize, _loadedData.hasPassword ? "Confirm Password" : "New Password", "", [], optionsDataTypeEmpty, false, true, (button, pw, type) {
                if (button == SimpleButtonActions.ok) {
                  if (_loadedData.hasPassword) {
                    // Confirm PW (Save un-encrypted)
                    logger.log("__SAVE__ Data as plain text");
                    _loadedData.password = "";
                  } else {
                    // New password (Save encrypted)
                    logger.log("__SAVE__ Data as ENCRYPTED text");
                    _loadedData.password = pw;
                  }
                  _saveDataState(_loadedData.dataToStringFormattedWithTs(_loadedData.password));
                }
              }, (initial, value, initialType, valueType) {
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
              });
            }
          });
          break;
        }
      case ActionType.none:
        {
          break;
        }
    }
    return Path.empty();
  }

  Future<void> _saveDataState(final String content) async {
    final localSaveState = DataContainer.saveToFile(_configData.getDataFileLocal(), content);
    int success = 0;
    final String lm;
    final String rm;
    if (localSaveState.isSuccess) {
      success++;
      lm = "Local Save OK";
    } else {
      lm = "Local Save FAIL";
    }
    final remoteSaveState = await DataContainer.toHttpPost(_configData.getPostDataFileUrl(), content, log: logger.log);
    if (remoteSaveState.isSuccess) {
      success++;
      rm = "Remote Save OK";
    } else {
      rm = "Remote Save FAIL";
    }
    setState(() {
      logger.log("__SAVE:__ $lm. $rm");
      if (success > 0) {
        _dataWasUpdated = false;
        _pathPropertiesList.clear();
        _globalSuccessState = SuccessState(true, message: "$lm. $rm");
      } else {
        _globalSuccessState = SuccessState(false, message: "$lm. $rm");
      }
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
    _pathPropertiesList.clear();
    _globalSuccessState = SuccessState(true, message: reason);
    _currentSelectedGroupsPrefix = "";
    _currentSelectedGroups = 0;
    logger.log("__DATA_CLEARED__ $reason");
  }

  void _loadDataState() async {
    FileDataPrefix fileDataPrefixRemote = FileDataPrefix.empty();
    FileDataPrefix fileDataPrefix = FileDataPrefix.empty();
    String fileDataContent = "";
    String source = "Local";
    //
    // Are we reloading the existing data? If yes is there existing data?
    //
    final String localPath;
    final String remotePath;
    final String fileName;
    final String pw;
    if (_loadedData.isEmpty) {
      pw = _initialPassword;
      localPath = _configData.getDataFileLocal();
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
    final successStateRemote = await DataContainer.fromHttpGet(remotePath, timeoutMillis: _configData.getDataFetchTimeoutMillis());
    if (successStateRemote.isSuccess) {
      fileDataPrefixRemote = FileDataPrefix.fromString(successStateRemote.value);
      fileDataContent = successStateRemote.value.substring(fileDataPrefixRemote.startPos);
      fileDataPrefix = fileDataPrefixRemote;
      source = "Remote";
      logger.log("__INFO:__ $source __TS:__ ${fileDataPrefix.timeStamp}");
    } else {
      logger.log(successStateRemote.toLogString());
    }

    //
    // Try to load the local data.
    // If the local data is later than remote data or remote load failed, use the local data.
    //
    final successStateLocal = DataContainer.loadFromFile(localPath);
    if (successStateLocal.isSuccess) {
      final fileDataPrefixLocal = FileDataPrefix.fromString(successStateLocal.value);
      if (successStateRemote.isFail || fileDataPrefixLocal.isLaterThan(fileDataPrefixRemote)) {
        fileDataContent = successStateLocal.value.substring(fileDataPrefixLocal.startPos);
        fileDataPrefix = fileDataPrefixLocal;
        source = "Local";
        logger.log("__INFO:__ $source __TS:__ ${fileDataPrefix.timeStamp}");
      }
    } else {
      logger.log(successStateLocal.toLogString());
    }
    //
    // File is now loaded!
    //
    if (fileDataContent.isEmpty) {
      setState(() {
        _globalSuccessState = SuccessState(false, message: "__LOAD__ No Data Available", log: logger.log);
      });
      return;
    }

    if (fileDataPrefix.encrypted && pw.isEmpty) {
      setState(() {
        _globalSuccessState = SuccessState(false, message: "__LOAD__ No Password Provided", log: logger.log);
      });
      return;
    }

    final DataContainer data;
    try {
      data = DataContainer(fileDataContent, fileDataPrefix, successStateRemote.path, successStateLocal.path, fileName, pw, log: logger.log);
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
      _dataWasUpdated = false;
      _checkReferences = true;
      _pathPropertiesList.clear();
      _treeNodeDataRoot = MyTreeNode.fromMap(_loadedData.dataMap, sorted: _applicationState.isDataSorted);
      _treeNodeDataRoot.expandAll(true);
      _treeNodeDataRoot.clearFilter();
      _filteredNodeDataRoot = MyTreeNode.empty();
      _selectedTreeNode = _treeNodeDataRoot.firstSelectableNode();
      _selectedPath = _selectedTreeNode.path;
      _globalSuccessState = SuccessState(true, message: "${fileDataPrefix.encrypted ? "Encrypted" : ""} [$source] File: ${_loadedData.timeStampString}", log: logger.log);
    });
  }

  void _reloadAndCopyFlags() {
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
    if (name.length < 2) {
      _globalSuccessState = SuccessState(false, message: "__ADD__ Name is too short");
      return;
    }
    final mapNodes = path.pathNodes(_loadedData.dataMap);
    if (mapNodes.error) {
      _globalSuccessState = SuccessState(false, message: "__ADD__ Path not found");
      return;
    }
    if (mapNodes.lastNodeIsData) {
      _globalSuccessState = SuccessState(false, message: "__ADD__ Cannot add to a data node");
      return;
    }
    if (mapNodes.lastNodeAsMap!.containsKey(name)) {
      _globalSuccessState = SuccessState(false, message: "__ADD__ Name already exists");
      return;
    }
    switch (type) {
      case optionTypeDataValue:
        setState(() {
          mapNodes.lastNodeAsMap![name] = emptyString;
          _dataWasUpdated = true;
          _checkReferences = true;
          _pathPropertiesList.setUpdated(path);
          _pathPropertiesList.setRenamed(path.cloneAppendList([name]));
          _pathPropertiesList.setUpdated(path.cloneAppendList([name]));
          _reloadAndCopyFlags();
          selectNode(path: path);
          _globalSuccessState = SuccessState(true, message: "Data node '$name' added", log: logger.log);
        });
        break;
      case optionTypeDataGroup:
        setState(() {
          final Map<String, dynamic> m = {};
          mapNodes.lastNodeAsMap![name] = m;
          _dataWasUpdated = true;
          _checkReferences = true;
          _pathPropertiesList.setUpdated(path);
          _pathPropertiesList.setRenamed(path.cloneAppendList([name]));
          _pathPropertiesList.setUpdated(path.cloneAppendList([name]));
          _reloadAndCopyFlags();
          selectNode(path: path);
          _globalSuccessState = SuccessState(true, message: "Group Node '$name' added", log: logger.log);
        });
        break;
    }
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
    final newName = "$newNameNoSuffix${newType.suffix}";
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
    final newName = "$newNameNoSuffix${newType.suffix}";
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
        _pathPropertiesList.setRenamed(parentPath);
        _reloadAndCopyFlags();
        selectNode(path: parentPath);
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
        _reloadAndCopyFlags();
        selectNode(path: parentPath);
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
          if (type.elementType == bool) {
            final lvTrimLc = nvTrim.toLowerCase();
            parentNode![key] = (lvTrimLc == "true" || lvTrimLc == "yes" || nvTrim == "1");
          } else {
            if (type.elementType == double || type.elementType == int) {
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
          _pathPropertiesList.setUpdated(detailActionData.path.cloneParentPath());
          _reloadAndCopyFlags();
          selectNode(path: detailActionData.path.cloneParentPath());
          _globalSuccessState = SuccessState(true, message: "Item ${detailActionData.getLastPathElement()} updated");
        } catch (e, s) {
          debugPrintStack(stackTrace: s);
        }
      });
    }
  }

  SuccessState handleResolveLink(String value) {
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
    return SuccessState(true, message: "", value: n);
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
          (path, button) {
            if (button == "SAVE") {
              _saveDataState(_loadedData.dataToStringFormattedWithTs(_loadedData.password));
            }
            if (button == "CANCEL") {
              shouldExit = false;
              setState(() {
                _globalSuccessState = SuccessState(true, message: "Exit Cancelled");
              });
            }
          },
        );
      }
      return shouldExit;
    } finally {
      _inExitProcess = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeData appThemeData = _configData.getAppThemeData();
    final screenForeground = appThemeData.screenForegroundColour(true);
    final appBackgroundColor = appThemeData.screenBackgroundColor;
    final appBackgroundErrorColor = appThemeData.screenBackgroundErrorColor;

    _screenSize(context);
    _configData.onUpdate = _onUpdateConfig;

    FlutterWindowClose.setWindowShouldCloseHandler(() async {
      return await _handleShouldExit();
    });

    if (_loadedData.isNotEmpty) {
      if (_lastSearch != _search || _filteredNodeDataRoot.isEmpty) {
        _lastSearch = _search;
        _filteredNodeDataRoot = _treeNodeDataRoot.applyFilter(_search, true, (match, tolowerCase, node) {
          if (tolowerCase) {
            return (node.label.toLowerCase().contains(match));
          }
          return (node.label.contains(match));
        });
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
        if (key.endsWith(referenceExtension) && node is String) {
          final p = Path.fromDotPath(node);
          final n = _loadedData.getNodeFromJson(p);
          if (n == null) {
            count++;
            logger.log("## __REF_ERROR__ ${path.asMarkdownLink} not found");
          } else {
            if (n is! String) {
              count++;
              logger.log("## __REF_ERROR__ ${path.asMarkdownLink} to non String");
            }
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

    final indicatorIconKey = GlobalKey();
    final indicatorIcon = IndicatorIcon(
      const [Icons.access_time_filled, Icons.access_time],
      key: indicatorIconKey,
      color: _configData.getAppThemeData().screenForegroundColour(true),
      period: 500,
      padding: const EdgeInsets.all(5),
      size: (_configData.appBarHeight / 3.5) * 2,
      onClick: (c) {
        _handleAction(DetailAction.actionOnly(ActionType.showLog));
      },
      getState: (c) {
        if (c == 2 || (c % 15) == 0) {
          DataContainer.testHttpGet(
            _configData.getRemoteTestFileUrl(),
            (response) {
              if (response.isEmpty) {
                logger.log("__REMOTE__ Test file loaded OK");
                (indicatorIconKey.currentState as ShowAble).setShow(false);
              } else {
                logger.log("__REMOTE__ $response");
                (indicatorIconKey.currentState as ShowAble).setShow(true);
              }
            },
          );
        }
        return c + 1;
      },
    );

    final DisplaySplitView displayData = createSplitView(
      _loadedData,
      _filteredNodeDataRoot,
      _selectedTreeNode,
      _isEditDataDisplay,
      _configData.isDesktop(),
      _applicationState.screen.divPos,
      appThemeData,
      _pathPropertiesList,
      _selectNodeState,
      _expandNodeState,
      (value) {
        return handleResolveLink(value);
      },
      (divPos) {
        // On divider change
        _applicationState.updateDividerPosState(divPos);
      },
      (detailActionData) {
        // On selected detail page action
        return _handleAction(detailActionData);
      },
      logger.log,
      _applicationState.isDataSorted,
      _configData.getRootNodeName(),
    );
    _treeViewScrollController = displayData.scrollController;

    final List<Widget> toolBarItems = List.empty(growable: true);
    toolBarItems.add(
      DetailIconButton(
        iconData: Icons.close,
        tooltip: 'Exit application',
        gap: _configData.iconGap,
        onPressed: () async {
          final close = await _handleShouldExit();
          if (close) {
            closer(0);
          }
        },
        appThemeData: appThemeData,
      ),
    );

    if (_loadedData.isEmpty) {
      _navBarHeight = 0;
      toolBarItems.add(Container(
        color: appThemeData.primary.med,
        width: screenSize.width / 3,
        child: inputTextField("Password:", appThemeData.tsLarge, _configData.getAppThemeData().textSelectionThemeData, _configData.getAppThemeData().darkMode, true, passwordEditingController, (v) {
          _initialPassword = v;
          _loadDataState();
        }, (v) {}),
      ));
      toolBarItems.add(DetailIconButton(
        appThemeData: appThemeData,
        iconData: Icons.file_open,
        gap: _configData.iconGap,
        tooltip: 'Load Data',
        onPressed: () {
          _initialPassword = passwordEditingController.text;
          passwordEditingController.text = "";
          _loadDataState();
        },
      ));
      toolBarItems.add(DetailIconButton(
          appThemeData: appThemeData,
          iconData: Icons.rule_folder,
          tooltip: 'Choose File',
          gap: _configData.iconGap,
          onPressed: () {
            showLocalFilesDialog(
              context,
              _configData.getAppThemeData(),
              _configData.dir(["data", "json"], [defaultConfigFileName, _configData.getAppStateFileName()]),
              (fileName) {
                if (fileName != _configData.getDataFileName()) {
                  _configData.setValueForJsonPath(dataFileLocalNamePath, fileName);
                  _configData.update(callOnUpdate: true);
                  logger.log("__CONFIG__ File name updated to:'$fileName'");
                  _configData.save(logger.log);
                } else {
                  logger.log("__CONFIG__ File name not updated. No change");
                }
              },
              (action) {
                if (action == SimpleButtonActions.ok) {
                  _handleAction(DetailAction(ActionType.createFile, false, Path.empty()));
                }
              },
            );
          }));
    } else {
      //
      // Data is loaded
      //
      _navBarHeight = _configData.appBarHeight;
      toolBarItems.add(DetailIconButton(
        show: _loadedData.isNotEmpty,
        appThemeData: appThemeData,
        iconData: _isEditDataDisplay ? Icons.search : Icons.edit,
        tooltip: _isEditDataDisplay ? 'Search Mode' : "Edit Mode",
        gap: _configData.iconGap,
        onPressed: () {
          setState(() {
            _isEditDataDisplay = !_isEditDataDisplay;
          });
        },
      ));
      toolBarItems.add(DetailIconButton(
        show: _dataWasUpdated,
        appThemeData: appThemeData,
        iconData: Icons.save,
        tooltip: "Save",
        gap: _configData.iconGap,
        onPressed: () {
          _handleAction(DetailAction(ActionType.save, false, Path.empty()));
        },
      ));
      if (_isEditDataDisplay) {
        toolBarItems.add(VerticalDivider(
          color: screenForeground,
        ));
        toolBarItems.add(
          DetailIconButton(
            iconData: Icons.menu,
            tooltip: 'Menu',
            gap: _configData.iconGap,
            onPressed: () {
              showOptionsDialog(context, _configData.getAppThemeData(), _selectedPath, [
                MenuOptionDetails("Done", "", ActionType.none, () {
                  return Icons.arrow_back;
                }),
                MenuOptionDetails("Add NEW Group", "Add a new group to '%{3}'", ActionType.addGroup, () {
                  return Icons.add_box_outlined;
                }),
                MenuOptionDetails("Add NEW Detail", "Add a new detail to group '%{3}'", ActionType.addDetail, () {
                  return Icons.add;
                }),
                MenuOptionDetails("Clear Select", "Clear ALL selected", ActionType.groupSelectClearAll, () {
                  return Icons.deselect;
                }),
                MenuOptionDetails("Save %{0}", "Save %{4} %{2}%{0}", ActionType.save, () {
                  return Icons.lock_open;
                }),
                MenuOptionDetails("Save %{1}", "Save %{4} %{2}%{1}", ActionType.saveAlt, () {
                  return _loadedData.hasPassword ? Icons.lock_open : Icons.lock;
                }),
                MenuOptionDetails("New data file", "Create a new data file", ActionType.createFile, () {
                  return _dataWasUpdated ? Icons.disabled_by_default_outlined : Icons.post_add;
                }, enabled: !_dataWasUpdated),
                MenuOptionDetails("Reload data file", "Reload %{4}", ActionType.reload, () {
                  return Icons.refresh;
                }),
                MenuOptionDetails("Restart application", "Restart this application", ActionType.restart, () {
                  return Icons.restart_alt;
                }),
                MenuOptionDetails("Reset Saved State", "Clears Previous searches etc.", ActionType.clearState, () {
                  return Icons.cleaning_services;
                }),
              ], [
                _loadedData.hasPassword ? 'ENCRYPTED' : 'UN-ENCRYPTED',
                _loadedData.hasPassword ? 'UN-ENCRYPTED' : 'ENCRYPTED',
                _configData.isDesktop() ? "to local and remote storage " : "",
                _selectedPath.last,
                _loadedData.fileName,
              ], (selectedAction, path) {
                _handleAction(DetailAction(selectedAction, true, path));
              });
            },
            appThemeData: appThemeData,
          ),
        );
      }
      if (_isEditDataDisplay) {
        toolBarItems.add(VerticalDivider(
          color: screenForeground,
        ));
        toolBarItems.add(DetailIconButton(
          onPressed: () {
            _handleAction(DetailAction(ActionType.groupSelectAll, false, _selectedPath));
          },
          gap: _configData.iconGap,
          tooltip: "Invert Selection",
          iconData: Icons.select_all,
          appThemeData: appThemeData,
        ));
        final canPaste = _pathPropertiesList.hasGroupSelects;
        if (canPaste) {
          toolBarItems.add(DetailIconButton(
            onPressed: () {
              _handleAction(DetailAction(ActionType.groupSelectClearAll, false, _selectedPath));
            },
            gap: _configData.iconGap,
            tooltip: "Clear ALL Selected",
            iconData: Icons.deselect,
            appThemeData: appThemeData,
          ));
          toolBarItems.add(DetailIconButton(
            onPressed: () {
              _handleAction(DetailAction(ActionType.groupCopy, false, _selectedPath));
            },
            gap: _configData.iconGap,
            tooltip: "Copy to ${_selectedPath.last}",
            iconData: Icons.file_copy,
            appThemeData: appThemeData,
          ));
          toolBarItems.add(DetailIconButton(
            onPressed: () {
              _handleAction(DetailAction(ActionType.groupDelete, false, _selectedPath));
            },
            gap: _configData.iconGap,
            tooltip: "Delete Data",
            iconData: Icons.delete,
            appThemeData: appThemeData,
          ));
        }
      } else {
        toolBarItems.add(
          Container(
            color: appThemeData.primary.med,
            child: SizedBox(
              width: screenSize.width / 3,
              child: inputTextField("Search:", appThemeData.tsMedium, _configData.getAppThemeData().textSelectionThemeData, _configData.getAppThemeData().darkMode, false, searchEditingController, (v) {
                _setSearchExpressionState(v);
              }, (v) {}),
            ),
          ),
        );
        toolBarItems.add(
          DetailIconButton(
            appThemeData: appThemeData,
            iconData: Icons.search,
            tooltip: 'Search',
            gap: _configData.iconGap,
            onPressed: () {
              _setSearchExpressionState(searchEditingController.text);
            },
          ),
        );
        toolBarItems.add(
          DetailIconButton(
            appThemeData: appThemeData,
            iconData: Icons.manage_search,
            tooltip: 'Manage Searches',
            gap: _configData.iconGap,
            onPressed: () async {
              await showSearchDialog(
                context,
                _configData.getAppThemeData(),
                _applicationState.getLastFindList(),
                (selected) {
                  if (selected.isNotEmpty) {
                    _setSearchExpressionState(selected);
                  }
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
            gap: _configData.iconGap,
            onPressed: () {
              _setSearchExpressionState("");
            },
          ),
        );
      }
    }

    final settings = Positioned(
        left: (screenSize.width - (_configData.iconSize) - 2),
        top: _navBarHeight + 7 * _configData.scale,
        child: DetailIconButton(
          iconData: Icons.settings,
          tooltip: 'Settings',
          gap: _configData.iconGap,
          onPressed: () {
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
            );
          },
          appThemeData: appThemeData,
        ));
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    //
    if (_globalSuccessState.isSuccess) {
      final newCount = _pathPropertiesList.countGroupSelects;
      if (_currentSelectedGroups != newCount) {
        _currentSelectedGroups = newCount;
        if (newCount > 0) {
          _currentSelectedGroupsPrefix = "SEL[$newCount]: ";
        } else {
          _currentSelectedGroupsPrefix = "";
        }
      }
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
                    Container(
                      color: _configData.getAppThemeData().screenForegroundColour(true),
                      height: 1,
                    ),
                    _loadedData.isEmpty
                        ? const SizedBox(
                            height: 0,
                          )
                        : _filteredNodeDataRoot.isEmpty
                            ? const SizedBox(
                                height: 0,
                              )
                            : Container(
                                height: _navBarHeight,
                                color: appBackgroundColor,
                                child: createNodeNavButtonBar(_selectedPath, appThemeData, _isEditDataDisplay, _loadedData.isEmpty, _applicationState.isDataSorted, (detailActionData) {
                                  return _handleAction(detailActionData);
                                }),
                              ),
                    _loadedData.isEmpty
                        ? const SizedBox(
                            height: 0,
                          )
                        : Container(
                            color: _configData.getAppThemeData().screenForegroundColour(true),
                            height: 1,
                          ),
                    Container(
                      height: screenSize.height - (_configData.appBarHeight + _configData.appBarHeight + _navBarHeight),
                      color: appBackgroundColor,
                      child: displayData.splitView,
                    ),
                    Container(
                      color: _configData.getAppThemeData().screenForegroundColour(true),
                      height: 1,
                    ),
                    Container(
                      height: _configData.appBarHeight,
                      color: _globalSuccessState.isSuccess ? appBackgroundColor : appBackgroundErrorColor,
                      child: Row(
                        children: [
                          indicatorIcon,
                          DetailIconButton(
                            appThemeData: appThemeData,
                            iconData: Icons.view_timeline,
                            tooltip: 'Log',
                            gap: _configData.iconGap,
                            onPressed: () {
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
            ],
          ))),
    );
  }
}
