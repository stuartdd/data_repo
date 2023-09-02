import 'package:data_repo/config.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'data_types.dart';
import 'path.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

// const _styleSmall = TextStyle(fontFamily: 'Code128', fontSize: 20.0, color: Colors.black);
// const _styleSmallDisabled = TextStyle(fontFamily: 'Code128', fontSize: 20.0, color: Colors.grey);
// const _inputTextStyle = TextStyle(fontFamily: 'Code128', fontSize: 30.0, color: Colors.black);
const _trueStr = "true";
const _falseStr = "false";
const helpText = """# # Heading 1 (one more # for each sub heading)
## ## Heading 2  (Use blank lines before and after headings)
_\\_Italic\\__ \\_\\___Bold__\\_\\_ \\_\\_\\____BoldItalic___\\_\\_\\_. One Two or Three underscore.

Escape using '\\\\'. 

For a 'New Line': Use an empty line. Otherwise it is a paragraph. Don't have empty spaces at the start of a line.

> > Block Quotes. Note space after >

1. First list line (Ordered Lists)
    1. Sublist (4 spaces indent)
2. Second List Line

- Un-ordered list start line with a dash+space '- '

``Code Blocks surround with 'backtick'. Use 2 to include a backtick `
``

Code block Special chars use &code; where code = lt, gt, amp

Horizontal line use 3 '*' or 3 '-' or 3 '_'
___
To add an image, add an exclamation mark (!), followed by alt text in brackets, and the path or URL to the image asset in parentheses. You can optionally add a title in quotation marks after the path or URL.

mages ``![alt text](images/image.jpg "Comment")``

[Link](https://www.markdownguide.org/basic-syntax/#images-1) ``[Link](https://www.markdownguide.org/basic-syntax/#images-1)``
""";

class DetailIconButton extends StatefulWidget {
  final bool show;
  final bool enabled;
  final Function() onPressed;
  final int timerMs;
  final IconData iconData;
  final String tooltip;
  final AppThemeData appThemeData;
  final EdgeInsetsGeometry padding;
  const DetailIconButton({super.key, this.show = true, this.enabled = true, required this.onPressed, this.timerMs = 100, required this.iconData, this.tooltip = "", required this.appThemeData, this.padding = const EdgeInsets.fromLTRB(1, 1, 1, 0)});
  @override
  State<DetailIconButton> createState() => _DetailIconButton();
}

class _DetailIconButton extends State<DetailIconButton> {
  bool grey = false;

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.show) {
      return IconButton(
        padding: widget.padding,
        icon: Icon(widget.iconData, color: widget.appThemeData.screenForegroundColour(widget.enabled && !grey)),
        tooltip: widget.tooltip,
        onPressed: () {
          if (!widget.enabled) {
            return;
          }
          if (grey) {
            return;
          }
          setState(() {
            grey = true;
          });
          Timer(const Duration(milliseconds: 5), () {
            if (mounted) {
              widget.onPressed();
              Timer(Duration(milliseconds: 15 + widget.timerMs), () {
                if (mounted) {
                  setState(() {
                    grey = false;
                  });
                }
              });
            }
          });
        },
      );
    } else {
      return const SizedBox(width: 0);
    }
  }
}

class DetailButton extends StatefulWidget {
  DetailButton({super.key, required this.onPressed, required this.text, this.timerMs = 100, this.show = true, this.disable = false, required this.appThemeData});
  final bool show;
  final bool disable;
  final AppThemeData appThemeData;
  final Function() onPressed;
  final String text;
  final int timerMs;
  void Function(bool)? _setDisabled;

  void setDisabled(bool dis) {
    if (_setDisabled != null) {
      _setDisabled!(dis);
    } else {
      debugPrint("DetailButton _setDisabled is null");
    }
  }

  @override
  State<DetailButton> createState() => _DetailButtonState();
}

class _DetailButtonState extends State<DetailButton> {
  bool grey = false;

  @override
  initState() {
    super.initState();
    widget._setDisabled = (dis) {
      setState(() {
        grey = dis;
      });
    };
    grey = widget.disable;
  }

  @override
  Widget build(BuildContext context) {
    final style = BorderSide(color: widget.appThemeData.screenForegroundColour(!grey), width: 2);
    if (widget.show) {
      return Row(
        children: [
          SizedBox(
            height: 40,
            child: OutlinedButton(
              onPressed: () {
                if (grey) {
                  return;
                }
                widget.onPressed();
                setState(() {
                  grey = true;
                });
                Timer(Duration(milliseconds: 15 + widget.timerMs), () {
                  if (mounted) {
                    setState(() {
                      grey = false;
                    });
                  }
                });
              },
              style: OutlinedButton.styleFrom(side: style),
              child: Text(widget.text, style: grey ? widget.appThemeData.tsMediumDisabled : widget.appThemeData.tsMedium),
            ),
          ),
          const SizedBox(width: 8)
        ],
      );
    } else {
      return const SizedBox(width: 0);
    }
  }
}

