import 'dart:io';

import 'package:data_repo/data_load.dart';
import 'package:flutter/material.dart';
import 'package:window_size/window_size.dart';
import 'package:window_manager/window_manager.dart';
import 'detail_widget.dart';
import 'encrypt.dart';
import 'config.dart';
import 'main_view.dart';

late final ConfigData _configData;
late final ApplicationState _applicationState;
Map<String, dynamic>? _loadedData;
bool dataWasUpdated = false;
String _searchExpression = "";

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
      WindowOptions windowOptions = const WindowOptions(
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
    ;
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
  String _password = "123";
  String _status = "";
  String _search = "";
  String _selected = "";
  bool _isPasswordInput = true;

  Map<String, dynamic>? _loadData(String pw) {
    try {
      final str = DataLoad.fromFile(_configData.getDataFileLocal());
      if (pw == "123") {
        try {
          // Decrypt here in  a try catch, then do json parse in nester try catch
          final data = DataLoad.jsonFromString(str);
          _password = pw;
          _status = "File Loaded";
          if (data[_configData.getUserId()] == null) {
            _status = "Loaded file did not contain the users data";
            return null;
          }
          return data;
        } catch (r) {
          _status = "Loaded file was corrupt or password is incorrect";
          return null;
        }
      }
      _status = "Invalid Password";
      return null;
    } catch (e) {
      _status = e.toString();
      return null;
    }
  }

  void _handleTreeSelect(String path) {
    setState(() {
      _selected = path;
      print(DataLoad.findNodeForPath(_loadedData!, _selected));
    });
    print("SELECT:$path");
  }

  void _handleInputField(String s) {
    if (s.isEmpty) {
      return;
    }
    setState(() {
      if (_isPasswordInput) {
        _loadedData = _loadData(
          s,
        );
        if (_loadedData == null) {
          _isPasswordInput = true;
          _selected = "";
          _showMyDialog("File '${_configData.getDataFileName()}' could not be loaded", _status);
        } else {
          _isPasswordInput = false;
          _selected = _loadedData!.isEmpty ? "" : _loadedData!.keys.first;
        }
      } else {
        _search = s;
      }
    });
  }

  bool doEditSubmit(DetailAction detailActionData) {
    if (detailActionData.isValueDifferent()) {
      final node = DataLoad.findNodeForPath(_loadedData!, detailActionData.path);
      if (node == null) {
        _showMyDialog("Path was not found", detailActionData.path);
        return true;
      }
      final key = detailActionData.getLastPathElement();
      if (key == "") {
        _showMyDialog("Last element of Path was not found", detailActionData.path);
        return true;
      }
      setState(() {
        dataWasUpdated = true;
        node[detailActionData.getLastPathElement()] = detailActionData.v2;
      });
      return true;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final Widget currentView = createSplitView(
      _loadedData,
      _configData.getUserId(),
      _search,
      _selected,
      _applicationState.isDesktop(),
      _applicationState.screen.hDiv,
      _configData.getMaterialColor(),
      _handleTreeSelect,
      (divPos) {
        if (_applicationState.updateDividerPos(divPos)) {
          _applicationState.writeToFile(false);
        }
      },
      (searchCount) {
        if (searchCount > 0) {
          _applicationState.addLastFind(_search, 5);
          _applicationState.writeToFile(false);
        }
      },
      (detailActionData) {
        print(detailActionData);
        switch (detailActionData.action) {
          case ActionType.none:
            {
              return false;
            }
          case ActionType.editSubmit:
            {
              return doEditSubmit(detailActionData);
            }
          default:
            {
              return false;
            }
        }
      },
    );

    final inputField = TextBoxAppBar((event) {
      _handleInputField(event);
    }, _isPasswordInput, _search);

    final Widget icon;
    if (_isPasswordInput) {
      icon = IconButton(
        icon: const Icon(Icons.done),
        tooltip: 'Done',
        onPressed: () {
          _handleInputField("123${inputField.getResp()}");
        },
      );
    } else {
      icon = Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_drop_down_circle_outlined),
            tooltip: 'Previous Searches',
            onPressed: () async {
              await _showSearchDialog(_applicationState.getLastFindList());
              if (_searchExpression.isNotEmpty) {
                setState(() {
                  _search = _searchExpression;
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_left_outlined),
            tooltip: 'Clear Search',
            onPressed: () {
              setState(() {
                _search = "";
              });
            },
          )
        ],
      );
    }
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.

    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        leading: IconButton(
          icon: const Icon(Icons.close_outlined),
          tooltip: 'Exit application',
          onPressed: () {
            closer(0);
          },
        ),

        title: inputField,

        centerTitle: true,
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: icon,
          ),
          Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: GestureDetector(
                onTap: () {},
                child: const Icon(Icons.more_vert),
              )),
        ],
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: currentView,
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {},
      //   tooltip: 'Increment',
      //   child: const Icon(Icons.add),
      // ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Future<void> _showSearchDialog(final List<String> prevList) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Previous Searches'),
          content: SingleChildScrollView(
            child: ListBody(
              children: createTextWidgetFromList(prevList, (selected) {
                _searchExpression = selected;
                Navigator.of(context).pop();
              }),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                _searchExpression = "";
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showMyDialog(final String m1, final String m2) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Alert'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(m1),
                Text(m2),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class TextBoxAppBar extends StatelessWidget {
  TextBoxAppBar(this._callme, this._isPasswordField, this._initial, {super.key});
  final void Function(String event)? _callme;
  final String _initial;
  final bool _isPasswordField;
  final TextEditingController _tec = TextEditingController(text: "");

  @override
  Widget build(BuildContext context) {
    _tec.text = _initial;
    return Container(
      alignment: Alignment.centerLeft,
      child: TextField(
        autofocus: true,
        onSubmitted: (value) {
          _callme!(value);
        },
        obscureText: _isPasswordField,
        controller: _tec,
        cursorColor: const Color(0xff000000),
        decoration: InputDecoration(border: const OutlineInputBorder(), hintText: _isPasswordField ? 'Password' : 'Search'),
      ),
    );
  }

  String getResp() {
    return _tec.value.text;
  }
}
