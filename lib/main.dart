import 'dart:io';
import 'package:data_repo/data_load.dart';
import 'package:flutter/material.dart';
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
late final AppColours _appColours;
late final ApplicationState _applicationState;

StringBuffer eventLog = StringBuffer();
String eventLogLatest = "";

String _okCancelDialogResult = "";
bool _inExitProcess = false;
final PathList _hiLightedPaths = PathList();
final TextEditingController textEditingController = TextEditingController(text: "");

const encDataPrefixMagic = "4rg7:";
const appBarHeight = 50.0;
const statusBarHeight = 35.0;
const inputTextTitleStyleHeight = 35.0;
const iconDataFileLoad = Icons.file_open;
const dialogTextStyle = TextStyle(fontFamily: 'Code128', fontSize: 25.0, color: Colors.black);
const dialogButtonStyle = TextStyle(fontFamily: 'Code128', fontSize: 25.0, color: Colors.blue);
const statusTextStyle = TextStyle(fontFamily: 'Code128', fontSize: 20.0, color: Colors.black);
const headingTextStyle = TextStyle(fontFamily: 'Code128', fontSize: 20.0, color: Colors.black);
const inputTextTitleStyle = TextStyle(fontFamily: 'Code128', fontSize: 30.0, color: Colors.black);

bool _shouldDisplayMarkdownHelp = false;
bool _shouldDisplayMarkdownPreview = false;

void closer(int returnCode) async {
  exit(returnCode);
}