class OptionListWidget extends StatefulWidget {
  final List<OptionsTypeData> optionList;
  final OptionsTypeData selectedOption;
  final void Function(String, OptionsTypeData) onSelect;
  final AppThemeData appThemeData;
  const OptionListWidget({super.key, required this.optionList, required this.selectedOption, required this.onSelect, required this.appThemeData});
  // Find the element type index for a given type name.
  //    -1 indicated not found
  int _findIndexFroOption(String key) {
    if (optionList.isNotEmpty) {
      for (int i = 0; i < optionList.length; i++) {
        if (optionList[i].key == key) {
          return i;
        }
      }
    }
    return -1;
  }

  @override
  State<OptionListWidget> createState() => _OptionListWidgetState();
}

class _OptionListWidgetState extends State<OptionListWidget> {
  OptionsTypeData _currentSelect = optionTypeDataNotFound;

  @override
  initState() {
    super.initState();
    _currentSelect = widget.selectedOption;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.optionList.isEmpty) {
      return const SizedBox(
        height: 0,
        width: 0,
      );
    }
    return Column(
      children: <Widget>[
        for (int i = 0; i < widget.optionList.length; i++) ...[
          RadioListTile<String>(
            title: Text(
              widget.optionList[i].description,
              style: widget.appThemeData.tsMedium,
            ),
            value: widget.optionList[i].key,
            activeColor: widget.appThemeData.screenForegroundColour(true),
            dense: true,
            groupValue: _currentSelect.key,
            onChanged: (String? value) {
              setState(() {
                if (value != null) {
                  debugPrint("Select $value");
                  final i = widget._findIndexFroOption(value);
                  if (i >= 0) {
                    _currentSelect = widget.optionList[i];
                    widget.onSelect(value, widget.optionList[i]);
                  }
                }
              });
            },
          ),
        ],
      ],
    );
  }
}

class MarkDownInputField extends StatefulWidget {
  final String initialText;
  final double height;
  final double width;
  final AppThemeData appThemeData;
  final bool Function(bool) shouldDisplayHelp;
  final bool Function(bool) shouldDisplayPreview;
  final String Function(String, String, OptionsTypeData, OptionsTypeData) onValidate;

  final Path Function(DetailAction) dataAction;

  const MarkDownInputField({super.key, required this.initialText, required this.onValidate, required this.height, required this.width, required this.shouldDisplayHelp, required this.shouldDisplayPreview, required this.dataAction, required this.appThemeData});
  @override
  State<MarkDownInputField> createState() => _MarkDownInputField();
}

class _MarkDownInputField extends State<MarkDownInputField> {
  final controller = TextEditingController();
  @override
  initState() {
    super.initState();
    controller.text = widget.initialText;
  }

  void doOnTapLink(String text, String? href, String title) {
    if (href != null) {
      widget.dataAction(DetailAction(
        ActionType.link,
        true,
        Path.empty(),
        oldValue: href,
        oldValueType: optionTypeDataString,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: Column(
        children: [
          widget.shouldDisplayPreview(false)
              ? Container(
                  color: widget.appThemeData.hiLight.light,
                  child: Markdown(
                    data: controller.text,
                    selectable: true,
                    shrinkWrap: true,
                    styleSheetTheme: MarkdownStyleSheetBaseTheme.platform,
                    onTapLink: doOnTapLink,
                  ))
              : const SizedBox(
                  height: 0,
                ),
          widget.shouldDisplayHelp(false)
              ? Container(
                  color: widget.appThemeData.secondary.light,
                  child: Markdown(
                    data: helpText,
                    selectable: true,
                    shrinkWrap: true,
                    styleSheetTheme: MarkdownStyleSheetBaseTheme.platform,
                    onTapLink: doOnTapLink,
                  ))
              : const SizedBox(
                  height: 0,
                ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.multiline,
              style: widget.appThemeData.tsMedium,
              cursorColor: widget.appThemeData.cursorColor,
              maxLines: null,
              expands: true,
              onChanged: (value) {
                setState(() {
                  widget.onValidate(widget.initialText, controller.text, optionTypeDataString, optionTypeDataString);
                });
              },
            ),
          ),
          Row(
            children: [
              DetailButton(
                appThemeData: widget.appThemeData,
                text: widget.shouldDisplayHelp(false) ? 'Hide Help' : "Show Help",
                onPressed: () {
                  setState(() {
                    widget.shouldDisplayHelp(true);
                  });
                },
              ),
              DetailButton(
                appThemeData: widget.appThemeData,
                text: widget.shouldDisplayPreview(false) ? 'Hide Preview' : "Show Preview",
                onPressed: () {
                  setState(() {
                    widget.shouldDisplayPreview(true);
                  });
                },
              )
            ],
          ),
        ],
      ),
    );
  }
}

class ValidatedInputField extends StatefulWidget {
  ValidatedInputField({super.key, this.initialValue = "", this.isPassword = false, this.onSubmit = null, required this.onValidate, required this.prompt, this.options = const [], this.initialOption = optionsDataTypeEmpty, required this.appThemeData});
  final String initialValue;
  final List<OptionsTypeData> options;
  final OptionsTypeData initialOption;
  final String prompt;
  final bool isPassword;
  final void Function(String, OptionsTypeData)? onSubmit;
  final String Function(String, String, OptionsTypeData, OptionsTypeData) onValidate;
  final controller = TextEditingController();
  final AppThemeData appThemeData;
  void Function(String)? _reValidate;
  void reValidate({String id = ""}) {
    if (_reValidate != null) {
      _reValidate!(id);
    } else {
      debugPrint("ValidatedInputField _reValidate(id=$id) is null");
    }
  }

