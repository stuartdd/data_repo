import 'package:flutter/material.dart';
import 'config.dart';
import 'data_types.dart';
import 'path.dart';
import 'detail_buttons.dart';

const inputTextTitleStyleHeight = 35.0;

Future<void> showOptionsDialog(final BuildContext context, final AppThemeData appThemeData, final Path path, final List<MenuOptionDetails> menuOptionsList, final List<String> sub, final Function(ActionType, Path) onSelect) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: appThemeData.dialogBackgroundColor,
        child: ListView(
          children: [
            for (int i = 0; i < menuOptionsList.length; i++) ...[
              menuOptionsList[i].enabled
                  ? Card(
                      elevation: 2,
                      margin: const EdgeInsets.all(2),
                      color: appThemeData.detailBackgroundColor,
                      child: ListTile(
                        title: Container(
                          padding: const EdgeInsets.all(4.0),
                          color: appThemeData.dialogBackgroundColor,
                          child: Row(
                            children: [
                              Icon(menuOptionsList[i].icon, size: appThemeData.iconSize, color: appThemeData.screenForegroundColour(true)),
                              appThemeData.iconGapBox(1),
                              Text(menuOptionsList[i].s1(sub), style: appThemeData.tsLarge),
                            ],
                          ),
                        ),
                        subtitle: menuOptionsList[i].hasSubText ? Text(menuOptionsList[i].s2(sub), style: appThemeData.tsMedium) : null,
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

Future<void> showFileNamePasswordDialog(final BuildContext context, final AppThemeData appThemeData, final String title, final List<String> info, final String Function(SimpleButtonActions, String, String) onAction) async {
  debugPrint("showFileNamePasswordDialog");
  final theme = appThemeData;
  var separator = appThemeData.verticalGapBox(1);
  final content = _stringsToTextList(info, 1, separator as SizedBox, theme);

  var fileName = "";
  var password = "";

  final okButtonManager = DetailTextButtonManager(
    text: "OK",
    visible: false,
    appThemeData: theme,
    onPressed: (button) {
      onAction(SimpleButtonActions.ok, fileName, password);
      Navigator.of(context).pop();
    },
  );

  final fileNameInput = ValidatedInputField(
    prompt: "File Name",
    appThemeData: appThemeData,
    onSubmit: (vx, vt) {},
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
      okButtonManager.setEnabled(message.isEmpty);
      return message;
    },
  );

  final passwordInput = ValidatedInputField(
    isPassword: true,
    prompt: "Password",
    appThemeData: appThemeData,
    onSubmit: (vx, vt) {},
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
              DetailTextButton(
                text: "CANCEL",
                appThemeData: theme,
                onPressed: (button) {
                  Navigator.of(context).pop();
                },
              ),
              okButtonManager.widget
            ],
          ),
        ],
      );
    },
  );
}

