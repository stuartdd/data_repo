import 'package:data_repo/config.dart';
import 'package:flutter/material.dart';

import 'data_types.dart';
import 'path.dart';
import 'detail_buttons.dart';

const inputTextTitleStyleHeight = 35.0;

Future<void> showModalInputDialog(final BuildContext context, AppThemeData appThemeData, Size screenSize, final String title, final String currentValue, final List<OptionsTypeData> options, final OptionsTypeData currentOption, final bool isRename, final bool isPassword, final void Function(SimpleButtonActions, String, OptionsTypeData) onAction, final String Function(String, String, OptionsTypeData, OptionsTypeData) externalValidate) async {
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