bool implementLink(String href) {
  debugPrint("LINK to $href. Simples!");
  return true;
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
    final path = await ApplicationState.getAppPath();
    final isDesktop = ApplicationState.appIsDesktop();
    log("${isDesktop ? "__START:__ Desktop" : "__Mobile__"} App");
    log("__PATH:__ $path");
    _configData = ConfigData(path, "config.json", isDesktop, log);
    _applicationState = await ApplicationState.readAppStateConfigFile(_configData.getAppStateFileLocal(), log);
    _appColours = _configData.getAppColours();
    if (isDesktop) {
      setWindowTitle("${_configData.getTitle()}: ${_configData.getUserName()}");
      const WindowOptions(
        minimumSize: Size(200, 200),
        titleBarStyle: TitleBarStyle.normal,
      );
      setWindowFrame(Rect.fromLTWH(_applicationState.screen.x, _applicationState.screen.y, _applicationState.screen.w, _applicationState.screen.h));
    }
  } catch (e) {
    stderr.writeln(e);
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
            if (_applicationState.updateScreen(info.frame.left, info.frame.top, info.frame.width, info.frame.height)) {
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
      theme: ThemeData(primarySwatch: _appColours.primary),
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
  String _expand = _configData.getUserName();
  String _search = "";
  String _previousSearch = "";
  Path _selected = Path.empty();
  bool _beforeDataLoaded = true;
  bool _dataWasUpdated = false;
  bool _isEditDataDisplay = false;
  SuccessState _globalSuccessState = SuccessState(true);
  DataContainer _loadedData = DataContainer.empty();

  void _setSearchExpressionState(String st) {
    if (st == _search) {
      return;
    }
    setState(() {
      textEditingController.text = st;
      _search = st;
    });
  }

  Future<void> _saveDataState(String pw) async {
    final String content = _loadedData.dataAsString;
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

  void _loadDataState(String pw) async {
    if (pw == "") {
      setState(() {
        _globalSuccessState = SuccessState(false, message: "Password was not provided", log: log);
      });
      return;
    }

    String source = "";
    int ts = -1;
    int tsRemote = -1;
    int tsLocal = -1;
    String fileData = "";
    final ssRemote = await DataLoad.fromHttpGet(_configData.getDataFileUrl(), timeoutMillis: _configData.getDataFetchTimeoutMillis());
    if (ssRemote.isSuccess) {
      tsRemote = DataLoad.timeStampFromString(ssRemote.value);
      log("__INFO:__ Remote __TS:__ ${DateTime.fromMillisecondsSinceEpoch(tsRemote)}");
      fileData = ssRemote.value;
      source = "Remote";
      ts = tsRemote;
    } else {
      log(ssRemote.toLogString());
    }

    final ssLocal = DataLoad.loadFromFile(_configData.getDataFileLocal());
    if (ssLocal.isSuccess) {
      tsLocal = DataLoad.timeStampFromString(ssLocal.value);
      log("__INFO:__ Local __TS:__ ${DateTime.fromMillisecondsSinceEpoch(tsLocal)}");
      if (tsLocal > tsRemote) {
        fileData = ssLocal.value;
        source = "Local";
        ts = tsLocal;
      }
    } else {
      log(ssLocal.toLogString());
    }

    if (fileData.isEmpty) {
      setState(() {
        _globalSuccessState = SuccessState(false, message: "No Data Available", log: log);
      });
      return;
    }

    final DataContainer data;
    try {
      data = DataContainer(fileData, encDataPrefixMagic, ts, source, password: _password);
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
    data.dataMap.remove(timeStampId);
    _loadedData = data;
    setState(() {
      _password = pw;
      _dataWasUpdated = false;
      _beforeDataLoaded = false;
      _selected = Path.fromDotPath(_loadedData.keys.first);
      _hiLightedPaths.clean();
      _globalSuccessState = SuccessState(true, message: "${_loadedData.source} File loaded: ${_loadedData.timeStampToString()}", log: log);
    });
  }

  void _handleAdd(Path path, String name, OptionsTypeData type) async {
    debugPrint("SS:_handleAdd");
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
          debugPrint("SS:_handleAdd:value");
          mapNode[name] = "undefined";
          _hiLightedPaths.add(path);
          _dataWasUpdated = true;
        });
        break;
      case optionTypeDataGroup:
        setState(() {
          debugPrint("SS:_handleAdd:group");
          final Map<String, dynamic> m = {};
          mapNode[name] = m;
          _hiLightedPaths.add(path);
          _dataWasUpdated = true;
        });
        break;
    }
    _globalSuccessState = SuccessState(true, message: "Node '$name' added", log: log);
  }

  void _handleTreeSelect(String dotPath) {
    final path = Path.fromDotPath(dotPath);
    setState(() {
      debugPrint("SS:_handleTreeSelect");
      if (path.isNotEmpty()) {
        _expand = path.getRoot();
      }
      _selected = path;
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
    final oldName = "${detailActionData.oldValue}${detailActionData.oldValueType.suffix}";
    if (oldName != newName) {
      setState(() {
        debugPrint("SS:_handleRenameSubmit");
        final mapNode = DataLoad.findLastMapNodeForPath(_loadedData.dataMap, detailActionData.path);
        if (mapNode == null) {
          _globalSuccessState = SuccessState(false, message: "Path not found");
        }
        if (detailActionData.value) {
          if (mapNode![newName] != null) {
            _globalSuccessState = SuccessState(false, message: "Name already exists");
          }
          final renameNode = mapNode[oldName];
          if (renameNode == null) {
            _globalSuccessState = SuccessState(false, message: "Name not found");
          }

          mapNode.remove(oldName);
          mapNode[newName] = renameNode;
          _dataWasUpdated = true;
          detailActionData.path.pop();
          detailActionData.path.push(newName);
          _hiLightedPaths.add(detailActionData.path);
        } else {
          if (newName.length <= 2) {
            _globalSuccessState = SuccessState(false, message: "New Name is too short");
          }
          final pp = detailActionData.path.parentPath();
          final parentNode = DataLoad.findLastMapNodeForPath(_loadedData.dataMap, pp);
          if (parentNode == null) {
            _globalSuccessState = SuccessState(false, message: "Parent not found");
          }
          if (parentNode![newName] != null) {
            _globalSuccessState = SuccessState(false, message: "Name already exists");
          }
          parentNode.remove(oldName);
          parentNode[newName] = mapNode;
          _dataWasUpdated = true;
          detailActionData.path.pop();
          detailActionData.path.push(newName);
          _hiLightedPaths.add(detailActionData.path);
          _globalSuccessState = SuccessState(true, message: "Item renamed");
        }
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
        } else {
          final pp = path.parentPath();
          final parentNode = DataLoad.findLastMapNodeForPath(_loadedData.dataMap, pp);
          if (parentNode == null) {
            _globalSuccessState = SuccessState(false, message: "Parent not found");
          }
          parentNode?.remove(path.getLast());
          _dataWasUpdated = true;
          _globalSuccessState = SuccessState(true, message: "Removed: '${path.getLast()}'");
        }
        _globalSuccessState = SuccessState(true, message: "Node '${path.getLast()}' removed", log: log);
      });
    }
  }

  void _handleEditSubmit(DetailAction detailActionData, String newValue, OptionsTypeData type) {
    if (detailActionData.oldValue != newValue || detailActionData.oldValueType != type) {
      setState(() {
        debugPrint("SS:_handleEditSubmit (${detailActionData.oldValueType})");
        final mapNode = DataLoad.findLastMapNodeForPath(_loadedData.dataMap, detailActionData.path);
        if (mapNode == null) {
          _globalSuccessState = SuccessState(false, message: "Path not found");
        }
        final key = detailActionData.getLastPathElement();
        if (key == "") {
          _globalSuccessState = SuccessState(false, message: "Last element of Path was not found");
        }
        debugPrint("SS:_handleEditSubmit (${detailActionData.oldValueType})");
        _dataWasUpdated = true;
        final nvTrim = newValue.trim();
        if (type.elementType == bool) {
          final lvTrimLc = nvTrim.toLowerCase();
          mapNode![key] = (lvTrimLc == "true" || lvTrimLc == "yes" || nvTrim == "1");
        } else {
          if (type.elementType == double || type.elementType == int) {
            try {
              final iv = int.parse(nvTrim);
              mapNode![key] = iv;
            } catch (e) {
              try {
                final dv = double.parse(nvTrim);
                mapNode![key] = dv;
              } catch (e) {
                mapNode![key] = nvTrim;
              }
            }
          } else {
            mapNode![key] = nvTrim;
          }
        }
        _hiLightedPaths.add(detailActionData.path);
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
          await _saveDataState(_password);
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
      _configData.getUserId(),
      _search,
      _expand,
      _selected,
      _isEditDataDisplay,
      _configData.isDesktop(),
      _applicationState.screen.hDiv,
      _appColours,
      _hiLightedPaths,
      _handleTreeSelect, // On tree selection
      (divPos) {
        // On divider change
        if (_applicationState.updateDividerPos(divPos)) {
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
              setState(() {
                _selected = detailActionData.path;
              });
              return true;
            }
          case ActionType.renameStart:
            {
              final title = detailActionData.valueName;
              _showModalInputDialog(
                context,
                "Re-Name $title '${detailActionData.getLastPathElement()}'",
                detailActionData.oldValue,
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
              return implementLink(detailActionData.oldValue);
            }
          default:
            {
              return false;
            }
        }
      },
      log,
    );

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
        appColours: _appColours,
      ),
    );

    if (_beforeDataLoaded) {
      toolBarItems.add(Container(
        color: _appColours.primary.shade400,
        child: SizedBox(
          width: MediaQuery.of(context).size.width / 3,
          child: TextField(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Password',
            ),
            autofocus: true,
            onSubmitted: (value) {
              _loadDataState(value);
            },
            obscureText: true,
            controller: textEditingController,
            cursorColor: const Color(0xff000000),
          ),
        ),
      ));
      toolBarItems.add(DetailIconButton(
        appColours: _appColours,
        icon: const Icon(iconDataFileLoad),
        tooltip: 'Load Data',
        timerMs: 5000,
        onPressed: () {
          _loadDataState("to-do ${textEditingController.text}");
        },
      ));
    } else {
      //
      // Data is loaded
      //

      if (_dataWasUpdated) {
        toolBarItems.add(
          DetailIconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save Data',
            onPressed: () {
              _saveDataState(_password);
            },
            appColours: _appColours,
          ),
        );
        toolBarItems.add(
          DetailIconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload Data',
            onPressed: () {
              _loadDataState(_password);
            },
            appColours: _appColours,
          ),
        );
      }
      toolBarItems.add(
        DetailIconButton(
          show: !_beforeDataLoaded,
          appColours: _appColours,
          icon: _isEditDataDisplay ? const Icon(Icons.remove_red_eye) : const Icon(Icons.edit),
          tooltip: _isEditDataDisplay ? 'Stop Editing' : "Start Editing",
          onPressed: () {
            setState(() {
              _isEditDataDisplay = !_isEditDataDisplay;
            });
          },
        ),
      );
      if (_isEditDataDisplay) {
        toolBarItems.add(DetailIconButton(
          appColours: _appColours,
          icon: const Icon(Icons.add_box_outlined),
          tooltip: 'Add',
          onPressed: () {
            _showModalInputDialog(
              context,
              "Add To: '${_selected.getLast()}'",
              "",
              optionsForAddElement,
              optionTypeDataValue,
              true,
              (action, text, type) {
                if (action == "OK") {
                  _handleAdd(_selected, text, type);
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
            color: _appColours.primary.shade400,
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
            appColours: _appColours,
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () {
              _setSearchExpressionState(textEditingController.text);
            },
          ),
        );
        toolBarItems.add(
          DetailIconButton(
            appColours: _appColours,
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
            appColours: _appColours,
            icon: const Icon(Icons.search_off),
            tooltip: 'Clear Search',
            onPressed: () {
              _setSearchExpressionState("");
            },
          ),
        );
      }
    }

    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      body: SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              // Center is a layout widget. It takes a single child and positions it
              // in the middle of the parent.
              children: [
            Container(
              height: appBarHeight,
              color: _appColours.primary.shade500,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: toolBarItems),
            ),
            Container(
              height: MediaQuery.of(context).size.height - (appBarHeight + statusBarHeight),
              color: _appColours.primary.shade500,
              child: displayData.splitView,
            ),
            Container(
              height: statusBarHeight,
              color: _globalSuccessState.isSuccess ? _appColours.primary.shade500 : _appColours.error.shade900,
              child: Row(
                children: [
                  DetailIconButton(
                    appColours: _appColours,
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
                    style: statusTextStyle,
                  )
                ],
              ),
            ),
          ])),
    );
  }
}