  @override
  State<ValidatedInputField> createState() => _ValidatedInputFieldState();
}

class _ValidatedInputFieldState extends State<ValidatedInputField> {
  String validateResponse = "";
  String initial = "";
  String current = "";
  OptionsTypeData initialOption = optionTypeDataNotFound;
  OptionsTypeData currentOption = optionTypeDataNotFound;
  bool obscurePw = true;

  @override
  initState() {
    super.initState();
    initial = widget.initialValue.trim();
    current = initial;
    initialOption = widget.initialOption;
    currentOption = initialOption;
    widget.controller.text = current;
    validateResponse = widget.onValidate(initial, current, initialOption, currentOption);
    obscurePw = widget.isPassword;
    widget._reValidate = (id) {
      _validate();
    };
  }

  void _validate() {
    setState(() {
      validateResponse = widget.onValidate(initial, current, initialOption, currentOption);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OptionListWidget(
            appThemeData: widget.appThemeData,
            optionList: widget.options,
            selectedOption: widget.initialOption,
            onSelect: (value, sel) {
              currentOption = sel;
              if (currentOption.elementType == bool) {
                current = _toTrueFalse(current);
              }
              debugPrint("currentOption $currentOption Value '$current'");
              _validate();
            }),
        currentOption.isEmpty
            ? const SizedBox(height: 0)
            : Container(
                alignment: Alignment.centerLeft,
                child: Text(widget.prompt.replaceAll("[type]", currentOption.description), style: widget.appThemeData.tsMedium),
              ),
        (widget.isPassword)
            ? Row(
                children: [
                  IconButton(
                      onPressed: () {
                        setState(() {
                          obscurePw = !obscurePw;
                        });
                      },
                      icon: Icon(obscurePw ? Icons.visibility : Icons.visibility_outlined)),
                  Text(obscurePw ? "Show password" : "Hide password")
                ],
              )
            : const SizedBox(height: 10),
        (validateResponse.isEmpty)
            ? const SizedBox(
                height: 0,
              )
            : Column(children: [
                Container(
                  alignment: Alignment.centerLeft,
                  color: widget.appThemeData.error.light,
                  child: Text(
                    " $validateResponse ",
                    style: widget.appThemeData.tsMedium,
                  ),
                ),
                const SizedBox(
                  height: 10,
                )
              ]),
        (currentOption.elementType == bool)
            ? OptionListWidget(
                appThemeData: widget.appThemeData,
                optionList: optionsForYesNo,
                selectedOption: OptionsTypeData.toTrueFalse(current),
                onSelect: (value, option) {
                  current = option.key;
                  _validate();
                })
            : TextField(
                controller: widget.controller,
                obscureText: widget.isPassword && obscurePw,
                style: widget.appThemeData.tsMedium,
                cursorColor: widget.appThemeData.cursorColor,
                autofocus: true,
                onChanged: (value) {
                  current = value;
                  _validate();
                },
                onSubmitted: (value) {
                  current = value;
                  _validate();
                  if (validateResponse.isEmpty && widget.onSubmit != null) {
                    widget.onSubmit!(current, currentOption);
                  }
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
      ],
    );
  }
}

String _toTrueFalse(String value) {
  final v = value.trim().toLowerCase();
  if (v.contains("tru") || v.contains("yes")) {
    return _trueStr;
  }
  try {
    final i = int.parse(v);
    if (i == 0) {
      return _falseStr;
    }
    return _trueStr;
  } catch (e) {
    return _falseStr;
  }
}
