import 'dart:io';
import 'package:data_repo/data_load.dart';
import 'package:flutter/material.dart';
import 'package:window_size/window_size.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_window_close/flutter_window_close.dart';
import 'detail_widget.dart';
import 'encrypt.dart';
import 'path.dart';
import 'config.dart';
import 'main_view.dart';
import 'detail_buttons.dart';

late final ConfigData _configData;
late final ApplicationState _applicationState;

String _okCancelDialogResult = "";
bool _inExitProcess = false;
final PathList _hiLightedPaths = PathList();
final TextEditingController textEditingController = TextEditingController(text: "");

const appBarHeight = 50.0;
const statusBarHeight = 35.0;
const iconDataFileLoad = Icons.file_open;
const dialogTextStyle = TextStyle(fontFamily: 'Code128', fontSize: 25.0, color: Colors.black);
const dialogButtonStyle = TextStyle(fontFamily: 'Code128', fontSize: 25.0, color: Colors.blue);
const statusTextStyle = TextStyle(fontFamily: 'Code128', fontSize: 20.0, color: Colors.black);
const inputTextStyle = TextStyle(fontFamily: 'Code128', fontSize: 30.0, color: Colors.black);

void closer(int returnCode) async {
  exit(returnCode);
}

void main() async {
  try {
    _configData = ConfigData("config.json");
    _applicationState = await ApplicationState.readFromFile(_configData.getStateFileLocal());
    WidgetsFlutterBinding.ensureInitialized();
    if (_applicationState.isDesktop()) {
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
          if (_applicationState.isDesktop()) {
            final info = await getWindowInfo();
            if (_applicationState.updateScreen(info.frame.left, info.frame.top, info.frame.width, info.frame.height)) {
              await _applicationState.writeToFile(false);
            }
          }
          break;
        }
      default:
        {
          print("Event:$eventName");
        }
    }
    super.onWindowEvent(eventName);
  }

  @override
  Widget build(BuildContext context) {
    if (_applicationState.isDesktop()) {
      windowManager.addListener(this);
    }
    return MaterialApp(
      title: 'data_repo',
      theme: ThemeData(primarySwatch: _configData.getMaterialColor()),
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
  bool _isPasswordInput = true;
  bool _dataWasUpdated = false;
  SuccessState _globalSuccessState = SuccessState(true);
  Map<String, dynamic> _loadedData = {};

  void _setSearchExpressionState(String st) {
    if (st == _search) {
      return;
    }
    setState(() {
      debugPrint("SS:_setSearchExpressionState");
      textEditingController.text = st;
      _search = st;
    });
  }

  void _saveDataState(String pw) {
    setState(() {
      debugPrint("SS:_saveDataState");
      final ss = DataLoad.saveToFile(_configData.getDataFileLocal(), _loadedData);
      if (ss.isSuccess) {
        _dataWasUpdated = false;
        _hiLightedPaths.clean();
      }
      _globalSuccessState = ss;
    });
  }

  void _loadDataState(String pw) {
    if (pw == "") {
      setState(() {
        debugPrint("SS:_loadDataState 1");
        _globalSuccessState = SuccessState(false, message: "Password was not provided");
      });
      return;
    }
    final ss = DataLoad.loadFromFile(_configData.getDataFileLocal());
    if (ss.isFail) {
      setState(() {
        debugPrint("SS:_loadDataState 2");
        _globalSuccessState = ss;
      });
      return;
    }
    Map<String, dynamic> data;
    try {
      data = DataLoad.jsonFromString(ss.value);
    } catch (r) {
      setState(() {
        debugPrint("SS:_loadDataState 2");
        _globalSuccessState = SuccessState(false, message: "Data file could not be parsed", exception: r as Exception);
      });
      return;
    }
    setState(() {
      debugPrint("SS:_loadDataState 4");
      if (data.isEmpty) {
        _globalSuccessState = SuccessState(false, message: "Data file does not contain any data");
        return;
      }
      if (data[_configData.getUserId()] == null) {
        _globalSuccessState = SuccessState(false, message: "Data file does not contain the users data");
        return;
      }
      _password = pw;
      _dataWasUpdated = false;
      _isPasswordInput = false;
      _loadedData = data;
      _selected = Path.fromDotPath(_loadedData.keys.first);
      _hiLightedPaths.clean();
    });
  }

  void _handleAddSubmitState(DetailAction detailActionData, String newValue) {
    setState(() {
      debugPrint("SS:_handleAddSubmitState");
      if (newValue.length < 2) {
        _globalSuccessState = SuccessState(false, message: "Name is too short");
        return;
      }
      final mapNode = DataLoad.findLastMapNodeForPath(_loadedData, detailActionData.path);
      if (mapNode == null) {
        _globalSuccessState = SuccessState(false, message: "Path not found");
        return;
      }
      if (mapNode[newValue] != null) {
        _globalSuccessState = SuccessState(false, message: "Name already exists");
        return;
      }
      _dataWasUpdated = true;
      if (detailActionData.value) {
        debugPrint("SS:_handleAddSubmitState:value");
        mapNode[newValue] = "";
      } else {
        debugPrint("SS:_handleAddSubmitState:group");
        mapNode[newValue] = {};
      }
      _hiLightedPaths.add(detailActionData.path);
      _globalSuccessState = SuccessState(true, message: "Item updated");
    });
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

  void _handleRenameSubmit(DetailAction detailActionData, String newName) {
    if (detailActionData.oldValue != newName) {
      setState(() {
        debugPrint("SS:_handleRenameSubmit");
        final mapNode = DataLoad.findLastMapNodeForPath(_loadedData, detailActionData.path);
        if (mapNode == null) {
          _globalSuccessState = SuccessState(false, message: "Path not found");
        }
        if (detailActionData.value) {
          if (mapNode![newName] != null) {
            _globalSuccessState = SuccessState(false, message: "Value already exists");
          }
          final renameNode = mapNode[detailActionData.oldValue];
          if (renameNode == null) {
            _globalSuccessState = SuccessState(false, message: "Value not found");
          }
          mapNode.remove(detailActionData.oldValue);
          mapNode[newName] = renameNode;
          _dataWasUpdated = true;
          detailActionData.path.pop();
          detailActionData.path.push(newName);
          _hiLightedPaths.add(detailActionData.path);
        } else {
          if (newName.length <= 2) {
            _globalSuccessState = SuccessState(false, message: "New value is too short");
          }
          final pp = detailActionData.path.parentPath();
          final parentNode = DataLoad.findLastMapNodeForPath(_loadedData, pp);
          if (parentNode == null) {
            _globalSuccessState = SuccessState(false, message: "Parent not found");
          }
          if (parentNode![newName] != null) {
            _globalSuccessState = SuccessState(false, message: "Value already exists");
          }
          parentNode.remove(detailActionData.oldValue);
          parentNode[newName] = mapNode;
          _dataWasUpdated = true;
          detailActionData.path.pop();
          detailActionData.path.push(newName);
          _hiLightedPaths.add(detailActionData.path);
          _globalSuccessState = SuccessState(true, message: "Item renamed");
        }
      });
    }
  }

  void _handleEditSubmit(DetailAction detailActionData, String newValue, String type) {
    if (detailActionData.oldValue != newValue) {
      setState(() {
        final mapNode = DataLoad.findLastMapNodeForPath(_loadedData, detailActionData.path);
        if (mapNode == null) {
          _globalSuccessState = SuccessState(false, message: "Path not found");
        }
        final key = detailActionData.getLastPathElement();
        if (key == "") {
          _globalSuccessState = SuccessState(false, message: "Last element of Path was not found");
        }
        debugPrint("SS:_handleEditSubmit (${detailActionData.oldValueType})");
        _dataWasUpdated = true;
        if (type == "double") {
          mapNode![key] = double.parse(newValue);
        } else {
          if (type == "int") {
            mapNode![key] = int.parse(newValue);
          } else {
            mapNode![key] = newValue;
          }
        }
        _hiLightedPaths.add(detailActionData.path);
        _globalSuccessState = SuccessState(true, message: "Item updated");
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
        await _showModalDialog(context, ["Data has been updated", "Press OK to SAVE before Exit", "Press CANCEL remain in the App", "Press EXIT to leave without saving"], ["OK", "CANCEL", "EXIT"]);
        if (_okCancelDialogResult == "OK") {
          _saveDataState(_password);
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
    debugPrint("BB:build");

    final DisplayData displayData = createSplitView(
      _loadedData,
      _configData.getUserId(),
      _search,
      _expand,
      _selected,
      _applicationState.isDesktop(),
      _applicationState.screen.hDiv,
      _configData.getMaterialColor(),
      _hiLightedPaths,
      _handleTreeSelect,
      (divPos) {
        //
        if (_applicationState.updateDividerPos(divPos)) {
          _applicationState.writeToFile(false);
        }
      },
      (searchCount) {
        // On Search complete
        if (searchCount > 0 && _previousSearch != _search) {
          _previousSearch = _search;
          _applicationState.addLastFind(_search, 5);
          _applicationState.writeToFile(false);
        }
      },
      (detailActionData) {
        // On action
        print(detailActionData);
        switch (detailActionData.action) {
          case ActionType.none:
            {
              return false;
            }
          case ActionType.select:
            {
              setState(() {
                _selected = detailActionData.path;
              });
              return true;
            }
          case ActionType.addStart:
            {
              final title = detailActionData.value ? "Value" : "Group";
              _showModalInputDialog(
                context,
                'Add new $title to "${detailActionData.getLastPathElement()}"',
                "",
                "Name",
                (action, text, type) {
                  if (action == "OK") {
                    _handleAddSubmitState(detailActionData, text);
                  }
                },
                (value, type, typeName) {
                  // Validate
                  return "";
                },
              );
              return true;
            }
          case ActionType.renameStart:
            {
              final title = detailActionData.value ? "Value" : "Group";
              _showModalInputDialog(
                context,
                "Re-Name $title '${detailActionData.getLastPathElement()}'",
                detailActionData.oldValue,
                detailActionData.oldValueType,
                (action, text, type) {
                  if (action == "OK") {
                    _handleRenameSubmit(detailActionData, text);
                  }
                },
                (value, type, typeName) {
                  // Validate
                  return "";
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
                detailActionData.oldValueType,
                (action, text, type) {
                  if (action == "OK") {
                    _handleEditSubmit(detailActionData, text, type);
                  }
                },
                (value, type, typeName) {
                  if (type == "double") {
                    try {
                      if (type == "double") {
                        double.parse(value);
                      } else {
                        if (type == "int") {
                          int.parse(value);
                        }
                      }
                     } catch (e) {
                      return "That is not $typeName";
                    }
                  }
                  return "";
                },
              );
              return true;
            }
          default:
            {
              return false;
            }
        }
      },
    );

    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      body: Column(
          // Center is a layout widget. It takes a single child and positions it
          // in the middle of the parent.
          children: [
            SizedBox(
              height: appBarHeight,
              child: Container(
                color: _configData.getMaterialColor().shade500,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DetailIconButton(
                      icon: const Icon(Icons.close_outlined),
                      tooltip: 'Exit application',
                      onPressed: () async {
                        final close = await _shouldExitHandler();
                        if (close) {
                          closer(0);
                        }
                      },
                      materialColor: _configData.getMaterialColor(),
                    ),
                    DetailIconButton(
                      show: _dataWasUpdated,
                      icon: const Icon(Icons.save),
                      tooltip: 'Save Data',
                      onPressed: () {
                        _saveDataState(_password);
                      },
                      materialColor: _configData.getMaterialColor(),
                    ),
                    DetailIconButton(
                      show: _dataWasUpdated,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Reload Data',
                      onPressed: () {
                        _loadDataState(_password);
                      },
                      materialColor: _configData.getMaterialColor(),
                    ),
                    Container(
                      color: _configData.getMaterialColor().shade400,
                      child: SizedBox(
                        // <-- SEE HERE
                        width: MediaQuery.of(context).size.width / 3,
                        child: TextField(
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            hintText: _isPasswordInput ? 'Password' : 'Search',
                          ),
                          autofocus: true,
                          onSubmitted: (value) {
                            if (_isPasswordInput) {
                              _loadDataState(value);
                            } else {
                              _setSearchExpressionState(value);
                            }
                          },
                          obscureText: _isPasswordInput,
                          controller: textEditingController,
                          cursorColor: const Color(0xff000000),
                        ),
                      ),
                    ),
                    DetailIconButton(
                      show: _isPasswordInput,
                      materialColor: _configData.getMaterialColor(),
                      icon: const Icon(iconDataFileLoad),
                      tooltip: 'Load Data',
                      onPressed: () {
                        _loadDataState("to-do ${textEditingController.text}");
                      },
                    ),
                    DetailIconButton(
                      show: !_isPasswordInput,
                      materialColor: _configData.getMaterialColor(),
                      icon: const Icon(Icons.search),
                      tooltip: 'Search',
                      onPressed: () {
                        _setSearchExpressionState(textEditingController.text);
                      },
                    ),
                    DetailIconButton(
                      show: !_isPasswordInput,
                      materialColor: _configData.getMaterialColor(),
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
                    DetailIconButton(
                      show: !_isPasswordInput,
                      materialColor: _configData.getMaterialColor(),
                      icon: const Icon(Icons.search_off),
                      tooltip: 'Clear Search',
                      onPressed: () {
                        _setSearchExpressionState("");
                      },
                    ),
                    DetailIconButton(
                      show: !_isPasswordInput,
                      materialColor: _configData.getMaterialColor(),
                      icon: const Icon(Icons.more_vert),
                      tooltip: 'More...',
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
            Container(
              color: _configData.getMaterialColor().shade400,
              child: SizedBox(
                height: MediaQuery.of(context).size.height - (appBarHeight + statusBarHeight),
                child: displayData.splitView,
              ),
            ),
            Container(
              color: _globalSuccessState.isSuccess ? _configData.getMaterialColor().shade500 : Colors.red.shade500,
              child: SizedBox(
                height: statusBarHeight,
                child: Row(
                  children: [
                    Text(
                      _globalSuccessState.toString(),
                      style: statusTextStyle,
                    )
                  ],
                ),
              ),
            ),
          ]),
    );
  }
}

List<Widget> createTextWidgetFromList(List<String> inlist, Function(String) onselect) {
  List<Widget> l = List.empty(growable: true);
  for (var value in inlist) {
    l.add(TextButton(
      child: Text("'$value'", style: dialogTextStyle),
      onPressed: () {
        onselect(value);
      },
    ));
  }
  return l;
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

Future<void> _showModalDialogSuccessState(final BuildContext context, SuccessState successState) async {
  if (_applicationState.isDesktop() && successState.hasException) {
    _showModalDialog(context, [successState.status, successState.toString()], ['OK']);
  } else {
    _showModalDialog(context, [successState.status], ['OK']);
  }
}

Future<void> _showModalDialog(final BuildContext context, final List<String> texts, final List<String> buttons) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Alert'),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              for (int i = 0; i < texts.length; i++) ...[
                Text(texts[i], style: dialogTextStyle),
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
                    _okCancelDialogResult = buttons[i].toUpperCase();
                    Navigator.of(context).pop();
                  },
                ),
              ]
            ],
          ),
        ],
      );
    },
  );
}

Future<void> _showModalInputDialog(final BuildContext context, final String title, final String value, final String type, final void Function(String, String, String) onAction, final String Function(String, String, String) validate) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: _configData.getMaterialColor().shade300,
        title: Text(title, style: inputTextStyle),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              ValidatedInputField(
                prompt: "Input \$",
                initialValue: value,
                onClose: (action, text, type) {
                  onAction(action, text, type);
                  Navigator.of(context).pop();
                },
                validate: (v, t, tn) {
                  if (v == value) {
                    return "";
                  }
                  return validate(v, t, tn);
                },
                inputType: type,
              ),
            ],
          ),
        ),
      );
    },
  );
}