Future<void> _showLogDialog(final BuildContext context, final String log) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Event Log', style: dialogButtonStyle),
        content: SingleChildScrollView(
            child: SizedBox(
          height: MediaQuery.of(context).size.height - (appBarHeight + statusBarHeight + inputTextTitleStyleHeight + 100),
          width: MediaQuery.of(context).size.width,
          child: Markdown(
            data: log,
            selectable: true,
            shrinkWrap: true,
            styleSheetTheme: MarkdownStyleSheetBaseTheme.platform,
          ),
        )),
        actions: <Widget>[
          TextButton(
            child: const Text('OK', style: dialogButtonStyle),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
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
        title: const Text('Previous Searches', style: dialogButtonStyle),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              for (int i = 0; i < prevList.length; i++) ...[
                TextButton(
                  child: Text(prevList[i], style: dialogTextStyle),
                  onPressed: () {
                    onSelect(prevList[i]);
                    Navigator.of(context).pop();
                  },
                ),
              ]
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel', style: dialogButtonStyle),
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
        backgroundColor: _appColours.primary.shade300,
        title: Text(title, style: dialogTextStyle),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              for (int i = 0; i < texts.length; i++) ...[
                (texts[i].startsWith('#')) ? Container(alignment: Alignment.center, color: _appColours.primary.shade500, child: Text(texts[i].substring(1), style: dialogTextStyle)) : Text(texts[i], style: dialogTextStyle),
              ]
            ],
          ),
        ),
        actions: <Widget>[
          Row(
            children: [
              for (int i = 0; i < buttons.length; i++) ...[
                DetailButton(
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
        backgroundColor: _appColours.primary.shade300,
        title: SizedBox(height: inputTextTitleStyleHeight, child: Text(title, style: inputTextTitleStyle)),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              (currentOption == optionTypeDataMarkDown && !isRename)
                  ? MarkDownInputField(
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
                      dataAction: (action) {
                        return implementLink(action.oldValue);
                      },
                      appColours: _appColours,
                    )
                  : ValidatedInputField(
                      options: options,
                      initialOption: currentOption,
                      prompt: "Input: ${isRename ? "New Name" : "[type]"}",
                      initialValue: currentValue,
                      appColours: _appColours,
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
