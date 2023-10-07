import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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
                      color: appThemeData.detailBackgroundColor,
                      child: ListTile(
                        leading: Icon(menuOptionsList[i].icon, color: appThemeData.screenForegroundColour(true)),
                        title: Container(
                          padding: const EdgeInsets.all(5.0),
                          color: appThemeData.dialogBackgroundColor,
                          child: Text(menuOptionsList[i].s1(sub), style: appThemeData.tsLarge),
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
  final theme = appThemeData;
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
    appThemeData: appThemeData,
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
    appThemeData: appThemeData,
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
              DetailButton(
                appThemeData: appThemeData,
                text: "Cancel",
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              DetailButton(
                appThemeData: appThemeData,
                text: "Copy",
                show: summaryList.hasNoErrors && copyMove,
                onPressed: () {
                  onActionReturn(SimpleButtonActions.copy, into);
                  Navigator.of(context).pop();
                },
              ),
              DetailButton(
                appThemeData: appThemeData,
                text: "Move",
                show: summaryList.hasNoErrors && copyMove,
                onPressed: () {
                  onActionReturn(SimpleButtonActions.move, into);
                  Navigator.of(context).pop();
                },
              ),
              DetailButton(
                appThemeData: appThemeData,
                text: "Remove",
                show: summaryList.hasNoErrors && !copyMove,
                onPressed: () {
                  onActionReturn(SimpleButtonActions.delete, Path.empty());
                  Navigator.of(context).pop();
                },
              ),
              DetailButton(
                appThemeData: appThemeData,
                text: "Clear",
                onPressed: () {
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

Future<void> showLogDialog(final BuildContext context, final AppThemeData appThemeData, final Size screenSize, final String log, final bool Function(String) onTapLink) async {
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
        backgroundColor: appThemeData.dialogBackgroundColor,
        insetPadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        title: Text('Event Log', style: appThemeData.tsMedium),
        content: SingleChildScrollView(
            child: Container(
          color: appThemeData.primary.light,
          height: screenSize.height,
          width: screenSize.width,
          child: Markdown(
            controller: scrollController,
            data: log,
            selectable: true,
            shrinkWrap: true,
            styleSheetTheme: MarkdownStyleSheetBaseTheme.platform,
            onTapLink: (text, href, title) {
              bool ok = true;
              if (href == null) {
                ok = onTapLink(text);
              } else {
                ok = onTapLink(href);
              }
              if (ok) {
                Navigator.of(context).pop();
              }
            },
          ),
        )),
        actions: <Widget>[
          Row(
            children: [
              DetailButton(
                appThemeData: appThemeData,
                text: "TOP",
                onPressed: () {
                  scrollController.animateTo(scrollController.position.minScrollExtent, duration: const Duration(milliseconds: 400), curve: Curves.ease);
                },
              ),
              DetailButton(
                appThemeData: appThemeData,
                text: "BOTTOM",
                onPressed: () {
                  scrollController.animateTo(scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 400), curve: Curves.ease);
                },
              ),
              DetailButton(
                appThemeData: appThemeData,
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

Future<void> showLocalFilesDialog(final BuildContext context, final AppThemeData appThemeData, List<String> files, final Function(String) onSelect, final void Function(SimpleButtonActions) onAction) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: appThemeData.dialogBackgroundColor,
        insetPadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        title: Text('Choose File', style: appThemeData.tsMedium),
        content: SingleChildScrollView(
          child: ListBody(children: [
            for (int i = 0; i < files.length; i++) ...[
              Container(
                height: 1,
                color: appThemeData.screenForegroundColour(true),
              ),
              Container(
                color: appThemeData.primary.medDark,
                child: TextButton(
                  child: Text(files[i], style: appThemeData.tsMedium),
                  onPressed: () {
                    onSelect(files[i]);
                    Navigator.of(context).pop();
                  },
                ),
              ),
              Container(
                height: 1,
                color: appThemeData.screenForegroundColour(true),
              ),
              const SizedBox(
                height: 10,
              ),
            ],
            DetailButton(
              appThemeData: appThemeData,
              text: "Create a file",
              onPressed: () {
                onAction(SimpleButtonActions.ok);
                Navigator.of(context).pop();
              },
            ),
          ]),
        ),
        actions: <Widget>[
          DetailButton(
            appThemeData: appThemeData,
            text: "Cancel",
            onPressed: () {
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
              Container(
                height: 1,
                color: appThemeData.screenForegroundColour(true),
              ),
              for (int i = 0; i < prevList.length; i++) ...[
                TextButton(
                  child: Text(prevList[i], style: appThemeData.tsMedium),
                  onPressed: () {
                    onSelect(prevList[i]);
                    Navigator.of(context).pop();
                  },
                ),
                Container(
                  height: 1,
                  color: appThemeData.screenForegroundColour(true),
                ),
              ]
            ],
          ),
        ),
        actions: <Widget>[
          DetailButton(
            appThemeData: appThemeData,
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
                DetailButton(
                  appThemeData: appThemeData,
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

Future<void> showModalInputDialog(final BuildContext context, final AppThemeData appThemeData, final Size screenSize, final String title, final String currentValue, final List<OptionsTypeData> options, final OptionsTypeData currentOption, final bool isRename, final bool isPassword, final void Function(SimpleButtonActions, String, OptionsTypeData) onAction, final String Function(String, String, OptionsTypeData, OptionsTypeData) externalValidate) async {
  var updatedText = currentValue;
  var updatedType = currentOption;
  var shouldDisplayMarkdownHelp = false;
  var shouldDisplayMarkdownPreview = false;
  var okButton = DetailButton(
    text: "OK",
    disable: true,
    appThemeData: appThemeData,
    onPressed: () {
      onAction(SimpleButtonActions.ok, updatedText, updatedType);
      Navigator.of(context).pop();
    },
  );

  var cancelButton = DetailButton(
    text: "CANCEL",
    disable: false,
    appThemeData: appThemeData,
    onPressed: () {
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
              okButton.setDisabled(ix == vx);
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
              children: [cancelButton, okButton],
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
        actions: [
          Row(
            children: [cancelButton, okButton],
          ),
        ],
      );
    },
  );
}