Widget _copyMoveSummaryList(GroupCopyMoveSummaryList summaryList, final AppThemeData appThemeData, Path into, final String head, final bool copyMove, final void Function(SimpleButtonActions, Path) onAction) {
  final wl = <Widget>[];
  final tab = appThemeData.textSize("Group: ", appThemeData.tsMedium);
  wl.add(Text("Selected Data:", style: appThemeData.tsMediumBold));
  wl.add(Container(
    color: Colors.black,
    height: 2,
  ));

  for (int i = 0; i < summaryList.length; i++) {
    final summary = summaryList.list[i];
    final tag = summary.isValue ? "Value:" : "Group:";
    final r1 = Row(
      children: [
        IconButton(
            onPressed: () {
              onAction(SimpleButtonActions.select, summaryList.list[i].copyFromPath);
            },
            tooltip: "Go To",
            icon: const Icon(Icons.select_all)),
        IconButton(
            onPressed: () {
              onAction(SimpleButtonActions.listRemove, summaryList.list[i].copyFromPath);
            },
            tooltip: "Delete from this list",
            icon: const Icon(Icons.delete)),
        summary.isError ? Text(summary.error, style: appThemeData.tsMediumError) : Text("OK: Can $head", style: appThemeData.tsMedium),
      ],
    );
    final r2 = Row(
      children: [
        SizedBox(width: tab.width, child: Text(tag, style: appThemeData.tsMedium)),
        Text(summary.name, style: appThemeData.tsMediumBold),
      ],
    );
    final r3 = Row(
      children: [
        SizedBox(width: tab.width, child: Text("In:", style: appThemeData.tsMedium)),
        Text(summary.parent, style: appThemeData.tsMediumBold),
      ],
    );
    wl.add(r1);
    wl.add(r2);
    wl.add(r3);
    if (copyMove) {
      final r4 = Row(
        children: [
          SizedBox(width: tab.width, child: Text("To:", style: appThemeData.tsMedium)),
          Text(into.toString(), style: appThemeData.tsMediumBold),
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

Future<void> showCopyMoveDialog(final BuildContext context, final AppThemeData appThemeData, final Path into, final GroupCopyMoveSummaryList summaryList, bool copyMove, final void Function(SimpleButtonActions, Path) onActionReturn, final void Function(SimpleButtonActions, Path) onActionClose) async {
  final head = copyMove ? "Copy or Move" : "Delete";
  final toFrom = copyMove ? "To" : "";
  final theme = appThemeData;
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
            if (action != SimpleButtonActions.select) {
              onActionReturn(action, path);
            } else {
              onActionClose(action, path);
            }
            Navigator.of(context).pop();
          }),
        ),
        actions: <Widget>[
          Row(
            children: [
              DetailTextButton(
                appThemeData: appThemeData,
                text: "Cancel",
                onPressed: (button) {
                  Navigator.of(context).pop();
                },
              ),
              DetailTextButton(
                appThemeData: appThemeData,
                text: "Copy",
                visible: summaryList.hasNoErrors && copyMove,
                onPressed: (button) {
                  onActionReturn(SimpleButtonActions.copy, into);
                  Navigator.of(context).pop();
                },
              ),
              DetailTextButton(
                appThemeData: appThemeData,
                text: "Move",
                visible: summaryList.hasNoErrors && copyMove,
                onPressed: (button) {
                  onActionReturn(SimpleButtonActions.move, into);
                  Navigator.of(context).pop();
                },
              ),
              DetailTextButton(
                appThemeData: appThemeData,
                text: "DELETE",
                visible: summaryList.hasNoErrors && !copyMove,
                onPressed: (button) {
                  onActionReturn(SimpleButtonActions.delete, Path.empty());
                  Navigator.of(context).pop();
                },
              ),
              DetailTextButton(
                appThemeData: appThemeData,
                text: "Clear",
                onPressed: (button) {
                  onActionReturn(SimpleButtonActions.listClear, Path.empty());
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

Future<void> showLocalFilesDialog(final BuildContext context, final AppThemeData appThemeData, List<String> files, final Function(String) onSelect, final void Function(SimpleButtonActions) onAction) async {
  final style = BorderSide(color: appThemeData.screenForegroundColour(true), width: 2);
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        actionsPadding: EdgeInsets.fromLTRB(appThemeData.buttonGap(3), 0, 0, appThemeData.buttonGap(1)),
        insetPadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        backgroundColor: appThemeData.dialogBackgroundColor,
        title: Text('Choose File', style: appThemeData.tsMedium),
        content: SingleChildScrollView(
          child: ListBody(children: [
            appThemeData.horizontalLine,
            for (int i = 0; i < files.length; i++) ...[
              TextButton(
                child: Text(files[i], style: appThemeData.tsMediumBold),
                onPressed: () {
                  onSelect(files[i]);
                  Navigator.of(context).pop();
                },
              ),
              appThemeData.horizontalLine,
            ],
            appThemeData.verticalGapBox(1),
            DetailTextButton(
              gaps: 0,
              appThemeData: appThemeData,
              text: "Create a new file",
              onPressed: (button) {
                onAction(SimpleButtonActions.ok);
                Navigator.of(context).pop();
              },
            )
          ]),
        ),
        actions: <Widget>[
          DetailTextButton(
            appThemeData: appThemeData,
            text: "Cancel",
            onPressed: (button) {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

Future<void> showSearchDialog(final BuildContext context, final AppThemeData appThemeData, final List<String> prevList, final Function(String) onSelect) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: appThemeData.dialogBackgroundColor,
        insetPadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        title: Text('Previous Searches', style: appThemeData.tsMedium),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              appThemeData.horizontalLine,
              for (int i = 0; i < prevList.length; i++) ...[
                TextButton(
                  child: Text(prevList[i], style: appThemeData.tsMediumBold),
                  onPressed: () {
                    onSelect(prevList[i]);
                    Navigator.of(context).pop();
                  },
                ),
                appThemeData.horizontalLine,
              ]
            ],
          ),
        ),
        actions: <Widget>[
          DetailTextButton(
            appThemeData: appThemeData,
            text: "Cancel",
            onPressed: (button) {
              onSelect("");
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

Future<void> showModalButtonsDialog(final BuildContext context, final AppThemeData appThemeData, final String title, final List<String> texts, final List<String> buttons, final Path path, final void Function(Path, String) onResponse) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: appThemeData.dialogBackgroundColor,
        insetPadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        title: Text(title, style: appThemeData.tsMedium),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              for (int i = 0; i < texts.length; i++) ...[
                (texts[i].startsWith('#')) ? Container(alignment: Alignment.center, color: appThemeData.primary.dark, child: Text(texts[i].substring(1), style: appThemeData.tsMedium)) : Text(texts[i], style: appThemeData.tsMedium),
              ]
            ],
          ),
        ),
        actions: <Widget>[
          Row(
            children: [
              for (int i = 0; i < buttons.length; i++) ...[
                DetailTextButton(
                  appThemeData: appThemeData,
                  text: buttons[i],
                  onPressed: (button) {
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

Future<void> showModalInputDialog(final BuildContext context, final AppThemeData appThemeData, final ScreenSize screenSize, final String title, final String currentValue, final List<OptionsTypeData> options, final OptionsTypeData currentOption, final bool isRename, final bool isPassword, final void Function(SimpleButtonActions, String, OptionsTypeData) onAction, final String Function(String, String, OptionsTypeData, OptionsTypeData) externalValidate) async {
  var updatedText = currentValue;
  var updatedType = currentOption;
  var shouldDisplayMarkdownHelp = false;
  var shouldDisplayMarkdownPreview = false;

  final okButtonManager = DetailTextButtonManager(
    text: "OK",
    enabled: false,
    appThemeData: appThemeData,
    onPressed: (button) {
      onAction(SimpleButtonActions.ok, updatedText, updatedType);
      Navigator.of(context).pop();
    },
  );

  final cancelButton = DetailTextButton(
    text: "CANCEL",
    appThemeData: appThemeData,
    onPressed: (button) {
      Navigator.of(context).pop();
    },
  );

  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      if (currentOption == optionTypeDataMarkDown && !isRename && !isPassword) {
        return AlertDialog(
          backgroundColor: appThemeData.dialogBackgroundColor,
          title: Text(title, style: appThemeData.tsMedium),
          content: MarkDownInputField(
            appThemeData: appThemeData,
            initialText: currentValue,
            onValidate: (ix, vx, it, vt) {
              okButtonManager.setEnabled(ix.trim() != vx.trim());
              updatedText = vx;
              updatedType = vt;
              return "";
            },
            height: screenSize.height - 100,
            width: screenSize.width,
            shouldDisplayHelp: (flipValue) {
              if (flipValue) {
                shouldDisplayMarkdownHelp = !shouldDisplayMarkdownHelp;
                if (shouldDisplayMarkdownHelp) {
                  shouldDisplayMarkdownPreview = false;
                }
              }
              return shouldDisplayMarkdownHelp;
            },
            shouldDisplayPreview: (flipValue) {
              if (flipValue) {
                shouldDisplayMarkdownPreview = !shouldDisplayMarkdownPreview;
                if (shouldDisplayMarkdownPreview) {
                  shouldDisplayMarkdownHelp = false;
                }
              }
              return shouldDisplayMarkdownPreview;
            },
            dataAction: (detailAction) {
              onAction(SimpleButtonActions.link, detailAction.oldValue, optionTypeDataLink);
              return Path.empty();
            },
          ),
          actions: [
            Row(
              children: [cancelButton, okButtonManager.widget],
            ),
          ],
        );
      }

      return AlertDialog(
        backgroundColor: appThemeData.dialogBackgroundColor,
        title: Text(title, style: appThemeData.tsMedium),
        content: ValidatedInputField(
          options: options,
          isPassword: isPassword,
          initialOption: currentOption,
          initialValue: currentValue,
          prompt: "Input: ${isRename ? "New Name" : "[type]"}",
          appThemeData: appThemeData,
          onSubmit: (text, type) {},
          onValidate: (ix, vx, it, vt) {
            final validMsg = externalValidate(ix, vx, it, vt);
            if (validMsg.isNotEmpty) {
              okButtonManager.setEnabled(false);
            } else {
              if (it.notEqual(vt) || (ix != vx)) {
                okButtonManager.setEnabled(true);
                updatedType = vt;
                updatedText = vx;
              } else {
                okButtonManager.setEnabled(false);
              }
            }
            return validMsg;
          },
        ),
        actions: [
          Row(
            children: [cancelButton, okButtonManager.widget],
          ),
        ],
      );
    },
  );
}