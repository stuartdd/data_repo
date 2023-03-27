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
const statusBarHeight = 30.0;
const iconDataFileLoad = Icons.file_open;
const dialogTextStyle = TextStyle(fontFamily: 'Code128', fontSize: 25.0, color: Colors.black);
const dialogButtonStyle = TextStyle(fontFamily: 'Code128', fontSize: 25.0, color: Colors.blue);
const statusTextStyle = TextStyle(fontFamily: 'Code128', fontSize: 20.0, color: Colors.black);

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

  SuccessState _setSuccessState(SuccessState newState) {
    if (_globalSuccessState.isDifferentFrom(newState)) {
      setState(() {
        _globalSuccessState = newState;
      });
      return newState;
    }
    return _globalSuccessState;
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

  void _saveDataState(String pw) {
    _setSuccessState(DataLoad.saveToFile(_configData.getDataFileLocal(), _loadedData));
    if (_globalSuccessState.isSuccess) {
      setState(() {
        _dataWasUpdated = false;
        _hiLightedPaths.clean();
      });
    }
  }

  void _loadDataState(String pw) {
    _setSuccessState(DataLoad.loadFromFile(_configData.getDataFileLocal()));
    if (!_globalSuccessState.isSuccess) {
      _showModalDialogSuccessState(context, _globalSuccessState);
      return;
    }
    Map<String, dynamic> data;
    if (pw == "") {
      try {
        // Decrypt here in  a try catch, then do json parse in nester try catch
        data = DataLoad.jsonFromString(_globalSuccessState.data);
      } catch (r) {
        _showModalDialogSuccessState(context, _setSuccessState(SuccessState(false, state: "Data file could not be parsed", exception: r as Exception)));
        return;
      }
      if (data.isEmpty) {
        _showModalDialogSuccessState(context, _setSuccessState(SuccessState(false, state: "Data file does not contain any data")));
        return;
      }
      if (data[_configData.getUserId()] == null) {
        _showModalDialogSuccessState(context, _setSuccessState(SuccessState(false, state: "Data file does not contain the users data")));
        return;
       }
      setState(() {
        _password = pw;
        _dataWasUpdated = false;
        _isPasswordInput = false;
        _loadedData = data;
        _selected = Path.fromDotPath(_loadedData.keys.first);
        _hiLightedPaths.clean();
      });
      return;
    }
    _showModalDialogSuccessState(context, _setSuccessState(SuccessState(false, state: "Password was not provided")));
  }

  void _handleTreeSelect(String dotPath) {
    final path = Path.fromDotPath(dotPath);
    setState(() {
      if (path.isNotEmpty()) {
        _expand = path.getRoot();
      }
      _selected = path;
      print("Selected:$_selected)");
    });
  }

  bool _handleRenameSubmit(DetailAction detailActionData) {
    if (detailActionData.isValueDifferent()) {
      final mapNode = DataLoad.findLastMapNodeForPath(_loadedData, detailActionData.path);
      if (mapNode == null) {
        _showModalDialog(context, ["Path was not found", detailActionData.path.toString()], ["OK"]);
        return false;
      }
      setState(() {
        var v = mapNode[detailActionData.v1];
        mapNode.remove(detailActionData.v1);
        mapNode[detailActionData.v2] = v;
        _dataWasUpdated = true;
        detailActionData.path.pop();
        detailActionData.path.push(detailActionData.v2);
        _hiLightedPaths.add(detailActionData.path);
      });
    }
    return true;
  }

  bool _handleEditSubmit(DetailAction detailActionData) {
    if (detailActionData.isValueDifferent()) {
      final mapNode = DataLoad.findLastMapNodeForPath(_loadedData, detailActionData.path);
      if (mapNode == null) {
        _showModalDialog(context, ["Path was not found", detailActionData.path.toString()], ["OK"]);
        return false;
      }
      final key = detailActionData.getLastPathElement();
      if (key == "") {
        _showModalDialog(context, ["Last element of Path was not found", detailActionData.path.toString()], ["OK"]);
        return false;
      }
      setState(() {
        _dataWasUpdated = true;
        mapNode[key] = detailActionData.v2;
        _hiLightedPaths.add(detailActionData.path);
      });
      return true;
    }
    return true;
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
          _setSuccessState(SuccessState(true, state: "Exit Cancelled"));
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
          case ActionType.renameSubmit:
            {
              return _handleRenameSubmit(detailActionData);
            }
          case ActionType.editSubmit:
            {
              return _handleEditSubmit(detailActionData);
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
                        _loadDataState(textEditingController.text);
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
                      _globalSuccessState.isSuccess ? "State: ${_globalSuccessState.state}" : "Error: ${_globalSuccessState.state}",
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
    _showModalDialog(context, [successState.state, successState.exception.toString()], ['OK']);
  } else {
    _showModalDialog(context, [successState.state], ['OK']);
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
