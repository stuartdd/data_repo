import 'dart:io';
import 'package:data_repo/configSettings.dart';
import 'package:data_repo/data_load.dart';
import 'package:data_repo/treeNode.dart';
import 'package:flutter/cupertino.dart';
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
const iconDataFileLoad = Icons.file_open;

late final ConfigData _configData;
late final ApplicationState _applicationState;
final PathPropertiesList _pathPropertiesList = PathPropertiesList(log: log);
final TextEditingController textEditingController = TextEditingController(text: "");

NodeCopyBin _nodeCopyBin = NodeCopyBin.empty();
StringBuffer eventLog = StringBuffer();
String eventLogLatest = "";
String _okCancelDialogResult = "";
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
      case 'maximize':
      case 'minimize':
        {
          _applicationState.screenNotMaximised = false;
          break;
        }
      case 'unmaximize':
        {
          _applicationState.screenNotMaximised = true;
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
            _applicationState.screenNotMaximised = true;
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
  bool _noDataToDisplay = true;
  double _navBarHeight = navBarHeight;
  ScrollController _treeViewScrollController = ScrollController();
  DataContainer _loadedData = DataContainer.empty();
  MyTreeNode _treeNodeDataRoot = MyTreeNode.empty();
  MyTreeNode _filteredNodeDataRoot = MyTreeNode.empty();
  SuccessState _globalSuccessState = SuccessState(true);
  MyTreeNode _selectedTreeNode = MyTreeNode.empty();
  Path _selectedPath = Path.empty();
  Map<String, BuildContext> nodeContextList = {};

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
        int tni = _selectedTreeNode.index - 1;
        if (tni < 0) {
          tni = 0;
        }
        final index = tni * _configData.getAppThemeData().treeNodeHeight;
        _treeViewScrollController.animateTo(index, duration: const Duration(milliseconds: 400), curve: Curves.ease);
      },
    );
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
    _previousSearch = "[$_search]"; // Need search and previousSearch to be different so filter is applied
    if (st.isEmpty) {
      log("__SEARCH__ cleared");
      selectNode();
    }
    setState(() {
      textEditingController.text = st;
      _search = st;
    });
  }

  Future<void> _saveDataState() async {
    final String content = DataLoad.convertMapToStringWithTs(_loadedData.dataMap, _loadedData.password);
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
        _pathPropertiesList.clear();
      }
      _globalSuccessState = SuccessState(success, message: m);
    });
  }

  void _loadDataState() async {
    String source = "";
    FilePrefixData filePrefixData = FilePrefixData.empty();
    FilePrefixData tsRemote = FilePrefixData.empty();
    String fileData = "";
    final ssRemote = await DataLoad.fromHttpGet(_configData.getGetDataFileUrl(), timeoutMillis: _configData.getDataFetchTimeoutMillis());
    if (ssRemote.isSuccess) {
      tsRemote = FilePrefixData.fromString(ssRemote.value);
      log("__INFO:__ Remote __TS:__ ${tsRemote.timeStamp}");
      fileData = ssRemote.value.substring(tsRemote.startPos);
      source = "Remote";
      filePrefixData = tsRemote;
    } else {
      log(ssRemote.toLogString());
    }

    final ssLocal = DataLoad.loadFromFile(_configData.getDataFileLocal());
    if (ssLocal.isSuccess) {
      final tsLocal = FilePrefixData.fromString(ssLocal.value);
      log("__INFO:__ Local __TS:__ ${tsLocal.timeStamp}");
      if (ssRemote.isFail || tsLocal.isLaterThan(tsRemote)) {
        fileData = ssLocal.value.substring(tsLocal.startPos);
        source = "Local";
        filePrefixData = tsLocal;
      }
    } else {
      log(ssLocal.toLogString());
    }

    if (filePrefixData.encrypted && _password.isEmpty) {
      setState(() {
        _globalSuccessState = SuccessState(false, message: "__LOAD__ No Password Provided", log: log);
      });
      return;
    }

    if (fileData.isEmpty) {
      setState(() {
        _globalSuccessState = SuccessState(false, message: "__LOAD__ No Data Available", log: log);
      });
      return;
    }

    final DataContainer data;
    try {
      data = DataContainer(fileData, filePrefixData, source, _password);
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
      _beforeDataLoaded = false;
      _pathPropertiesList.clear();
      _treeNodeDataRoot = MyTreeNode.fromMap(_loadedData.dataMap);
      _treeNodeDataRoot.expandAll(true);
      _treeNodeDataRoot.clearFilter();
      _filteredNodeDataRoot = MyTreeNode.empty();
      _noDataToDisplay = _treeNodeDataRoot.isEmpty;
      _selectedTreeNode = _treeNodeDataRoot.firstSelectableNode();
      _selectedPath = _selectedTreeNode.path;
      _globalSuccessState = SuccessState(true, message: "${filePrefixData.encrypted ? "Encrypted " : ""} ${_loadedData.source} File loaded: ${_loadedData.timeStampString}", log: log);
    });
  }

  void _refreshTreeNodeDataRoot() {
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
          _refreshTreeNodeDataRoot();
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
          _refreshTreeNodeDataRoot();
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
        _refreshTreeNodeDataRoot();
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
        _refreshTreeNodeDataRoot();
        selectNode(path: parentPath);
        _globalSuccessState = SuccessState(true, message: "Removed: '${path.last}'");
      });
    }
  }

  void _handlePasteState(final Path path) async {
    setState(() {
      final mapNodes = path.pathNodes(_loadedData.dataMap);
      if (mapNodes.error) {
        _globalSuccessState = SuccessState(false, message: "__PASTE__ Path not found");
        return;
      }
      final node = DataLoad.getMapFromJson(_loadedData.dataMap, path);
      String name = _nodeCopyBin.copyFromPath.last;
      if (node.containsKey(name)) {
        name = "${name}_copy";
      }
      final newPath = path.cloneAppendList([name]);
      node[name] = _nodeCopyBin.copyNode();
      _dataWasUpdated = true;
      _pathPropertiesList.setUpdated(path);
      _pathPropertiesList.setUpdated(newPath);
      _refreshTreeNodeDataRoot();
      selectNode(path: newPath);
      if (_nodeCopyBin.cut) {
        final p = _handleDelete(_nodeCopyBin.copyFromPath);
        if (p.isEmpty) {
          _globalSuccessState = SuccessState(false, message: "__PASTE__ CUT path not removed");
          return;
        }
        _pathPropertiesList.setUpdated(p);
        _refreshTreeNodeDataRoot();
        selectNode(path: p);
      }
      _globalSuccessState = SuccessState(true, message: "Pasted: '$name' into: '${path.last}'");
    });
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
          _refreshTreeNodeDataRoot();
          selectNode(path: detailActionData.path.cloneParentPath());
          _globalSuccessState = SuccessState(true, message: "Item ${detailActionData.getLastPathElement()} updated");
        } catch (e, s) {
          debugPrintStack(stackTrace: s);
        }
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

    if (_previousSearch != _search || _filteredNodeDataRoot.isEmpty) {
      _previousSearch = _search;
      _filteredNodeDataRoot = _treeNodeDataRoot.applyFilter(_search, true, (match, tolowerCase, node) {
        if (tolowerCase) {
          return (node.label.toLowerCase().contains(match));
        }
        return (node.label.contains(match));
      });
    } else {
      _filteredNodeDataRoot = _treeNodeDataRoot.clone(requiredOnly: true);
    }

    _noDataToDisplay = _filteredNodeDataRoot.isEmpty;
    if (_noDataToDisplay) {
      _isEditDataDisplay = false;
      _navBarHeight = 0;
    } else {
      if (_search.isNotEmpty) {
        _applicationState.addLastFind(_search, 10);
      }
      _navBarHeight = navBarHeight;
    }

    final DisplayData displayData = createSplitView(
      _loadedData.dataMap,
      _filteredNodeDataRoot,
      _selectedTreeNode,
      _isEditDataDisplay,
      _configData.isDesktop(),
      _applicationState.screen.divPos,
      _configData.getAppThemeData(),
      _nodeCopyBin,
      _pathPropertiesList,
      _selectNodeState,
      _expandNodeState,
      (divPos) {
        // On divider change
        _applicationState.updateDividerPosState(divPos);
      },
      (detailActionData) {
        // On selected detail page action
        debugPrint(detailActionData.toString());
        switch (detailActionData.action) {
          case ActionType.group:
            {
              setState(() {
                _pathPropertiesList.setGroupSelect(detailActionData.path);
              });
              break;
            }
          case ActionType.delete:
            {
              _showModalDialog(context, "Remove item", ["${detailActionData.valueName} '${detailActionData.getLastPathElement()}'"], ["OK", "Cancel"], detailActionData.path, _handleDeleteState);
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
                    _handleEditState(detailActionData, text, type);
                  } else {
                    if (action == "link") {
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
        }
        return Path.empty();
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
        iconData: Icons.close_outlined,
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
        color: _configData.getAppThemeData().primary.med,
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
        iconData: iconDataFileLoad,
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
      toolBarItems.add(DetailIconButton(
        show: !_noDataToDisplay,
        appThemeData: _configData.getAppThemeData(),
        iconData: _isEditDataDisplay ? Icons.search : Icons.edit,
        tooltip: _isEditDataDisplay ? 'Search Mode' : "Edit Mode",
        onPressed: () {
          setState(() {
            _isEditDataDisplay = !_isEditDataDisplay;
          });
        },
      ));
      if (_dataWasUpdated || _isEditDataDisplay) {
        toolBarItems.add(
          DetailIconButton(
            iconData: Icons.save,
            tooltip: _loadedData.hasPassword ? "Save ENCRYPTED" : 'Save Data',
            onPressed: () {
              _saveDataState();
            },
            appThemeData: _configData.getAppThemeData(),
          ),
        );
        toolBarItems.add(
          DetailIconButton(
            iconData: Icons.refresh,
            tooltip: 'Reload Data',
            onPressed: () {
              _loadDataState();
            },
            appThemeData: _configData.getAppThemeData(),
          ),
        );
      }
      if (_isEditDataDisplay) {
        final canCopy = _selectedPath.hasParent;
        final canPaste = _nodeCopyBin.isNotEmpty;

        toolBarItems.add(DetailIconButton(
          appThemeData: _configData.getAppThemeData(),
          iconData: Icons.add_box_outlined,
          tooltip: 'Add Value or Group',
          onPressed: () {
            _showModalInputDialog(
              context,
              "Add To: '${_selectedPath.last}'",
              "",
              optionsForAddElement,
              optionTypeDataValue,
              true,
              (action, text, type) {
                if (action == "OK") {
                  _handleAddState(_selectedPath, text, type);
                }
              },
              (initial, value, initialType, valueType) {
                return value.trim().isEmpty ? "Cannot be empty" : "";
              },
            );
          },
        ));
        if (canCopy) {
          toolBarItems.add(
            DetailIconButton(
              onPressed: () {
                setState(() {
                  _nodeCopyBin = NodeCopyBin(_selectedPath, false, DataLoad.getMapFromJson(_loadedData.dataMap, _selectedPath), _password);
                  _globalSuccessState = SuccessState(true, message: "Node '${_selectedPath.last}' COPIED to clipboard");
                });
              },
              tooltip: "Copy This Node",
              iconData: Icons.copy,
              appThemeData: _configData.getAppThemeData(),
            ),
          );
          toolBarItems.add(
            DetailIconButton(
              onPressed: () {
                setState(() {
                  _nodeCopyBin = NodeCopyBin(_selectedPath, true, DataLoad.getMapFromJson(_loadedData.dataMap, _selectedPath), _password);
                  _globalSuccessState = SuccessState(true, message: "Node '${_selectedPath.last}' CUT to clipboard");
                });
              },
              tooltip: "Cut This Node",
              iconData: Icons.cut,
              appThemeData: _configData.getAppThemeData(),
            ),
          );
        }
        if (canPaste) {
          toolBarItems.add(DetailIconButton(
            show: canPaste,
            onPressed: () {
              _handlePasteState(_selectedPath);
            },
            tooltip: "Paste into ${_selectedPath.last}",
            iconData: Icons.paste,
            appThemeData: _configData.getAppThemeData(),
          ));
        }
      } else {
        toolBarItems.add(
          Container(
            color: _configData.getAppThemeData().primary.med,
            child: SizedBox(
              width: MediaQuery.of(context).size.width / 3,
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
                controller: textEditingController,
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
              _setSearchExpressionState(textEditingController.text);
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
        left: MediaQuery.of(context).size.width - appBarHeight,
        top: 0,
        child: DetailIconButton(
          iconData: Icons.settings,
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
              (settingsControlList, save) {
                // Commit
                // log("__SETTINGS:__ ${settingsControl.detail.path} Type:${settingsControl.detail.detailType} Value:'${settingsControl.stringValue}'");
                // final msg = DataLoad.setValueForJsonPath(_configData.getJson(), settingsControl.detail.path, settingsControl.dynamicValue);
                settingsControlList.commit(_configData.getJson());
                setState(() {
                  _configData.update();
                  if (save) {
                    _globalSuccessState = _configData.save(log);
                  } else {
                    _globalSuccessState = SuccessState(true, message: "Config data NOT saved");
                  }
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
    final appBackgroundColor = _configData.getAppThemeData().screenBackgroundColor;
    final appBackgroundErrorColor = _configData.getAppThemeData().screenBackgroundErrorColor;
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
                  color: appBackgroundColor,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: toolBarItems),
                ),
                Container(
                  color: Colors.black,
                  height: 1,
                ),
                _beforeDataLoaded
                    ? const SizedBox(
                        height: 0,
                      )
                    : _noDataToDisplay
                        ? SizedBox(
                            height: 0,
                          )
                        : Container(
                            height: _navBarHeight,
                            color: appBackgroundColor,
                            child: createNodeNavButtonBar(_selectedPath, _nodeCopyBin, _configData.getAppThemeData(), _isEditDataDisplay, _beforeDataLoaded, (detailActionData) {
                              switch (detailActionData.action) {
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
                                default:
                                  {
                                    return Path.empty();
                                  }
                              }
                              return Path.empty();
                            }),
                          ),
                _beforeDataLoaded
                    ? const SizedBox(
                        height: 0,
                      )
                    : Container(
                        color: Colors.black,
                        height: 1,
                      ),
                Container(
                  height: MediaQuery.of(context).size.height - (appBarHeight + statusBarHeight + (_beforeDataLoaded ? 2 : _navBarHeight + 3)),
                  color: appBackgroundColor,
                  child: displayData.splitView,
                ),
                Container(
                  height: 1,
                  color: Colors.black,
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
      )),
    );
  }
}

Future<void> _showConfigDialog(final BuildContext context, AppThemeData appThemeData, final String fileName, final String Function(dynamic, SettingDetail) validate, final void Function(SettingControlList, bool) onCommit) async {
  return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _configData.getAppThemeData().dialogBackgroundColor,
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
            settingsControlList: SettingControlList(appThemeData.desktop, _configData.getJson()),
            onValidate: validate,
            onCommit: (settingsControlList, shouldSave) {
              if (settingsControlList.canSaveOrApply) {
                onCommit(settingsControlList, shouldSave);
              }
              Navigator.of(context).pop();
            },
            height: MediaQuery.of(context).size.height - (appBarHeight + statusBarHeight + inputTextTitleStyleHeight + 100),
            width: MediaQuery.of(context).size.width,
          ),
        );
      });
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
        title: Text('Event Log', style: _configData.getAppThemeData().tsMedium),
        content: SingleChildScrollView(
            child: Container(
          color: _configData.getAppThemeData().primary.light,
          height: MediaQuery.of(context).size.height - (appBarHeight + statusBarHeight),
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
        backgroundColor: _configData.getAppThemeData().dialogBackgroundColor,
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

Future<void> _showModalDialog(final BuildContext context, final String title, final List<String> texts, final List<String> buttons, final Path? path, final void Function(Path, String)? onResponse) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: _configData.getAppThemeData().dialogBackgroundColor,
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
                    if (onResponse != null && path != null) {
                      onResponse(path, buttons[i].toUpperCase());
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
        backgroundColor: _configData.getAppThemeData().dialogBackgroundColor,
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
                        return Path.empty();
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
