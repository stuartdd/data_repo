import 'dart:io';

import 'package:data_repo/data_load.dart';
import 'package:flutter/material.dart';
import 'package:window_size/window_size.dart';
import 'package:window_manager/window_manager.dart';
import 'detail_widget.dart';
import 'encrypt.dart';
import 'path.dart';
import 'config.dart';
import 'main_view.dart';
import 'detail_buttons.dart';

late final ConfigData _configData;
late final ApplicationState _applicationState;

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
  String _expand = _configData.getUserName();
  String _search = "";
  Path _selected = Path.empty();
  bool _isPasswordInput = true;
  bool _dataWasUpdated = false;
  Map<String, dynamic> _loadedData = {};

  bool _saveData(String pw) {
    print("Save; pw:$pw: file:${_configData.getDataFileLocal()}");
    DataLoad.saveToFile(_configData.getDataFileLocal(), _loadedData);
    setState(() {
      _dataWasUpdated = false;
    });
    return false;
  }

  void _loadData(String pw) {
    String str;
    try {
      str = DataLoad.loadFromFile(_configData.getDataFileLocal());
    } catch (e) {
      throw DataLoadException(message: "Data file could not be loaded");
    }

    Map<String, dynamic> data;
    if (pw == "123") {
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
      _password = pw;
      _dataWasUpdated = false;
      _isPasswordInput = false;
      _loadedData = data;
      _selected = Path.fromDotPath(_loadedData.keys.first);
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
      print(_selected);
    });
  }

  void _handleSearchField(String searchFor) {
    if (searchFor.isEmpty) {
      return;
    }
    setState(() {
      if (_isPasswordInput) {
        try {
          _loadData(searchFor);
        } catch(e) {
          _showModalDialog(context, "File could not be loaded:", e.toString());
          return;
        }
      } else {
        _search = searchFor;
      }
    });
  }

  bool _handleEditSubmit(DetailAction detailActionData) {
    if (detailActionData.isValueDifferent()) {
      final mapNode = DataLoad.findLastMapNodeForPath(_loadedData!, detailActionData.path);
      if (mapNode == null) {
        _showModalDialog(context, "Path was not found", detailActionData.path.toString());
        return true;
      }
      final key = detailActionData.getLastPathElement();
      if (key == "") {
        _showModalDialog(context, "Last element of Path was not found", detailActionData.path.toString());
        return true;
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
        if (searchCount > 0) {
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

    final searchText = SearchTextOnAppBar(
      (event) {
        _handleSearchField(event);
      },
      _isPasswordInput,
      _dataWasUpdated,
      _search,
      _configData.getMaterialColor(),
      () {
        setState(() {
          _saveData(_password);
        });
      },
      () {
        setState(() {
          _loadData(_password);
        });
      },
    );

    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.

    if (displayData.treeViewController != null) {}
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        leading: DetailIconButton(
          icon: const Icon(Icons.close_outlined),
          tooltip: 'Exit application',
          onPressed: () {
            if (_dataWasUpdated) {
              _showModalDialog(context, "Data has been updated", "Save first or reload");
            } else {
              closer(0);
            }
          },
          materialColor: _configData.getMaterialColor(),
        ),

        title: searchText,

        centerTitle: true,
        actions: <Widget>[
          DetailIconButton(
            show: _isPasswordInput,
            materialColor: _configData.getMaterialColor(),
            icon: const Icon(Icons.done),
            tooltip: 'Done',
            onPressed: () {
              _handleSearchField("123${searchText.getResp()}");
            },
          ),
          DetailIconButton(
            show: !_isPasswordInput,
            materialColor: _configData.getMaterialColor(),
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () {
              _handleSearchField(searchText.getResp());
            },
          ),
          DetailIconButton(
            show: !_isPasswordInput,
            materialColor: _configData.getMaterialColor(),
            icon: const Icon(Icons.access_alarm),
            tooltip: 'Previous Searches',
            onPressed: () async {
              await _showSearchDialog(context, _applicationState.getLastFindList());
              if (_searchExpression.isNotEmpty) {
                setState(() {
                  _search = _searchExpression;
                });
              }
            },
          ),
          DetailIconButton(
            show: !_isPasswordInput,
            materialColor: _configData.getMaterialColor(),
            icon: const Icon(Icons.arrow_left_outlined),
            tooltip: 'Clear Search',
            onPressed: () {
              setState(() {
                _search = "";
              });
            },
          ),
          DetailIconButton(
            show: !_isPasswordInput,
            materialColor: _configData.getMaterialColor(),
            icon: const Icon(Icons.more_vert),
            tooltip: 'More...',
            onPressed: () {},
          ),
          const SizedBox(width: 40)
        ],
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: displayData.splitView,
      ),
    );
  }
}

Future<void> _showSearchDialog(final BuildContext context, final List<String> prevList) async {
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

Future<void> _showModalDialog(final BuildContext context, final String m1, final String m2) async {
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

class SearchTextOnAppBar extends StatelessWidget {
  SearchTextOnAppBar(this._callMe, this._isPasswordField, this._fileIsUpdated, this._initial, this.materialColor, this._onSave, this._onReload, {super.key});
  final void Function(String event)? _callMe;
  final String _initial;
  final bool _isPasswordField;
  final bool _fileIsUpdated;
  final Function() _onSave;
  final Function() _onReload;
  final MaterialColor materialColor;
  final TextEditingController _tec = TextEditingController(text: "");

  @override
  Widget build(BuildContext context) {
    _tec.text = _initial;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailIconButton(
          show: _fileIsUpdated,
          icon: const Icon(Icons.save),
          tooltip: 'Save Data',
          onPressed: () {
            _onSave();
          },
          materialColor: materialColor,
        ),
        DetailIconButton(
          show: _fileIsUpdated,
          icon: const Icon(Icons.refresh),
          tooltip: 'Reload Data',
          onPressed: () {
            _onReload();
          },
          materialColor: materialColor,
        ),
        SizedBox(
          // <-- SEE HERE
          width: 200,
          child: TextField(
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: _isPasswordField ? 'Password' : 'Search',
            ),
            autofocus: true,
            onSubmitted: (value) {
              _callMe!(value);
            },
            obscureText: _isPasswordField,
            controller: _tec,
            cursorColor: const Color(0xff000000),
          ),
        ),
      ],
    );
  }

  String getResp() {
    return _tec.value.text;
  }
}
