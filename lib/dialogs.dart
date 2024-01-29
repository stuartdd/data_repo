/*
 * Copyright (C) 2023 Stuart Davies (stuartdd)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
import 'package:flutter/material.dart';
import 'config.dart';
import 'data_types.dart';
import 'path.dart';
import 'detail_buttons.dart';

Future<void> showOptionsDialog(final BuildContext context, final AppThemeData appThemeData, final Path path, final List<MenuOptionDetails> menuOptionsList, final List<String> sub, final Function(ActionType, Path) onSelect, final Function() onClose) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return Dialog(
        shape: appThemeData.rectangleBorderShape,
        backgroundColor: appThemeData.dialogBackgroundColor,
        child: ListView(
          children: [
            for (int i = 0; i < menuOptionsList.length; i++) ...[
              menuOptionsList[i].enabled && menuOptionsList[i].isNotGroup
                  ? Card(
                      shape: appThemeData.rectangleBorderShape,
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
                              Text(menuOptionsList[i].title(sub), style: appThemeData.tsLarge),
                            ],
                          ),
                        ),
                        subtitle: menuOptionsList[i].hasSubText ? Text(menuOptionsList[i].subTitle(sub), style: appThemeData.tsMedium) : null,
                        onTap: () {
                          if (menuOptionsList[i].enabled) {
                            onSelect(menuOptionsList[i].action, path);
                            Navigator.of(context).pop();
                            onClose();
                          }
                        },
                      ),
                    )
                  : emptyOrGroup(menuOptionsList[i]),
            ]
          ],
        ),
      );
    },
  );
}

Widget emptyOrGroup(MenuOptionDetails mo) {
  if (mo.enabled) {
    return Container(height: 5, color: mo.separatorColour);
  }
  return const SizedBox(height: 0);
}

List<Widget> _stringsToTextList(final List<String> values, final int startAt, final Widget separator, final AppThemeData theme) {
  final wl = <Widget>[];
  for (int i = startAt; i < values.length; i++) {
    wl.add(Text(values[i], style: theme.tsMedium));
    wl.add(separator);
  }
  return wl;
}

Future<void> showFileNamePasswordDialog(final BuildContext context, final AppThemeData appThemeData, final String title, final List<String> info, final String Function(SimpleButtonActions, String, String) onAction, final Function() onClose) async {
  final theme = appThemeData;
  var separator = appThemeData.verticalGapBox(1);
  final content = _stringsToTextList(info, 1, separator as SizedBox, theme);

  var fileName = "";
  var password = "";

  final okButtonManager = DetailTextButtonManager(
    text: "OK",
    enabled: false,
    appThemeData: theme,
    onPressed: (button) {
      onAction(SimpleButtonActions.ok, fileName, password);
      Navigator.of(context).pop();
      onClose();
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
      var message = validatePassword(vx, allowEmpty: true);
      if (message.isEmpty) {
        password = vx;
      } else {
        password = "";
      }
      fileNameInput.reValidateImpl(id: "xxx");
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
        shape: appThemeData.rectangleBorderShape,
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
                  onClose();
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
        DetailIconButton(
            appThemeData: appThemeData,
            onPressed: (m) {
              onAction(SimpleButtonActions.select, summaryList.list[i].copyFromPath);
            },
            iconData: Icons.open_in_new,
            tooltip: "Go To"),
        DetailIconButton(
            appThemeData: appThemeData,
            onPressed: (m) {
              onAction(SimpleButtonActions.listRemove, summaryList.list[i].copyFromPath);
            },
            tooltip: "Delete from this list",
            iconData: Icons.delete),
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

Future<void> showCopyMoveDialog(final BuildContext context, final AppThemeData appThemeData, final Path into, final GroupCopyMoveSummaryList summaryList, bool copyMove, final void Function(SimpleButtonActions, Path) onActionReturn, final void Function(SimpleButtonActions, Path) onActionClose, final void Function() onClose) async {
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
        shape: appThemeData.rectangleBorderShape,
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
            onClose();
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
                  onClose();
                },
              ),
              DetailTextButton(
                appThemeData: appThemeData,
                text: "Copy",
                visible: summaryList.hasNoErrors && copyMove,
                onPressed: (button) {
                  onActionReturn(SimpleButtonActions.copy, into);
                  Navigator.of(context).pop();
                  onClose();
                },
              ),
              DetailTextButton(
                appThemeData: appThemeData,
                text: "Move",
                visible: summaryList.hasNoErrors && copyMove,
                onPressed: (button) {
                  onActionReturn(SimpleButtonActions.move, into);
                  Navigator.of(context).pop();
                  onClose();
                },
              ),
              DetailTextButton(
                appThemeData: appThemeData,
                text: "DELETE",
                visible: summaryList.hasNoErrors && !copyMove,
                onPressed: (button) {
                  onActionReturn(SimpleButtonActions.delete, Path.empty());
                  Navigator.of(context).pop();
                  onClose();
                },
              ),
              DetailTextButton(
                appThemeData: appThemeData,
                text: "Clear",
                onPressed: (button) {
                  onActionReturn(SimpleButtonActions.listClear, Path.empty());
                  Navigator.of(context).pop();
                  onClose();
                },
              ),
            ],
          )
        ],
      );
    },
  );
}

Future<void> showFilesListDialog(final BuildContext context, final AppThemeData appThemeData, List<FileListEntry> files, final bool canCreateFile, final Function(String) onSelect, final void Function(SimpleButtonActions) onAction, final Function() onClose) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      final Widget createButton;
      if (canCreateFile) {
        createButton = DetailTextButton(
          gaps: 0,
          appThemeData: appThemeData,
          text: "Create a new LOCAL file",
          onPressed: (button) {
            onAction(SimpleButtonActions.ok);
            Navigator.of(context).pop();
            onClose();
          },
        );
      } else {
        createButton = const SizedBox(height: 0);
      }
      final help = Row(children: [
        Text("Key:", style: appThemeData.tsMediumBold),
        appThemeData.iconGapBox(0.5),
        appThemeData.scaledIcon(FileListEntry.localIcon),
        appThemeData.iconGapBox(0.1),
        Text("Local", style: appThemeData.tsMediumBold),
        appThemeData.iconGapBox(0.6),
        appThemeData.scaledIcon(FileListEntry.remoteIcon),
        appThemeData.iconGapBox(0.1),
        Text("Remote", style: appThemeData.tsMediumBold),
        appThemeData.iconGapBox(0.5),
        appThemeData.scaledIcon(FileListEntry.syncedIcon),
        appThemeData.iconGapBox(0.1),
        Text("Both", style: appThemeData.tsMediumBold),
      ]);

      return AlertDialog(
        shape: appThemeData.rectangleBorderShape,
        actionsPadding: EdgeInsets.fromLTRB(appThemeData.buttonGap * 3, 0, 0, appThemeData.buttonGap),
        insetPadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        backgroundColor: appThemeData.dialogBackgroundColor,
        title: Text('Choose a File', style: appThemeData.tsMedium),
        content: SingleChildScrollView(
          child: ListBody(children: [
            help,
            appThemeData.horizontalLine,
            for (int i = 0; i < files.length; i++) ...[
              Row(
                children: [
                  appThemeData.scaledIcon(files[i].locationIcon),
                  appThemeData.iconGapBox(0.5),
                  appThemeData.scaledIcon(files[i].stateIcon),
                  TextButton(
                    child: Text(files[i].name, style: appThemeData.tsMediumBold),
                    onPressed: () {
                      onSelect(files[i].name);
                      Navigator.of(context).pop();
                      onClose();
                    },
                  ),
                ],
              ),
              appThemeData.horizontalLine,
            ],
            appThemeData.verticalGapBox(1),
            createButton
          ]),
        ),
        actions: <Widget>[
          DetailTextButton(
            appThemeData: appThemeData,
            text: "Cancel",
            onPressed: (button) {
              Navigator.of(context).pop();
              onClose();
            },
          ),
        ],
      );
    },
  );
}

Future<void> showSearchDialog(final BuildContext context, final AppThemeData appThemeData, final List<String> prevList, final Function(String) onSelect, final Function() onClose) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        shape: appThemeData.rectangleBorderShape,
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
                    onClose();
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
              onClose();
            },
          ),
        ],
      );
    },
  );
}

Future<void> showModalButtonsDialog(final BuildContext context, final AppThemeData appThemeData, final String title, final List<String> texts, final List<String> buttons, final Path path, final void Function(Path, String) onResponse, final Function() onClose) async {
  debugPrint("showDialog");
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        shape: appThemeData.rectangleBorderShape,
        backgroundColor: appThemeData.dialogBackgroundColor,
        insetPadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        title: Text(title, style: appThemeData.tsMediumBold),
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
                    onClose();
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

Future<void> showMyAboutDialog(final BuildContext context, final Color foreground, final Color background, final ScreenSize screenSize, final String aboutDataMd, final void Function(DetailAction) onAction, final void Function() onClose) {
  const tsHeading = TextStyle(fontSize: (30.0), color: Colors.black, fontWeight: FontWeight.bold);

  const borderRadius = BorderRadius.all(Radius.circular(4));
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: borderRadius,
        ),
        backgroundColor: background,
        title: const Text("About: Data Repo", style: tsHeading),
        content: SizedBox(
          width: screenSize.width,
          child: markdownDisplayWidget(true, aboutDataMd, background, (text, href, title) {
            if (href != null) {
              onAction(DetailAction(
                ActionType.link,
                true,
                Path.empty(),
                oldValue: href,
                oldValueType: optionTypeDataString,
              ));
            }
          }),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
              side: BorderSide(color: foreground, width: 2),
              borderRadius: borderRadius,
            )),
            onPressed: () {
              Navigator.of(context).pop();
              onClose();
            },
            child: const Text("OK", style: tsHeading),
          )
        ],
      );
    },
  );
}

Future<void> showModalInputDialog(final BuildContext context, final AppThemeData appThemeData, final ScreenSize screenSize, final String currentValue, final bool isRename, final bool isPassword, final void Function(SimpleButtonActions, String, OptionsTypeData) onAction, final String Function(String, String, OptionsTypeData, OptionsTypeData) externalValidate, final Function() onClose, {final List<OptionsTypeData> options = const [], final OptionsTypeData currentOption = optionsDataTypeEmpty, final String title = ""}) async {
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
      onClose();
    },
  );

  final cancelButton = DetailTextButton(
    text: "CANCEL",
    appThemeData: appThemeData,
    onPressed: (button) {
      Navigator.of(context).pop();
      onClose();
    },
  );

  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      if (currentOption == optionTypeDataMarkDown && !isRename && !isPassword) {
        return AlertDialog(
          shape: appThemeData.rectangleBorderShape,
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
        shape: appThemeData.rectangleBorderShape,
        backgroundColor: appThemeData.dialogBackgroundColor,
        title: Text(title, style: appThemeData.tsMedium),
        content: ValidatedInputField(
          options: options,
          isPassword: isPassword,
          isRename: isRename,
          initialOption: currentOption,
          initialValue: currentValue,
          prompt: "Input: ${isRename ? "New Name" : "[type]"}",
          appThemeData: appThemeData,
          onSubmit: (text, type) {
            if (okButtonManager.getEnabled()) {
              onAction(SimpleButtonActions.ok, updatedText, updatedType);
              Navigator.of(context).pop();
              onClose();
            }
          },
          onValidate: (ix, vx, it, vt) {
            String validMsg;
            if (isPassword) {
              validMsg = validatePassword(vx);
              if (validMsg.isEmpty) {
                validMsg = externalValidate(ix, vx, it, vt);
              }
            } else {
              validMsg = externalValidate(ix, vx, it, vt);
            }
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

String validatePassword(final String pw, {final bool allowEmpty = false}) {
  if (pw.isEmpty) {
    if (allowEmpty) {
      return "";
    }
    return "Password cannot be empty";
  }
  if (pw.length < 5) {
    return "Password more than 4 chars";
  }
  if (pw.length > 15) {
    return "Password: less than 15 chars";
  }
  return "";
}
