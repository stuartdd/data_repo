import 'dart:io';
import 'package:data_repo/data_load.dart';
import 'package:data_repo/treeNode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_treeview/flutter_treeview.dart';
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

late final ConfigData _configData;
late final ApplicationState _applicationState;

StringBuffer eventLog = StringBuffer();
String eventLogLatest = "";

String _okCancelDialogResult = "";
bool _inExitProcess = false;
final PathList _hiLightedPaths = PathList();
final TextEditingController textEditingController = TextEditingController(text: "");

const appBarHeight = 50.0;
const statusBarHeight = 35.0;
const inputTextTitleStyleHeight = 35.0;
const iconDataFileLoad = Icons.file_open;

bool _shouldDisplayMarkdownHelp = false;
bool _shouldDisplayMarkdownPreview = false;

void closer(int returnCode) async {
  exit(returnCode);
}

void log(String text) {
  if (text == eventLogLatest) {
    return;
  }
  eventLogLatest = text;
  eventLog.writeln(text);
  eventLog.writeln("\n");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final applicationDefaultDir = await ApplicationState.getApplicationDefaultDir();
    final isDesktop = ApplicationState.appIsDesktop();
    _configData = ConfigData(applicationDefaultDir, "config.json", isDesktop, log);
    _applicationState = await ApplicationState.readAppStateConfigFile(_configData.getAppStateFileLocal(), log);
    if (isDesktop) {
      setWindowTitle("${_configData.getTitle()}: ${_configData.getUserName()}");
      const WindowOptions(
        minimumSize: Size(200, 200),
        titleBarStyle: TitleBarStyle.normal,
      );
      setWindowFrame(Rect.fromLTWH(_applicationState.screen.x, _applicationState.screen.y, _applicationState.screen.w, _applicationState.screen.h));
    }
  } catch (e) {
    print(e);
    closer(1);
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget with WindowListener {
  MyApp({super.key});

  @override
  onWindowEvent(String eventName) async {
    switch (eventName) {
      case 'maximize':
      case 'minimize':
        {
          _applicationState.setShouldUpdateScreen(false);
          break;
        }
      case 'unmaximize':
        {
          _applicationState.setShouldUpdateScreen(true);
          break;
        }
      case 'close':
        {
          return;
        }
      case 'move':
      case 'resize':
        {
          if (_configData.isDesktop()) {
            final info = await getWindowInfo();
            if (_applicationState.updateScreenState(info.frame.left, info.frame.top, info.frame.width, info.frame.height)) {
              await _applicationState.writeAppStateConfigFile(false);
            }
          }
          break;
        }
      default:
        {
          debugPrint("Event:$eventName");
        }
    }
    super.onWindowEvent(eventName);
  }

  @override
  Widget build(BuildContext context) {
    if (_configData.isDesktop()) {
      windowManager.addListener(this);
    }
    return MaterialApp(
      title: 'data_repo',
      theme: ThemeData(primarySwatch: _configData.getPrimaryColour()),
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
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _password = "";
  String _search = "";
  String _previousSearch = "";
  bool _beforeDataLoaded = true;
  bool _dataWasUpdated = false;
  bool _isEditDataDisplay = false;
  SuccessState _globalSuccessState = SuccessState(true);
  DataContainer _loadedData = DataContainer.empty();
  ScrollController _treeViewScrollController = ScrollController();
  MyTreeNode _treeNodeDataRoot = MyTreeNode.empty();
  Path _selectedPath = Path.empty();
  MyTreeNode _selectedTreeNode = MyTreeNode.empty();

  Map<String, BuildContext> nodeContextList = {};

  Future<void> implementLinkState(final String href, final String from) async {
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

  void _setSearchExpressionState(String st) {
    if (st == _search) {
      return;
    }
    setState(() {
      textEditingController.text = st;
      _search = st;
    });
  }

  Future<void> _saveDataState() async {
    final String content = _loadedData.dataAsString();
    final ss = DataLoad.saveToFile(_configData.getDataFileLocal(), content);
    if (ss.isSuccess) {
      log("__OK:__ Local Data saved");
    }
    final pp = await DataLoad.toHttpPost(_configData.getPostDataFileUrl(), content, log: log);
    if (pp.isSuccess) {
      log("__OK:__ Remote Data saved");
    }
    String m = "Remote Save";
    bool success = true;
    if (pp.isSuccess) {
      m = "$m OK. Local Save";
    } else {
      success = false;
      m = "$m FAIL. Local Save";
    }
    if (ss.isSuccess) {
      m = "$m OK";
    } else {
      success = false;
      m = "$m FAIL";
    }
    setState(() {
      if (success) {
        _dataWasUpdated = false;
        _hiLightedPaths.clean();
      }
      _globalSuccessState = SuccessState(success, message: m);
    });
  }

  void _loadDataState() async {
    String source = "";
    FilePrefixData ts = FilePrefixData.empty();
    FilePrefixData tsRemote = FilePrefixData.empty();
    FilePrefixData tsLocal = FilePrefixData.empty();
    String fileData = "";
    final ssRemote = await DataLoad.fromHttpGet(_configData.getGetDataFileUrl(), timeoutMillis: _configData.getDataFetchTimeoutMillis());
    if (ssRemote.isSuccess) {
      tsRemote = DataLoad.readFilePrefixData(ssRemote.value);
      log("__INFO:__ Remote __TS:__ ${tsRemote.getTimeStamp()}");
      fileData = ssRemote.value.substring(tsRemote.startPos);
      source = "Remote";
      ts = tsRemote;
    } else {
      log(ssRemote.toLogString());
    }

    final ssLocal = DataLoad.loadFromFile(_configData.getDataFileLocal());
    if (ssLocal.isSuccess) {
      tsLocal = DataLoad.readFilePrefixData(ssLocal.value);
      log("__INFO:__ Local __TS:__ ${tsLocal.getTimeStamp()}");
      if (ssRemote.isFail || tsLocal.isLaterThan(tsRemote)) {
        fileData = ssLocal.value.substring(tsLocal.startPos);
        source = "Local";
        ts = tsLocal;
      }
    } else {
      log(ssLocal.toLogString());
    }

    if (ts.encrypted && _password.isEmpty) {
      setState(() {
        _globalSuccessState = SuccessState(false, message: "No Password Provided", log: log);
      });
      return;
    }

    if (fileData.isEmpty) {
      setState(() {
        _globalSuccessState = SuccessState(false, message: "No Data Available", log: log);
      });
      return;
    }

    final DataContainer data;
    try {
      data = DataContainer(fileData, ts, source, _password);
    } catch (r) {
      setState(() {
        _globalSuccessState = SuccessState(false, message: "Data file could not be parsed", exception: r as Exception, log: log);
      });
      return;
    }
    if (data.isEmpty) {
      setState(() {
        _globalSuccessState = SuccessState(false, message: "Data file does not contain any data", log: log);
      });
      return;
    }
    _loadedData = data;
    setState(() {
      _dataWasUpdated = false;
      _beforeDataLoaded = false;
      _treeNodeDataRoot = MyTreeNode.fromMap(_loadedData.dataMap);
      _treeNodeDataRoot.expandAll(true);
      _selectedPath = Path.fromDotPath(_loadedData.keys.first);
      _selectedTreeNode = _treeNodeDataRoot.findByPath(_selectedPath)!;
      _hiLightedPaths.clean();
      _globalSuccessState = SuccessState(true, message: "${ts.encrypted ? "Encrypted " : ""} ${_loadedData.source} File loaded: ${_loadedData.filePrefixData.getTimeStamp()}", log: log);
    });
  }

  void _handleAdd(Path path, String name, OptionsTypeData type) async {
    if (name.length < 2) {
      _globalSuccessState = SuccessState(false, message: "Name is too short");
      return;
    }
    final mapNode = DataLoad.findLastMapNodeForPath(_loadedData.dataMap, path);
    if (mapNode == null) {
      _globalSuccessState = SuccessState(false, message: "Path not found");
      return;
    }
    if (mapNode[name] != null) {
      _globalSuccessState = SuccessState(false, message: "Name already exists");
      return;
    }
    switch (type) {
      case optionTypeDataValue:
        setState(() {
          mapNode[name] = "undefined";
          _hiLightedPaths.add(path);
          _dataWasUpdated = true;
          _treeNodeDataRoot = MyTreeNode.fromMap(_loadedData.dataMap);
        });
        break;
      case optionTypeDataGroup:
        setState(() {
          final Map<String, dynamic> m = {};
          mapNode[name] = m;
          _hiLightedPaths.add(path);
          _dataWasUpdated = true;
          _treeNodeDataRoot = MyTreeNode.fromMap(_loadedData.dataMap);
        });
        break;
    }
    _globalSuccessState = SuccessState(true, message: "Node '$name' added", log: log);
  }

  void _handleTreeSelect(Path path) {
    setState(() {
      final n = _treeNodeDataRoot.findByPath(path);
      if (n == null) {
        _selectedPath = Path.fromDotPath(_loadedData.keys.first);
        _selectedTreeNode = _treeNodeDataRoot.findByPath(_selectedPath)!;
      } else {
        _selectedTreeNode = n;
        _selectedPath = path;
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
    final newName = "$newNameNoSuffix${newType.suffix}";
    final oldName = "${detailActionData.oldValue}${detailActionData.oldValueType.suffix}";

    if (oldName != newName) {
      if (newName.isEmpty) {
        return "Cannot be empty";
      }
      final mapNode = DataLoad.findLastMapNodeForPath(_loadedData.dataMap, detailActionData.path);
      if (mapNode == null) {
        return "Path not found";
      }
      if (detailActionData.value) {
        if (mapNode[newName] != null) {
          return "Name already exists";
        }
      } else {
        final pp = detailActionData.path.parentPath();
        final parentNode = DataLoad.findLastMapNodeForPath(_loadedData.dataMap, pp);
        if (parentNode == null) {
          return "Parent not found";
        }
        if (parentNode[newName] != null) {
          return "Name already exists";
        }
      }
    }
    return "";
  }

  void _handleRenameSubmit(DetailAction detailActionData, String newNameNoSuffix, OptionsTypeData newType) {
    final newName = "$newNameNoSuffix${newType.suffix}";
    final oldName = detailActionData.oldValue;
    if (oldName != newName) {
      setState(() {
        final mapNode = DataLoad.findLastMapNodeForPath(_loadedData.dataMap, detailActionData.path);
        if (mapNode == null) {
          _globalSuccessState = SuccessState(false, message: "Path not found");
          return;
        }
        if (detailActionData.value) {
          if (mapNode[newName] != null) {
            _globalSuccessState = SuccessState(false, message: "Name already exists");
            return;
          }
          final renameNode = mapNode[oldName];
          if (renameNode == null) {
            _globalSuccessState = SuccessState(false, message: "Name not found");
            return;
          }
          mapNode.remove(oldName);
          mapNode[newName] = renameNode;
        } else {
          if (newName.length <= 2) {
            _globalSuccessState = SuccessState(false, message: "New Name is too short");
            return;
          }
          final pp = detailActionData.path.parentPath();
          final parentNode = DataLoad.findLastMapNodeForPath(_loadedData.dataMap, pp);
          if (parentNode == null) {
            _globalSuccessState = SuccessState(false, message: "Parent not found");
            return;
          }
          if (parentNode[newName] != null) {
            _globalSuccessState = SuccessState(false, message: "Name already exists");
            return;
          }
          parentNode.remove(oldName);
          parentNode[newName] = mapNode;
        }
        detailActionData.path.pop();
        detailActionData.path.push(newName);
        _hiLightedPaths.add(detailActionData.path);
        _dataWasUpdated = true;
        _treeNodeDataRoot = MyTreeNode.fromMap(_loadedData.dataMap);
        _globalSuccessState = SuccessState(true, message: "Node '$oldName' renamed $newName", log: log);
      });
    }
  }

  void _handleDelete(Path path, String value, String response) async {
    if (response == "OK") {
      setState(() {
        final mapNode = DataLoad.findLastMapNodeForPath(_loadedData.dataMap, path);
        if (mapNode == null) {
          _globalSuccessState = SuccessState(false, message: "Path not found");
          return;
        } else {
          final pp = path.parentPath();
          final parentNode = DataLoad.findLastMapNodeForPath(_loadedData.dataMap, pp);
          if (parentNode == null) {
            _globalSuccessState = SuccessState(false, message: "Parent not found");
            return;
          }
          parentNode.remove(path.getLast());
          _dataWasUpdated = true;
          _treeNodeDataRoot = MyTreeNode.fromMap(_loadedData.dataMap);
          _globalSuccessState = SuccessState(true, message: "Removed: '${path.getLast()}'");
        }
      });
    }
  }

  void _handleEditSubmit(DetailAction detailActionData, String newValue, OptionsTypeData type) {
    if (detailActionData.oldValue != newValue || detailActionData.oldValueType != type) {
      setState(() {
        final mapNode = DataLoad.findLastMapNodeForPath(_loadedData.dataMap, detailActionData.path);
        if (mapNode == null) {
          _globalSuccessState = SuccessState(false, message: "Path not found");
          return;
        }
        final key = detailActionData.getLastPathElement();
        if (key == "") {
          _globalSuccessState = SuccessState(false, message: "Last element of Path was not found");
          return;
        }
        _dataWasUpdated = true;
        final nvTrim = newValue.trim();
        if (type.elementType == bool) {
          final lvTrimLc = nvTrim.toLowerCase();
          mapNode[key] = (lvTrimLc == "true" || lvTrimLc == "yes" || nvTrim == "1");
        } else {
          if (type.elementType == double || type.elementType == int) {
            try {
              final iv = int.parse(nvTrim);
              mapNode[key] = iv;
            } catch (e) {
              try {
                final dv = double.parse(nvTrim);
                mapNode[key] = dv;
              } catch (e) {
                mapNode[key] = nvTrim;
              }
            }
          } else {
            mapNode[key] = nvTrim;
          }
        }
        _hiLightedPaths.add(detailActionData.path);
        _treeNodeDataRoot = MyTreeNode.fromMap(_loadedData.dataMap);
        _globalSuccessState = SuccessState(true, message: "Item ${detailActionData.getLastPathElement()} updated");
      });
    }
  }

  Future<bool> _shouldExitHandler() async {
    if (_inExitProcess) {
      return false;
    }
    _inExitProcess = true;
    try {
      if (_dataWasUpdated) {
        await _showModalDialog(context, "Alert", ["Data has been updated", "Press OK to SAVE before Exit", "Press CANCEL remain in the App", "Press EXIT to leave without saving"], ["OK", "CANCEL", "EXIT"], null, null);
        if (_okCancelDialogResult == "OK") {
          await _saveDataState();
          return _globalSuccessState.isSuccess;
        }
        if (_okCancelDialogResult == "CANCEL") {
          setState(() {
            _globalSuccessState = SuccessState(true, message: "Exit Cancelled");
          });
          return false;
        }
      }
      return true;
    } finally {
      _inExitProcess = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    FlutterWindowClose.setWindowShouldCloseHandler(() async {
      return await _shouldExitHandler();
    });
    final DisplayData displayData = createSplitView(
      _loadedData.dataMap,
      _treeNodeDataRoot,
      _configData.getUserId(),
      _search,
      _selectedPath,
      _isEditDataDisplay,
      _configData.isDesktop(),
      _applicationState.screen.hDiv,
      _configData.getAppThemeData(),
      _hiLightedPaths,
      _handleTreeSelect, // On tree selection
      (divPos) {
        // On divider change
        if (_applicationState.updateDividerPosState(divPos)) {
          _applicationState.writeAppStateConfigFile(false);
        }
      },
      (searchCount) {
        // On search complete.
        if (searchCount > 0 && _previousSearch != _search) {
          _previousSearch = _search;
          _applicationState.addLastFind(_search, 5);
          _applicationState.writeAppStateConfigFile(false);
        }
      },
      (detailActionData) {
        // On selected detail page action
        debugPrint(detailActionData.toString());
        switch (detailActionData.action) {
          case ActionType.none:
            {
              return false;
            }
          case ActionType.delete:
            {
              _showModalDialog(context, "Remove item", ["${detailActionData.valueName} '${detailActionData.getLastPathElement()}'"], ["OK", "Cancel"], detailActionData.path, _handleDelete);
              return true;
            }
          case ActionType.select:
            {
              _handleTreeSelect(detailActionData.path);
              Future.delayed(
                const Duration(milliseconds: 300),
                () {
                  if (_selectedTreeNode != null) {
                    final index = (_selectedTreeNode.index -2) * _configData.getAppThemeData().treeNodeHeight;
                    _treeViewScrollController.animateTo(index, duration: const Duration(milliseconds: 400), curve: Curves.ease);
                  }
                },
              );
              return true;
            }
          case ActionType.renameStart:
            {
              final title = detailActionData.valueName;
              _showModalInputDialog(
                context,
                "Re-Name $title '${detailActionData.getLastPathElement()}'",
                detailActionData.getDisplayValue(false),
                detailActionData.value ? optionsForRenameElement : [],
                OptionsTypeData.locateTypeInOptionsList(detailActionData.oldValueType.key, optionsForRenameElement, optionTypeDataString),
                true,
                (action, text, type) {
                  if (action == "OK") {
                    _handleRenameSubmit(detailActionData, text, type);
                  }
                },
                (initial, value, initialType, valueType) {
                  //
                  // Validate a re-name
                  //
                  return _checkRenameOk(detailActionData, value, valueType);
                },
              );
              return true;
            }
          case ActionType.editStart:
            {
              _showModalInputDialog(
                context,
                "Update Value '${detailActionData.getLastPathElement()}'",
                detailActionData.oldValue,
                optionsForUpdateElement,
                detailActionData.oldValueType,
                false,
                (action, text, type) {
                  if (action == "OK") {
                    _handleEditSubmit(detailActionData, text, type);
                  } else {
                    if (action == "link") {
                      implementLinkState(text, detailActionData.path.getLast());
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
              return true;
            }
          case ActionType.link:
            {
              implementLinkState(detailActionData.oldValue, detailActionData.path.getLast());
              return true;
            }
          default:
            {
              return false;
            }
        }
      },
      (buildContext, node) {
        // BuildNode
        nodeContextList[node.key] = buildContext;
        return MyTreeWidget(node.key, node.label, buildContext);
      },
      log,
    );
    _treeViewScrollController = displayData.scrollController;

    final List<Widget> toolBarItems = List.empty(growable: true);
    toolBarItems.add(
      DetailIconButton(
        icon: const Icon(Icons.close_outlined),
        tooltip: 'Exit application',
        onPressed: () async {
          final close = await _shouldExitHandler();
          if (close) {
            closer(0);
          }
        },
        appThemeData: _configData.getAppThemeData(),
      ),
    );

    if (_beforeDataLoaded) {
      toolBarItems.add(Container(
        color: _configData.getAppThemeData().primary.shade400,
        child: SizedBox(
          width: MediaQuery.of(context).size.width / 3,
          child: TextField(
            style: _configData.getAppThemeData().tsLarge,
            decoration: const InputDecoration(
              hintText: 'Password',
            ),
            autofocus: true,
            onSubmitted: (value) {
              _password = value;
              textEditingController.text = "";
              _loadDataState();
            },
            obscureText: true,
            controller: textEditingController,
            cursorColor: const Color(0xff000000),
          ),
        ),
      ));
      toolBarItems.add(DetailIconButton(
        appThemeData: _configData.getAppThemeData(),
        icon: const Icon(iconDataFileLoad),
        tooltip: 'Load Data',
        timerMs: 5000,
        onPressed: () {
          _password = textEditingController.text;
          textEditingController.text = "";
          _loadDataState();
        },
      ));
    } else {
      //
      // Data is loaded
      //
      toolBarItems.add(
        DetailIconButton(
          show: !_beforeDataLoaded,
          appThemeData: _configData.getAppThemeData(),
          icon: _isEditDataDisplay ? const Icon(Icons.remove_red_eye) : const Icon(Icons.edit),
          tooltip: _isEditDataDisplay ? 'Stop Editing' : "Start Editing",
          onPressed: () {
            setState(() {
              _isEditDataDisplay = !_isEditDataDisplay;
            });
          },
        ),
      );
      if (_dataWasUpdated || _isEditDataDisplay) {
        toolBarItems.add(
          DetailIconButton(
            icon: const Icon(Icons.save),
            tooltip: _loadedData.hasPassword ? "Save ENCRYPTED" : 'Save Data',
            onPressed: () {
              _saveDataState();
            },
            appThemeData: _configData.getAppThemeData(),
          ),
        );
        toolBarItems.add(
          DetailIconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload Data',
            onPressed: () {
              _loadDataState();
            },
            appThemeData: _configData.getAppThemeData(),
          ),
        );
      }
      if (_isEditDataDisplay) {
        toolBarItems.add(DetailIconButton(
          appThemeData: _configData.getAppThemeData(),
          icon: const Icon(Icons.add_box_outlined),
          tooltip: 'Add Value or Group',
          onPressed: () {
            _showModalInputDialog(
              context,
              "Add To: '${_selectedPath.getLast()}'",
              "",
              optionsForAddElement,
              optionTypeDataValue,
              true,
              (action, text, type) {
                if (action == "OK") {
                  _handleAdd(_selectedPath, text, type);
                }
              },
              (initial, value, initialType, valueType) {
                return value.trim().isEmpty ? "Cannot be empty" : "";
              },
            );
          },
        ));
      } else {
        toolBarItems.add(
          Container(
            color: _configData.getAppThemeData().primary.shade400,
            child: SizedBox(
              width: MediaQuery.of(context).size.width / 3,
              child: TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Search',
                ),
                autofocus: true,
                onSubmitted: (value) {
                  _setSearchExpressionState(value);
                },
                controller: textEditingController,
                cursorColor: const Color(0xff000000),
              ),
            ),
          ),
        );
        toolBarItems.add(
          DetailIconButton(
            appThemeData: _configData.getAppThemeData(),
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () {
              _setSearchExpressionState(textEditingController.text);
            },
          ),
        );
        toolBarItems.add(
          DetailIconButton(
            appThemeData: _configData.getAppThemeData(),
            icon: const Icon(Icons.youtube_searched_for),
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
            icon: const Icon(Icons.search_off),
            tooltip: 'Clear Search',
            onPressed: () {
              _setSearchExpressionState("");
            },
          ),
        );
      }
    }

    final settings = Positioned(
        left: MediaQuery.of(context).size.width - appBarHeight,
        top: 0,
        child: DetailIconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'Settings',
          onPressed: () {
            _showConfigDialog(
              context,
              _configData.getAppThemeData(),
              _configData.getConfigFileName(),
              (validValue, detail) {
                // Validate
                return "";
              },
              (settingsControl) {
                // Commit
                log("__SETTINGS:__ ${settingsControl.detail.path} Type:${settingsControl.detail.valueType} Value:'${settingsControl.value}'");
                final msg = DataLoad.setValueForJsonPath(_configData.getJson(), settingsControl.detail.path, settingsControl.value);
                setState(() {
                  _configData.update();
                });
                return msg;
              },
              () {
                // Save
                setState(() {
                  _globalSuccessState = _configData.save(log);
                });
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
    return Scaffold(
      body: SingleChildScrollView(
          child: Stack(
        children: [
          Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              // Center is a layout widget. It takes a single child and positions it
              // in the middle of the parent.
              children: [
                Container(
                  height: appBarHeight,
                  color: _configData.getAppThemeData().primary.shade500,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: toolBarItems),
                ),
                Container(
                  height: MediaQuery.of(context).size.height - (appBarHeight + statusBarHeight),
                  color: _configData.getAppThemeData().primary.shade500,
                  child: displayData.splitView,
                ),
                Container(
                  height: 1,
                  color: Colors.black,
                ),
                Container(
                  height: statusBarHeight,
                  color: _globalSuccessState.isSuccess ? _configData.getAppThemeData().primary.shade500 : _configData.getAppThemeData().error.shade500,
                  child: Row(
                    children: [
                      DetailIconButton(
                        appThemeData: _configData.getAppThemeData(),
                        icon: const Icon(
                          Icons.view_timeline,
                          size: statusBarHeight,
                        ),
                        tooltip: 'Log',
                        padding: const EdgeInsets.fromLTRB(1, 1, 1, 0),
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
      )),
    );
  }
}

Future<void> _showConfigDialog(final BuildContext context, AppThemeData appThemeData, final String fileName, final String Function(dynamic, SettingDetail) validate, final String Function(SettingControl) commit, final Function() saveConfig) async {
  List<SettingControl>? controlList = _configData.createSettingsControlList();
  return showDialog<void>(
    context: context,
    barrierColor: _configData.getPrimaryColour().shade300,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: _configData.getPrimaryColour().shade600,
        title: Text("Settings:", style: appThemeData.tsLarge),
        content: SizedBox(
          height: MediaQuery.of(context).size.height - (appBarHeight + statusBarHeight + inputTextTitleStyleHeight + 100),
          width: MediaQuery.of(context).size.width,
          child: SingleChildScrollView(
              child: Column(
            children: _configData.getSettingsWidgets(null, appThemeData, controlList, (value, detail) {
              return "";
            }),
          )),
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Save', style: _configData.getAppThemeData().tsMedium),
            onPressed: () {
              if (controlList.isNotEmpty) {
                int count = 0;
                for (final c in controlList) {
                  if (c.changed) {
                    commit(c);
                    count++;
                  }
                }
                if (count > 0) {
                  saveConfig();
                }
              }
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text('Close', style: _configData.getAppThemeData().tsMedium),
            onPressed: () {
              if (controlList.isNotEmpty) {
                for (final c in controlList) {
                  if (c.changed) {
                    commit(c);
                  }
                }
              }
              Navigator.of(context).pop();
            },
          ),
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
        backgroundColor: _configData.getAppThemeData().primary.shade300,
        title: Text('Event Log', style: _configData.getAppThemeData().tsMedium),
        content: SingleChildScrollView(
            child: Container(
          color: _configData.getAppThemeData().primary.shade100,
          height: MediaQuery.of(context).size.height - (appBarHeight + statusBarHeight + inputTextTitleStyleHeight + 100),
          width: MediaQuery.of(context).size.width,
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
        backgroundColor: _configData.getPrimaryColour().shade300,
        title: Text('Previous Searches', style: _configData.getAppThemeData().tsMedium),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Container(
                height: 1,
                color: Colors.black,
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
                  color: Colors.black,
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

Future<void> _showModalDialog(final BuildContext context, final String title, final List<String> texts, final List<String> buttons, final Path? action, final void Function(Path, String, String)? onAction) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: _configData.getPrimaryColour().shade300,
        title: Text(title, style: _configData.getAppThemeData().tsMedium),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              for (int i = 0; i < texts.length; i++) ...[
                (texts[i].startsWith('#')) ? Container(alignment: Alignment.center, color: _configData.getPrimaryColour().shade500, child: Text(texts[i].substring(1), style: _configData.getAppThemeData().tsMedium)) : Text(texts[i], style: _configData.getAppThemeData().tsMedium),
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
                    if (onAction != null && action != null) {
                      onAction(action, "", buttons[i].toUpperCase());
                    } else {
                      _okCancelDialogResult = buttons[i].toUpperCase();
                    }
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

Future<void> _showModalInputDialog(final BuildContext context, final String title, final String currentValue, final List<OptionsTypeData> options, final OptionsTypeData currentOption, final bool isRename, final void Function(String, String, OptionsTypeData) onAction, final String Function(String, String, OptionsTypeData, OptionsTypeData) externalValidate) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: _configData.getPrimaryColour().shade300,
        title: SizedBox(height: inputTextTitleStyleHeight, child: Text(title, style: _configData.getAppThemeData().tsMedium)),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              (currentOption == optionTypeDataMarkDown && !isRename)
                  ? MarkDownInputField(
                      appThemeData: _configData.getAppThemeData(),
                      initialText: currentValue,
                      onClose: (action, text, type) {
                        onAction(action, text, type);
                        Navigator.of(context).pop();
                      },
                      height: MediaQuery.of(context).size.height - (appBarHeight + statusBarHeight + inputTextTitleStyleHeight + 100),
                      width: MediaQuery.of(context).size.width,
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
                        onAction(detailAction.action.name, detailAction.oldValue, OptionsTypeData.forTypeOrName(String, "link"));
                        return true;
                      },
                    )
                  : ValidatedInputField(
                      options: options,
                      initialOption: currentOption,
                      prompt: "Input: ${isRename ? "New Name" : "[type]"}",
                      initialValue: currentValue,
                      appThemeData: _configData.getAppThemeData(),
                      onClose: (action, text, type) {
                        onAction(action, text, type);
                        Navigator.of(context).pop();
                      },
                      onValidate: (ix, vx, it, vt) {
                        return externalValidate(ix.trim(), vx.trim(), it, vt);
                      },
                    ),
            ],
          ),
        ),
      );
    },
  );
}
