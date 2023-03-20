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
final TextEditingController textEditingController = TextEditingController(text: "");

const appBarHeight = 50.0;
const iconDataFileLoad = Icons.file_open;
const dialogTextStyle = TextStyle(fontFamily: 'Code128', fontSize: 25.0, color: Colors.black);
const dialogButtonStyle = TextStyle(fontFamily: 'Code128', fontSize: 25.0, color: Colors.blue);

Future closer(int returnCode) async {
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
  Map<String, dynamic> _loadedData = {};

  void _setSearchExpressionState(String st) {
    if (st == _search) {
      return;
    }
    setState(() {
      textEditingController.text = st;
      _search = st;
    });
  }

  bool _saveDataState(String pw) {
    print("Save; pw:$pw: file:${_configData.getDataFileLocal()}");
    DataLoad.saveToFile(_configData.getDataFileLocal(), _loadedData);
    setState(() {
      _dataWasUpdated = false;
    });
    return false;
  }

  void _loadDataState(String pw) {
    String str;
    try {
      str = DataLoad.loadFromFile(_configData.getDataFileLocal());
    } catch (e) {
      throw DataLoadException(message: "Data file could not be loaded");
    }
    Map<String, dynamic> data;
    if (pw == "") {
      try {
        // Decrypt here in  a try catch, then do json parse in nester try catch
        data = DataLoad.jsonFromString(str);
      } catch (r) {
        throw DataLoadException(message: "Data file could not be parsed");
      }
      if (data.isEmpty) {
        throw DataLoadException(message: "Loaded file does not contain any data");
      }
      if (data[_configData.getUserId()] == null) {
        throw DataLoadException(message: "Loaded file does not contain the users data");
      }
      setState(() {
        _password = pw;
        _dataWasUpdated = false;
        _isPasswordInput = false;
        _loadedData = data;
        _selected = Path.fromDotPath(_loadedData.keys.first);
      });
      return;
    }
    throw DataLoadException(message: "Password was not provided");
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

  void _handlePasswordFieldState(String pw) {
    try {
      _loadDataState(pw);
    } catch (e) {
      _showModalDialog(context, ["File could not be loaded:", e.toString()], false);
      return;
    }
  }

  bool _handleEditSubmit(DetailAction detailActionData) {
    if (detailActionData.isValueDifferent()) {
      final mapNode = DataLoad.findLastMapNodeForPath(_loadedData, detailActionData.path);
      if (mapNode == null) {
        _showModalDialog(context, ["Path was not found", detailActionData.path.toString()], false);
        return false;
      }
      final key = detailActionData.getLastPathElement();
      if (key == "") {
        _showModalDialog(context, ["Last element of Path was not found", detailActionData.path.toString()], false);
        return false;
      }
      setState(() {
        _dataWasUpdated = true;
        mapNode[key] = detailActionData.v2;
      });
      return true;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    FlutterWindowClose.setWindowShouldCloseHandler(() async {
      if (_dataWasUpdated) {
        await _showModalDialog(context, ["Data has been updated", "Press OK to EXIT without saving", "Press CANCEL to remain in the app"], true);
        if (_okCancelDialogResult != "OK") {
          return false;
        }
      }
      return true;
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
                        if (_dataWasUpdated) {
                          await _showModalDialog(context, ["Data has been updated", "Press OK to SAVE then Exit", "Press CANCEL remain in the App"], true);
                          if (_okCancelDialogResult == "OK") {
                            _saveDataState(_password);
                            closer(0);
                          }
                        } else {
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
                              _handlePasswordFieldState(value);
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
                        _handlePasswordFieldState(textEditingController.text);
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
                height: MediaQuery.of(context).size.height - appBarHeight,
                child: displayData.splitView,
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

Future<void> _showModalDialog(final BuildContext context, final List<String> texts, bool hasCancel) async {
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
          TextButton(
            child: const Text('OK', style: dialogButtonStyle),
            onPressed: () {
              _okCancelDialogResult = "OK";
              Navigator.of(context).pop();
            },
          ),
          hasCancel
              ? TextButton(
                  child: const Text('CANCEL', style: dialogButtonStyle),
                  onPressed: () {
                    _okCancelDialogResult = "CANCEL";
                    Navigator.of(context).pop();
                  },
                )
              : const SizedBox(width: 0),
        ],
      );
    },
  );
}
