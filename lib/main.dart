import 'dart:async';
import 'dart:io';
import 'package:data_repo/configSettings.dart';
import 'package:data_repo/data_container.dart';
import 'package:data_repo/treeNode.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_size/window_size.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_window_close/flutter_window_close.dart';

import 'path.dart';
import 'data_types.dart';
import 'config.dart';
import 'appState.dart';
import 'main_view.dart';
import 'detail_buttons.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

const appBarHeight = 50.0;
const navBarHeight = 50.0;
const statusBarHeight = 35.0;
const inputTextTitleStyleHeight = 35.0;

late final ConfigData _configData;
late final ApplicationState _applicationState;

StringBuffer eventLog = StringBuffer();
String eventLogLatest = "";

bool _inExitProcess = false;
bool _shouldDisplayMarkdownHelp = false;
bool _shouldDisplayMarkdownPreview = false;

void closer(final int returnCode) async {
  exit(returnCode);
}

void log(final String text) {
  if (text == eventLogLatest) {
    return;
  }
  eventLogLatest = text;
  eventLog.writeln(text);
  eventLog.writeln("\n");
}

Size screenSize(BuildContext context) {
  final pt = MediaQuery.of(context).padding.top;
  final bi = MediaQuery.of(context).viewInsets.bottom - MediaQuery.of(context).viewInsets.top;
  final height = MediaQuery.of(context).size.height - (bi + pt);
  final width = MediaQuery.of(context).size.width;
  return Size(width, height);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final applicationDefaultDir = await ApplicationState.getApplicationDefaultDir();
    final isDesktop = ApplicationState.appIsDesktop();

    _configData = ConfigData(applicationDefaultDir, "config.json", isDesktop, log);
    _applicationState = ApplicationState.readAppStateConfigFile(_configData.getAppStateFileLocal(), log);
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
  bool _isEditDataDisplay = false;
  double _navBarHeight = navBarHeight;

  SuccessState _globalSuccessState = SuccessState(true);
  ScrollController _treeViewScrollController = ScrollController();
  DataContainer _loadedData = DataContainer.empty();
  MyTreeNode _treeNodeDataRoot = MyTreeNode.empty();
  MyTreeNode _filteredNodeDataRoot = MyTreeNode.empty();
  MyTreeNode _selectedTreeNode = MyTreeNode.empty();
  Path _selectedPath = Path.empty();

  final PathPropertiesList _pathPropertiesList = PathPropertiesList(log: log);
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
        _globalSuccessState = SuccessState(true, message: "Link submitted from $from", log: log);
      });
    } else {
      setState(() {
        _globalSuccessState = SuccessState(false, message: "Link could not be launched", log: log);
      });
    }
  }

  void selectNode({final Path? path}) {
    if (path != null) {
      final n = _treeNodeDataRoot.findByPath(path);
      if (n == null) {
        _selectedTreeNode = _treeNodeDataRoot.firstSelectableNode();
        log("__ERROR__ Selected node [$path] was not found");
      } else {
        if (n.isLeaf) {
          _selectedTreeNode = _treeNodeDataRoot.firstSelectableNode();
          log("__ERROR__ Selected node [$path] was a data node");
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
            log("__WARNING__ Data source has changed");
            _showModalButtonsDialog(context, "Data source has Changed", ["If you CONTINUE:", "Saving and Reloading", "will use OLD config data", "and UNSAVED config", "changes may be lost."], ["RESTART", "CONTINUE"], Path.empty(), (path, button) {
              if (button == "RESTART") {
                setState(() {
                  _clearData("Config updated - RESTART");
                  log("__RESTART__ Local file ${_configData.getDataFileLocal()}");
                  log("__RESTART__ Remote file ${_configData.getGetDataFileUrl()}");
                  setWindowTitle("${_configData.getTitle()}: ${_configData.getDataFileName()}");
                });
              } else {
                log("__CONFIG__ CONTINUE option chosen");
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
      log("__SEARCH__ cleared");
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
                _showCopyMoveDialog(
                  context,
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
                );
              }
            });
          }
          break;
        }
      case ActionType.removeItem:
        {
          _showModalButtonsDialog(context, "Remove item", ["${detailActionData.valueName} '${detailActionData.getLastPathElement()}'"], ["OK", "Cancel"], detailActionData.path, _handleDeleteState);
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
          _showModalInputDialog(
            context,
            "Change $title '${detailActionData.getLastPathElement()}'",
            detailActionData.getDisplayValue(false),
            detailActionData.value ? optionsForRenameElement : [],
            OptionsTypeData.locateTypeInOptionsList(detailActionData.oldValueType.key, optionsForRenameElement, optionTypeDataString),
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
          _showModalInputDialog(
            context,
            "Update Value '${detailActionData.getLastPathElement()}'",
            detailActionData.oldValue,
            optionsForUpdateElement,
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
              _showModalInputDialog(context, "New Group Name", "", [], optionsDataTypeEmpty, false, false, (action, text, type) {
                if (action == SimpleButtonActions.ok) {
                  _handleAddState(_selectedPath, text, optionTypeDataGroup);
                }
              }, (initial, value, initialType, valueType) {
                return value.trim().isEmpty ? "Cannot be empty" : "";
              });
            }
          });
          break;
        }
      case ActionType.addDetail:
        {
          Timer(const Duration(milliseconds: 1), () {
            if (mounted) {
              _showModalInputDialog(context, "New Detail Name", "", [], optionsDataTypeEmpty, false, false, (action, text, type) {
                if (action == SimpleButtonActions.ok) {
                  _handleAddState(_selectedPath, text, optionTypeDataValue);
                }
              }, (initial, value, initialType, valueType) {
                return value.trim().isEmpty ? "Cannot be empty" : "";
              });
            }
          });
          break;
        }
      case ActionType.createFile:
        {
          Timer(const Duration(milliseconds: 1), () {
            if (mounted) {
              _showFileNamePasswordDialog(context, "New File", [
                "Password if encryption is required:",
                "Enter a valid file name:",
                "File extension is added automatically.",
                "Un-Encrypted extension = .json",
                "Encrypted extension = .data",
              ], (action, fileName, password) {
                final fn = password.isEmpty ? "$fileName.json" : "$fileName.data";
                if (_configData.localFileExists(fn).isNotEmpty) {
                  return "${password.isNotEmpty ? "Encrypted" : ""} file '$fn' Exists";
                }
                if (action == SimpleButtonActions.ok) {
                  final content = DataContainer.staticDataToStringFormattedWithTs(_configData.getMinimumDataContentMap(), password, addTimeStamp: true);
                  final success = DataContainer.saveToFile(_configData.getDataFileLocalAlt(fn), content);
                  _globalSuccessState = success;
                  if (success.isFail) {
                    log("__CREATE__ Failed. ${success.message}");
                    Timer(const Duration(milliseconds: 1), () {
                      if (mounted) {
                        _showModalButtonsDialog(context, "Create File Failed", ["Reason - ${success.message}", "No changes were made"], ["Acknowledge"], Path.empty(), (path, button) {
                          setState(() {});
                        });
                      }
                    });
                  } else {
                    Timer(const Duration(milliseconds: 1), () {
                      if (mounted) {
                        _showModalButtonsDialog(context, "Create File:", ["Make this your NEW file", "or", "Continue with EXISTING file"], ["NEW", "EXISTING"], Path.empty(), (path, button) {
                          setState(() {
                            if (button == "NEW") {
                              _configData.setValueForJsonPath(dataFileLocalNamePath, fn);
                              _configData.save(log);
                              _configData.update(callOnUpdate: false);
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
              _showModalButtonsDialog(context, "Restart Alert", ["Restart - Discard changes", "Cancel - Don't Restart"], ["Restart", "Cancel"], Path.empty(), (p, sel) {
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
                _showModalButtonsDialog(context, "Reload Alert", ["Reload - Discard changes", "Cancel - Don't Reload"], ["Reload", "Cancel"], Path.empty(), (p, sel) {
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
              _showModalInputDialog(context, _loadedData.hasPassword ? "Confirm Password" : "New Password", "", [], optionsDataTypeEmpty, false, true, (button, pw, type) {
                if (button == SimpleButtonActions.ok) {
                  if (_loadedData.hasPassword) {
                    // Confirm PW (Save un-encrypted)
                    log("__SAVE__ Data as plain text");
                    _loadedData.password = "";
                  } else {
                    // New password (Save encrypted)
                    log("__SAVE__ Data as ENCRYPTED text");
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
    final remoteSaveState = await DataContainer.toHttpPost(_configData.getPostDataFileUrl(), content, log: log);
    if (remoteSaveState.isSuccess) {
      success++;
      rm = "Remote Save OK";
    } else {
      rm = "Remote Save FAIL";
    }
    setState(() {
      log("__SAVE:__ $lm. $rm");
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
    log("__DATA_CLEARED__ $reason");
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
      fileDataPrefixRemote = FileDataPrefix.fromString(successStateRemote.fileContent);
      fileDataContent = successStateRemote.fileContent.substring(fileDataPrefixRemote.startPos);
      fileDataPrefix = fileDataPrefixRemote;
      source = "Remote";
      log("__INFO:__ $source __TS:__ ${fileDataPrefix.timeStamp}");
    } else {
      log(successStateRemote.toLogString());
    }

    //
    // Try to load the local data.
    // If the local data is later than remote data or remote load failed, use the local data.
    //
    final successStateLocal = DataContainer.loadFromFile(localPath);
    if (successStateLocal.isSuccess) {
      final fileDataPrefixLocal = FileDataPrefix.fromString(successStateLocal.fileContent);
      if (successStateRemote.isFail || fileDataPrefixLocal.isLaterThan(fileDataPrefixRemote)) {
        fileDataContent = successStateLocal.fileContent.substring(fileDataPrefixLocal.startPos);
        fileDataPrefix = fileDataPrefixLocal;
        source = "Local";
        log("__INFO:__ $source __TS:__ ${fileDataPrefix.timeStamp}");
      }
    } else {
      log(successStateLocal.toLogString());
    }
    //
    // File is now loaded!
    //
    if (fileDataContent.isEmpty) {
      setState(() {
        _globalSuccessState = SuccessState(false, message: "__LOAD__ No Data Available", log: log);
      });
      return;
    }

    if (fileDataPrefix.encrypted && pw.isEmpty) {
      setState(() {
        _globalSuccessState = SuccessState(false, message: "__LOAD__ No Password Provided", log: log);
      });
      return;
    }

    final DataContainer data;
    try {
      data = DataContainer(fileDataContent, fileDataPrefix, successStateRemote.path, successStateLocal.path, fileName, pw);
    } catch (r) {
      setState(() {
        _globalSuccessState = SuccessState(false, message: "__LOAD__ Data file could not be parsed", exception: r as Exception, log: log);
      });
      return;
    }
    if (data.isEmpty) {
      setState(() {
        _globalSuccessState = SuccessState(false, message: "__LOAD__ Data file does not contain any data", log: log);
      });
      return;
    }
    _loadedData = data;
    setState(() {
      _dataWasUpdated = false;
      _pathPropertiesList.clear();
      _treeNodeDataRoot = MyTreeNode.fromMap(_loadedData.dataMap);
      _treeNodeDataRoot.expandAll(true);
      _treeNodeDataRoot.clearFilter();
      _filteredNodeDataRoot = MyTreeNode.empty();
      _selectedTreeNode = _treeNodeDataRoot.firstSelectableNode();
      _selectedPath = _selectedTreeNode.path;
      _globalSuccessState = SuccessState(true, message: "${fileDataPrefix.encrypted ? "Encrypted" : ""} [$source] File: ${_loadedData.timeStampString}", log: log);
    });
  }

  void _reloadAndCopyFlags() {
    final temp = MyTreeNode.fromMap(_loadedData.dataMap);
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
          mapNodes.lastNodeAsMap![name] = "undefined";
          _dataWasUpdated = true;
          _pathPropertiesList.setUpdated(path);
          _pathPropertiesList.setRenamed(path.cloneAppendList([name]));
          _pathPropertiesList.setUpdated(path.cloneAppendList([name]));
          _reloadAndCopyFlags();
          selectNode(path: path);
          _globalSuccessState = SuccessState(true, message: "Data node '$name' added", log: log);
        });
        break;
      case optionTypeDataGroup:
        setState(() {
          final Map<String, dynamic> m = {};
          mapNodes.lastNodeAsMap![name] = m;
          _dataWasUpdated = true;
          _pathPropertiesList.setUpdated(path);
          _pathPropertiesList.setRenamed(path.cloneAppendList([name]));
          _pathPropertiesList.setUpdated(path.cloneAppendList([name]));
          _reloadAndCopyFlags();
          selectNode(path: path);
          _globalSuccessState = SuccessState(true, message: "Group Node '$name' added", log: log);
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

        var newPath = detailActionData.path.cloneRename(newName);
        var parentPath = newPath.cloneParentPath();
        _pathPropertiesList.setRenamed(newPath);
        _pathPropertiesList.setRenamed(parentPath);
        _reloadAndCopyFlags();
        selectNode(path: parentPath);
        _globalSuccessState = SuccessState(true, message: "Node '$oldName' renamed $newName", log: log);
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

  Future<bool> _handleShouldExit() async {
    if (_inExitProcess) {
      return false;
    }
    _inExitProcess = true;
    try {
      bool shouldExit = true;
      if (_dataWasUpdated) {
        await _showModalButtonsDialog(
          context,
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
      _navBarHeight = 0;
    } else {
      if (_search.isNotEmpty) {
        _applicationState.addLastFind(_search, 10);
      }
      _navBarHeight = navBarHeight;
    }

    final DisplaySplitView displayData = createSplitView(
      _loadedData,
      _filteredNodeDataRoot,
      _selectedTreeNode,
      _isEditDataDisplay,
      _configData.isDesktop(),
      _applicationState.screen.divPos,
      _configData.getAppThemeData(),
      _pathPropertiesList,
      _selectNodeState,
      _expandNodeState,
      (divPos) {
        // On divider change
        _applicationState.updateDividerPosState(divPos);
      },
      (detailActionData) {
        // On selected detail page action
        return _handleAction(detailActionData);
      },
      log,
    );
    _treeViewScrollController = displayData.scrollController;

    final List<Widget> toolBarItems = List.empty(growable: true);
    toolBarItems.add(
      DetailIconButton(
        iconData: Icons.close_outlined,
        tooltip: 'Exit application',
        onPressed: () async {
          final close = await _handleShouldExit();
          if (close) {
            closer(0);
          }
        },
        appThemeData: _configData.getAppThemeData(),
      ),
    );

    if (_loadedData.isEmpty) {
      toolBarItems.add(Container(
        color: _configData.getAppThemeData().primary.med,
        child: SizedBox(
          width: screenSize(context).width / 3,
          child: TextField(
            style: _configData.getAppThemeData().tsLarge,
            decoration: const InputDecoration(
              hintText: 'Password',
            ),
            autofocus: true,
            onSubmitted: (value) {
              _initialPassword = value;
              passwordEditingController.text = "";
              _loadDataState();
            },
            obscureText: true,
            controller: passwordEditingController,
            cursorColor: const Color(0xff000000),
          ),
        ),
      ));
      toolBarItems.add(DetailIconButton(
        appThemeData: _configData.getAppThemeData(),
        iconData: Icons.file_open,
        tooltip: 'Load Data',
        timerMs: 5000,
        onPressed: () {
          _initialPassword = passwordEditingController.text;
          passwordEditingController.text = "";
          _loadDataState();
        },
      ));
    } else {
      //
      // Data is loaded
      //
      toolBarItems.add(DetailIconButton(
        show: _loadedData.isNotEmpty,
        appThemeData: _configData.getAppThemeData(),
        iconData: _isEditDataDisplay ? Icons.search : Icons.edit,
        tooltip: _isEditDataDisplay ? 'Search Mode' : "Edit Mode",
        onPressed: () {
          setState(() {
            _isEditDataDisplay = !_isEditDataDisplay;
          });
        },
      ));
      toolBarItems.add(DetailIconButton(
        show: _dataWasUpdated,
        appThemeData: _configData.getAppThemeData(),
        iconData: Icons.save,
        tooltip: "Save",
        onPressed: () {
          _saveDataState(_loadedData.dataToStringFormattedWithTs(_loadedData.password));
        },
      ));
      if (_isEditDataDisplay) {
        toolBarItems.add(VerticalDivider(
          color: _configData.getAppThemeData().screenForegroundColour(true),
        ));
        toolBarItems.add(
          DetailIconButton(
            iconData: Icons.menu,
            tooltip: 'Menu',
            onPressed: () {
              _showOptionsDialog(context, _selectedPath, [
                MenuOptionDetails("Done", "", ActionType.none, () {
                  return Icons.arrow_back;
                }),
                MenuOptionDetails("Invert Select '%{3}'", "Invert ALL selected in '%{3}'", ActionType.groupSelectAll, () {
                  return Icons.select_all;
                }),
                MenuOptionDetails("Clear Select", "Clear ALL selected", ActionType.groupSelectClearAll, () {
                  return Icons.deselect;
                }),
                MenuOptionDetails("Add NEW Group", "Add a new group to '%{3}'", ActionType.addGroup, () {
                  return Icons.add_box_outlined;
                }),
                MenuOptionDetails("Add NEW Detail", "Add a new detail to group '%{3}'", ActionType.addDetail, () {
                  return Icons.add;
                }),
                MenuOptionDetails("Save %{0}", "Save %{4} %{2}%{0}", ActionType.save, () {
                  return Icons.save;
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
            appThemeData: _configData.getAppThemeData(),
          ),
        );
      }
      if (_isEditDataDisplay) {
        toolBarItems.add(VerticalDivider(
          color: _configData.getAppThemeData().screenForegroundColour(true),
        ));
        toolBarItems.add(DetailIconButton(
          onPressed: () {
            _handleAction(DetailAction(ActionType.groupSelectAll, false, _selectedPath));
          },
          tooltip: "Invert Selection",
          iconData: Icons.select_all,
          appThemeData: _configData.getAppThemeData(),
        ));
        final canPaste = _pathPropertiesList.hasGroupSelects;
        if (canPaste) {
          toolBarItems.add(DetailIconButton(
            onPressed: () {
              _handleAction(DetailAction(ActionType.groupSelectClearAll, false, _selectedPath));
            },
            tooltip: "Clear ALL Selected",
            iconData: Icons.deselect,
            appThemeData: _configData.getAppThemeData(),
          ));
          toolBarItems.add(DetailIconButton(
            onPressed: () {
              _handleAction(DetailAction(ActionType.groupCopy, false, _selectedPath));
            },
            tooltip: "Copy to ${_selectedPath.last}",
            iconData: Icons.file_copy,
            appThemeData: _configData.getAppThemeData(),
          ));
          toolBarItems.add(DetailIconButton(
            onPressed: () {
              _handleAction(DetailAction(ActionType.groupDelete, false, _selectedPath));
            },
            tooltip: "Delete Data",
            iconData: Icons.delete,
            appThemeData: _configData.getAppThemeData(),
          ));
        }
      } else {
        toolBarItems.add(
          Container(
            color: _configData.getAppThemeData().primary.med,
            child: SizedBox(
              width: screenSize(context).width / 3,
              child: TextField(
                style: _configData.getAppThemeData().tsMedium,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Search',
                ),
                autofocus: true,
                onSubmitted: (value) {
                  _setSearchExpressionState(value);
                },
                controller: searchEditingController,
                cursorColor: const Color(0xff000000),
              ),
            ),
          ),
        );
        toolBarItems.add(
          DetailIconButton(
            appThemeData: _configData.getAppThemeData(),
            iconData: Icons.search,
            tooltip: 'Search',
            onPressed: () {
              _setSearchExpressionState(searchEditingController.text);
            },
          ),
        );
        toolBarItems.add(
          DetailIconButton(
            appThemeData: _configData.getAppThemeData(),
            iconData: Icons.youtube_searched_for,
            tooltip: 'Previous Searches',
            onPressed: () async {
              await _showSearchDialog(
                context,
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
            appThemeData: _configData.getAppThemeData(),
            iconData: Icons.search_off,
            tooltip: 'Clear Search',
            onPressed: () {
              _setSearchExpressionState("");
            },
          ),
        );
      }
    }

    final settings = Positioned(
        left: screenSize(context).width - appBarHeight,
        top: 0,
        child: DetailIconButton(
          iconData: Icons.settings,
          tooltip: 'Settings',
          onPressed: () {
            _showConfigDialog(
              context,
              _configData.getAppThemeData(),
              _configData.getConfigFileName(),
              _configData.getDataFileDir(),
              (validValue, detail) {
                // Validate
                return SettingValidation.ok();
              },
              (settingsControlList, save) {
                // Commit
                settingsControlList.commit(_configData, log: log);
                setState(() {
                  _configData.update();
                  if (save) {
                    _globalSuccessState = _configData.save(log);
                  } else {
                    _globalSuccessState = SuccessState(true, message: "Config data NOT saved");
                  }
                });
              },
              () {
                return _dataWasUpdated ? "Must Save changes first" : "";
              },
            );
          },
          appThemeData: _configData.getAppThemeData(),
        ));
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    //
    final appBackgroundColor = _configData.getAppThemeData().screenBackgroundColor;
    final appBackgroundErrorColor = _configData.getAppThemeData().screenBackgroundErrorColor;
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
                      height: appBarHeight,
                      color: appBackgroundColor,
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: toolBarItems),
                    ),
                    Container(
                      color: Colors.black,
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
                                child: createNodeNavButtonBar(_selectedPath, _configData.getAppThemeData(), _isEditDataDisplay, _loadedData.isEmpty, (detailActionData) {
                                  return _handleAction(detailActionData);
                                }),
                              ),
                    _loadedData.isEmpty
                        ? const SizedBox(
                            height: 0,
                          )
                        : Container(
                            color: Colors.black,
                            height: 1,
                          ),
                    Container(
                      height: screenSize(context).height - (appBarHeight + statusBarHeight + _navBarHeight),
                      color: appBackgroundColor,
                      child: displayData.splitView,
                    ),
                    Container(
                      height: statusBarHeight,
                      color: _globalSuccessState.isSuccess ? appBackgroundColor : appBackgroundErrorColor,
                      child: Row(
                        children: [
                          DetailIconButton(
                            appThemeData: _configData.getAppThemeData(),
                            iconData: Icons.view_timeline,
                            tooltip: 'Log',
                            padding: const EdgeInsets.all(1.0),
                            onPressed: () {
                              _showLogDialog(context, eventLog.toString());
                            },
                          ),
                          Text(
                            _globalSuccessState.toString(),
                            style: _configData.getAppThemeData().tsMedium,
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

Future<void> _showConfigDialog(final BuildContext context, AppThemeData appThemeData, final String fileName, String dataFileDir, final SettingValidation Function(dynamic, SettingDetail) validate, final void Function(SettingControlList, bool) onCommit, final String Function() canChangeConfig) async {
  final settingsControlList = SettingControlList(appThemeData.desktop, dataFileDir, _configData);
  final applyButton = DetailButton(
    disable: true,
    text: "Apply",
    appThemeData: appThemeData,
    onPressed: () {
      onCommit(settingsControlList, false);
      log("__CONFIG__ changes APPLIED");
      Navigator.of(context).pop();
    },
  );
  final saveButton = DetailButton(
    disable: true,
    text: "Save",
    appThemeData: appThemeData,
    onPressed: () {
      onCommit(settingsControlList, true);
      log("__CONFIG__ changes SAVED");
      Navigator.of(context).pop();
    },
  );
  return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _configData.getAppThemeData().dialogBackgroundColor,
          insetPadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
          title: Row(
            children: [
              Text("Settings: ", style: appThemeData.tsLarge),
              Icon(
                Icons.circle_rounded,
                color: appThemeData.primary.lightest,
              ),
              Icon(
                Icons.circle_rounded,
                color: appThemeData.primary.light,
              ),
              Icon(
                Icons.circle_rounded,
                color: appThemeData.primary.med,
              ),
              Icon(
                Icons.circle_rounded,
                color: appThemeData.primary.medLight,
              ),
              Icon(
                Icons.circle_rounded,
                color: appThemeData.primary.medDark,
              ),
              Icon(
                Icons.circle_rounded,
                color: appThemeData.primary.dark,
              ),
              Icon(
                Icons.circle_rounded,
                color: appThemeData.primary.darkest,
              ),
            ],
          ),
          content: ConfigInputPage(
            appThemeData: appThemeData,
            settingsControlList: settingsControlList,
            onValidate: (dynamicValue, settingDetail) {
              return validate(dynamicValue, settingDetail);
            },
            onUpdateState: (settingsControlList, hint) {
              final enable = settingsControlList.canSaveOrApply & hint.isEmpty;
              applyButton.setDisabled(!enable);
              saveButton.setDisabled(!enable);
            },
            hint: canChangeConfig(),
            width: screenSize(context).width,
          ),
          actions: [
            Row(
              children: [
                DetailButton(
                  text: "Cancel",
                  appThemeData: appThemeData,
                  onPressed: () {
                    settingsControlList.clear();
                    Navigator.of(context).pop();
                  },
                ),
                saveButton,
                applyButton,
              ],
            )
          ],
        );
      });
}

Future<void> _showOptionsDialog(final BuildContext context, final Path path, final List<MenuOptionDetails> menuOptionsList, final List<String> sub, final Function(ActionType, Path) onSelect) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: _configData.getAppThemeData().dialogBackgroundColor,
        child: ListView(
          children: [
            for (int i = 0; i < menuOptionsList.length; i++) ...[
              menuOptionsList[i].enabled
                  ? Card(
                      color: _configData.getAppThemeData().detailBackgroundColor,
                      child: ListTile(
                        leading: Icon(menuOptionsList[i].icon, color: _configData.getAppThemeData().screenForegroundColour(true)),
                        title: Container(
                          padding: const EdgeInsets.all(5.0),
                          color: _configData.getAppThemeData().dialogBackgroundColor,
                          child: Text(menuOptionsList[i].s1(sub), style: _configData.getAppThemeData().tsLarge),
                        ),
                        subtitle: menuOptionsList[i].hasSubText ? Text(menuOptionsList[i].s2(sub), style: _configData.getAppThemeData().tsMedium) : null,
                        onTap: () {
                          if (menuOptionsList[i].enabled) {
                            onSelect(menuOptionsList[i].action, path);
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    )
                  : const SizedBox(height: 0),
            ]
          ],
        ),
      );
    },
  );
}

List<Widget> _stringsToTextList(final List<String> values, final int startAt, final Widget separator, final AppThemeData theme) {
  final wl = <Widget>[];
  for (int i = startAt; i < values.length; i++) {
    wl.add(Text(values[i], style: theme.tsMedium));
    wl.add(separator);
  }
  return wl;
}

Future<void> _showFileNamePasswordDialog(final BuildContext context, final String title, final List<String> info, final String Function(SimpleButtonActions, String, String) onAction) async {
  final theme = _configData.getAppThemeData();
  const separator = SizedBox(height: 5);
  final content = _stringsToTextList(info, 1, separator, theme);

  var fileName = "";
  var password = "";

  final okButton = DetailButton(
    text: "OK",
    disable: true,
    appThemeData: theme,
    onPressed: () {
      onAction(SimpleButtonActions.ok, fileName, password);
      Navigator.of(context).pop();
    },
  );

  final fileNameInput = ValidatedInputField(
    prompt: "File Name",
    appThemeData: _configData.getAppThemeData(),
    onValidate: (ix, vx, it, vt) {
      var message = "";
      if (vx.length < 2) {
        message = "Must be longer than 2 characters";
      } else {
        if (vx.contains(".")) {
          message = "Don't add an extension";
        } else {
          message = onAction(SimpleButtonActions.validate, vx, password);
        }
      }
      if (message.isEmpty) {
        fileName = vx;
      }
      okButton.setDisabled(message.isNotEmpty);
      return message;
    },
  );

  final passwordInput = ValidatedInputField(
    isPassword: true,
    prompt: "Password",
    appThemeData: _configData.getAppThemeData(),
    onValidate: (ix, vx, it, vt) {
      var message = "";
      if (vx.isNotEmpty && vx.length <= 4) {
        message = "Must be longer than 4";
      }
      if (message.isEmpty) {
        password = vx;
      } else {
        password = "";
      }
      fileNameInput.reValidate(id: "xxx");
      return message;
    },
  );

  content.add(fileNameInput);
  content.add(separator);
  content.add(Text(info[0], style: theme.tsMedium));
  content.add(passwordInput);

  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        insetPadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        backgroundColor: theme.dialogBackgroundColor,
        // title: Text("Copy or Move TO:\n'$into'", style: theme.tsMedium),
        title: Text(title, style: theme.tsMediumBold),
        content: SingleChildScrollView(
          child: ListBody(children: content),
        ),
        actions: [
          Row(
            children: [
              DetailButton(
                text: "CANCEL",
                disable: false,
                appThemeData: theme,
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              okButton
            ],
          ),
        ],
      );
    },
  );
}

Widget _copyMoveSummaryList(GroupCopyMoveSummaryList summaryList, AppThemeData theme, Path into, final String head, final bool copyMove, final void Function(SimpleButtonActions, Path) onAction) {
  final wl = <Widget>[];
  final tab = theme.textSize("Group: ", theme.tsMedium);
  wl.add(Text("Selected Data:", style: theme.tsMediumBold));
  wl.add(Container(
    color: Colors.black,
    height: 2,
  ));
  for (int i = 0; i < summaryList.length; i++) {
    for (int j = 0; j < summaryList.length; j++) {
      final ni = summaryList.list[i];
      final nj = summaryList.list[j];
      debugPrint("! ni:${ni.copyFromPath} nj:${nj.copyFromPath}");
    }
  }
  for (int i = 0; i < summaryList.length; i++) {
    final summary = summaryList.list[i];
    final tag = summary.isValue ? "Value:" : "Group:";
    final r1 = Row(
      children: [
        IconButton(
            onPressed: () {
              onAction(SimpleButtonActions.listRemove, summaryList.list[i].copyFromPath);
            },
            tooltip: "Delete from this list",
            icon: const Icon(Icons.delete)),
        summary.isError ? Text(summary.error, style: theme.tsMediumError) : Text("OK: Can $head", style: theme.tsMedium),
      ],
    );
    final r2 = Row(
      children: [
        SizedBox(width: tab.width, child: Text(tag, style: theme.tsMedium)),
        Text(summary.name, style: theme.tsMediumBold),
      ],
    );
    final r3 = Row(
      children: [
        SizedBox(width: tab.width, child: Text("In:", style: theme.tsMedium)),
        Text(summary.parent, style: theme.tsMediumBold),
      ],
    );
    wl.add(r1);
    wl.add(r2);
    wl.add(r3);
    if (copyMove) {
      final r4 = Row(
        children: [
          SizedBox(width: tab.width, child: Text("To:", style: theme.tsMedium)),
          Text(into.toString(), style: theme.tsMediumBold),
        ],
      );
      wl.add(r4);
    }
    wl.add(Container(
      color: Colors.black,
      height: 2,
    ));
  }
  return ListBody(children: wl);
}

Future<void> _showCopyMoveDialog(final BuildContext context, final Path into, final GroupCopyMoveSummaryList summaryList, bool copyMove, final void Function(SimpleButtonActions, Path) onAction) async {
  final head = copyMove ? "Copy or Move" : "Delete";
  final toFrom = copyMove ? "To" : "";
  final theme = _configData.getAppThemeData();
  final top = Column(children: [
    Text("$head $toFrom", style: theme.tsMedium),
    copyMove ? Text(into.toString(), style: theme.tsMedium) : const SizedBox(height: 0),
  ]);
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        insetPadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        backgroundColor: theme.dialogBackgroundColor,
        // title: Text("Copy or Move TO:\n'$into'", style: theme.tsMedium),
        title: top,
        content: SingleChildScrollView(
          child: _copyMoveSummaryList(summaryList, theme, into, head, copyMove, (action, path) {
            onAction(action, path);
            Navigator.of(context).pop();
          }),
        ),
        actions: <Widget>[
          Row(
            children: [
              DetailButton(
                appThemeData: _configData.getAppThemeData(),
                text: "Cancel",
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              DetailButton(
                appThemeData: _configData.getAppThemeData(),
                text: "Copy",
                show: summaryList.hasNoErrors && copyMove,
                onPressed: () {
                  onAction(SimpleButtonActions.copy, into);
                  Navigator.of(context).pop();
                },
              ),
              DetailButton(
                appThemeData: _configData.getAppThemeData(),
                text: "Move",
                show: summaryList.hasNoErrors && copyMove,
                onPressed: () {
                  onAction(SimpleButtonActions.move, into);
                  Navigator.of(context).pop();
                },
              ),
              DetailButton(
                appThemeData: _configData.getAppThemeData(),
                text: "Remove",
                show: summaryList.hasNoErrors && !copyMove,
                onPressed: () {
                  onAction(SimpleButtonActions.delete, Path.empty());
                  Navigator.of(context).pop();
                },
              ),
              DetailButton(
                appThemeData: _configData.getAppThemeData(),
                text: "Clear",
                onPressed: () {
                  onAction(SimpleButtonActions.listClear, Path.empty());
                  Navigator.of(context).pop();
                },
              ),
            ],
          )
        ],
      );
    },
  );
}

Future<void> _showLogDialog(final BuildContext context, final String log) async {
  final scrollController = ScrollController();
  Future.delayed(
    const Duration(milliseconds: 400),
    () {
      scrollController.animateTo(scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 400), curve: Curves.ease);
    },
  );

  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: _configData.getAppThemeData().dialogBackgroundColor,
        insetPadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        title: Text('Event Log', style: _configData.getAppThemeData().tsMedium),
        content: SingleChildScrollView(
            child: Container(
          color: _configData.getAppThemeData().primary.light,
          height: screenSize(context).height,
          width: screenSize(context).width,
          child: Markdown(
            controller: scrollController,
            data: log,
            selectable: true,
            shrinkWrap: true,
            styleSheetTheme: MarkdownStyleSheetBaseTheme.platform,
          ),
        )),
        actions: <Widget>[
          Row(
            children: [
              DetailButton(
                appThemeData: _configData.getAppThemeData(),
                text: "TOP",
                onPressed: () {
                  scrollController.animateTo(scrollController.position.minScrollExtent, duration: const Duration(milliseconds: 400), curve: Curves.ease);
                },
              ),
              DetailButton(
                appThemeData: _configData.getAppThemeData(),
                text: "BOTTOM",
                onPressed: () {
                  scrollController.animateTo(scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 400), curve: Curves.ease);
                },
              ),
              DetailButton(
                appThemeData: _configData.getAppThemeData(),
                text: "DONE",
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          )
        ],
      );
    },
  );
}

Future<void> _showSearchDialog(final BuildContext context, final List<String> prevList, final Function(String) onSelect) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: _configData.getAppThemeData().dialogBackgroundColor,
        insetPadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        title: Text('Previous Searches', style: _configData.getAppThemeData().tsMedium),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Container(
                height: 1,
                color: _configData.getAppThemeData().screenForegroundColour(true),
              ),
              for (int i = 0; i < prevList.length; i++) ...[
                TextButton(
                  child: Text(prevList[i], style: _configData.getAppThemeData().tsMedium),
                  onPressed: () {
                    onSelect(prevList[i]);
                    Navigator.of(context).pop();
                  },
                ),
                Container(
                  height: 1,
                  color: _configData.getAppThemeData().screenForegroundColour(true),
                ),
              ]
            ],
          ),
        ),
        actions: <Widget>[
          DetailButton(
            appThemeData: _configData.getAppThemeData(),
            text: "Cancel",
            onPressed: () {
              onSelect("");
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

Future<void> _showModalButtonsDialog(final BuildContext context, final String title, final List<String> texts, final List<String> buttons, final Path path, final void Function(Path, String) onResponse) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: _configData.getAppThemeData().dialogBackgroundColor,
        insetPadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        title: Text(title, style: _configData.getAppThemeData().tsMedium),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              for (int i = 0; i < texts.length; i++) ...[
                (texts[i].startsWith('#')) ? Container(alignment: Alignment.center, color: _configData.getPrimaryColour().dark, child: Text(texts[i].substring(1), style: _configData.getAppThemeData().tsMedium)) : Text(texts[i], style: _configData.getAppThemeData().tsMedium),
              ]
            ],
          ),
        ),
        actions: <Widget>[
          Row(
            children: [
              for (int i = 0; i < buttons.length; i++) ...[
                DetailButton(
                  appThemeData: _configData.getAppThemeData(),
                  text: buttons[i],
                  onPressed: () {
                    onResponse(path, buttons[i].toUpperCase());
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ],
          ),
        ],
      );
    },
  );
}

Future<void> _showModalInputDialog(final BuildContext context, final String title, final String currentValue, final List<OptionsTypeData> options, final OptionsTypeData currentOption, final bool isRename, final bool isPassword, final void Function(SimpleButtonActions, String, OptionsTypeData) onAction, final String Function(String, String, OptionsTypeData, OptionsTypeData) externalValidate) async {
  var updatedText = currentValue;
  var updatedType = currentOption;

  var okButton = DetailButton(
    text: "OK",
    disable: true,
    appThemeData: _configData.getAppThemeData(),
    onPressed: () {
      onAction(SimpleButtonActions.ok, updatedText, updatedType);
      Navigator.of(context).pop();
    },
  );

  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: _configData.getAppThemeData().dialogBackgroundColor,
        insetPadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        title: Text(title, style: _configData.getAppThemeData().tsMedium),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              (currentOption == optionTypeDataMarkDown && !isRename && !isPassword)
                  ? MarkDownInputField(
                      appThemeData: _configData.getAppThemeData(),
                      initialText: currentValue,
                      onValidate: (ix, vx, it, vt) {
                        okButton.setDisabled(ix == vx);
                        updatedText = vx;
                        updatedType = vt;
                        return "";
                      },
                      height: screenSize(context).height - (appBarHeight + statusBarHeight + inputTextTitleStyleHeight + 100),
                      width: screenSize(context).width,
                      shouldDisplayHelp: (flipValue) {
                        if (flipValue) {
                          _shouldDisplayMarkdownHelp = !_shouldDisplayMarkdownHelp;
                          if (_shouldDisplayMarkdownHelp) {
                            _shouldDisplayMarkdownPreview = false;
                          }
                        }
                        return _shouldDisplayMarkdownHelp;
                      },
                      shouldDisplayPreview: (flipValue) {
                        if (flipValue) {
                          _shouldDisplayMarkdownPreview = !_shouldDisplayMarkdownPreview;
                          if (_shouldDisplayMarkdownPreview) {
                            _shouldDisplayMarkdownHelp = false;
                          }
                        }
                        return _shouldDisplayMarkdownPreview;
                      },
                      dataAction: (detailAction) {
                        onAction(SimpleButtonActions.link, detailAction.oldValue, OptionsTypeData.forTypeOrName(String, "link"));
                        return Path.empty();
                      },
                    )
                  : ValidatedInputField(
                      options: options,
                      isPassword: isPassword,
                      initialOption: currentOption,
                      initialValue: currentValue,
                      prompt: "Input: ${isRename ? "New Name" : "[type]"}",
                      appThemeData: _configData.getAppThemeData(),
                      onSubmit: (text, type) {
                        onAction(SimpleButtonActions.ok, text, type);
                        Navigator.of(context).pop();
                      },
                      onValidate: (ix, vx, it, vt) {
                        final validMsg = externalValidate(ix.trim(), vx.trim(), it, vt);
                        if (validMsg.isEmpty) {
                          okButton.setDisabled(false);
                          updatedText = vx;
                          updatedType = vt;
                        } else {
                          okButton.setDisabled(true);
                        }
                        return validMsg;
                      },
                    ),
            ],
          ),
        ),
        actions: [
          Row(
            children: [
              DetailButton(
                text: "CANCEL",
                disable: false,
                appThemeData: _configData.getAppThemeData(),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              okButton
            ],
          ),
        ],
      );
    },
  );
}
