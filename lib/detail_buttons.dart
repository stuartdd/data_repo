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
const clickTimerMs = 250;

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

abstract class ManageAble {
  void setVisible(bool x);
  void setEnabled(bool x);
}

EdgeInsetsGeometry _getPadding(final EdgeInsetsGeometry? pad, final double top, final double gap, final double fallbackGap) {
  if (pad != null) {
    return pad;
  }
  final g;
  if (gap == 0) {
    g = fallbackGap;
  } else {
    g = gap;
  }
  return EdgeInsets.fromLTRB(2, top, g, 0);
}

class IndicatorIconManager implements ManageAble {
  late final GlobalKey key;
  late final Widget widget;
  IndicatorIconManager(List<IconData> iconData, {required double size, required Color color, EdgeInsets? padding, required int period, required int Function(int, ManageAble) getState, void Function(int, ManageAble)? onClick, bool active = true, bool visible = true}) {
    key = GlobalKey();
    widget = _IndicatorIcon(key: key, iconData, size: size, color: color, period: period, getState: getState);
  }

  @override
  void setVisible(bool x) {
    final cs = key.currentState;
    if (cs != null && cs is ManageAble) {
      (cs as ManageAble).setVisible(x);
    }
  }

  @override
  void setEnabled(bool x) {
    final cs = key.currentState;
    if (cs != null && cs is ManageAble) {
      (cs as ManageAble).setEnabled(x);
    }
  }
}

class _IndicatorIcon extends StatefulWidget {
  final List<IconData> _iconData;
  final double size;
  final Color color;
  final EdgeInsets? padding;
  final int period;
  final bool enabled;
  final bool visible;
  final int Function(int, _IndicatorIconState) getState;
  final void Function(int, _IndicatorIconState)? onClick;
  const _IndicatorIcon(this._iconData, {super.key, required this.size, required this.color, this.padding, required this.period, required this.getState, this.onClick, this.enabled = true, this.visible = true});

  @override
  State<_IndicatorIcon> createState() => _IndicatorIconState();
}

class _IndicatorIconState extends State<_IndicatorIcon> implements ManageAble {
  late bool enabled;
  late bool visible;
  late Timer timer;
  late List<Icon> icons;
  int state = 0;

  @override
  initState() {
    super.initState();
    enabled = widget.enabled;
    visible = widget.visible;
    icons = [];

    for (var icd in widget._iconData) {
      if (widget.size > 2) {
        icons.add(Icon(icd, color: widget.color, size: widget.size));
      } else {
        icons.add(Icon(icd, color: widget.color));
      }
    }

    if (icons.isEmpty) {
      if (widget.size > 2) {
        icons.add(Icon(Icons.check_box_outline_blank, color: widget.color, size: widget.size));
      } else {
        icons.add(Icon(Icons.check_box_outline_blank, color: widget.color));
      }
    }

    if (icons.length == 1) {
      if (widget.size > 2) {
        icons.add(Icon(Icons.indeterminate_check_box_outlined, color: widget.color, size: widget.size));
      } else {
        icons.add(Icon(Icons.indeterminate_check_box_outlined, color: widget.color));
      }
    }

    timer = Timer.periodic(Duration(milliseconds: widget.period), (timer) async {
      if (mounted) {
        if (enabled) {
          final st = widget.getState(state, this);
          if (st != state) {
            setState(() {
              state = st;
            });
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (visible) {
      Widget icon = icons[state % icons.length];
      if (widget.onClick != null) {
        icon = InkWell(
          child: icon,
          onTap: () {
            widget.onClick!(state, this);
          },
        );
      }
      if (widget.padding != null) {
        icon = Padding(padding: widget.padding!, child: icon);
      }
      return icon;
    }
    return const SizedBox(width: 0, height: 0);
  }

  @override
  void setVisible(bool vi) {
    setState(() {
      visible = vi;
    });
  }

  @override
  void setEnabled(bool en) {
    setState(() {
      enabled = en;
    });
  }

  @override
  void dispose() {
    if (timer.isActive) {
      timer.cancel();
    }
    super.dispose();
  }
}

class DetailIconButtonManager implements ManageAble {
  late final GlobalKey key;
  late final Widget widget;
  DetailIconButtonManager({bool visible = true, bool enabled = true, int timerMs = clickTimerMs, required IconData iconData, String tooltip = "", required AppThemeData appThemeData, EdgeInsetsGeometry? padding, required Function(ManageAble) onPressed}) {
    key = GlobalKey();
    widget = DetailIconButton(key: key, visible: visible, enabled: enabled, timerMs: timerMs, iconData: iconData, tooltip: tooltip, appThemeData: appThemeData, padding: padding, onPressed: onPressed);
  }

  @override
  void setVisible(bool x) {
    final cs = key.currentState;
    if (cs != null && cs is ManageAble) {
      (cs as ManageAble).setVisible(x);
    }
  }

  @override
  void setEnabled(bool x) {
    final cs = key.currentState;
    if (cs != null && cs is ManageAble) {
      (cs as ManageAble).setEnabled(x);
    }
  }
}

class DetailIconButton extends StatefulWidget {
  final bool visible;
  final bool enabled;
  final Function(ManageAble) onPressed;
  final int timerMs;
  final IconData iconData;
  final String tooltip;
  final AppThemeData appThemeData;
  final EdgeInsetsGeometry? padding;

  const DetailIconButton({super.key, this.visible = true, this.enabled = true, required this.onPressed, this.timerMs = clickTimerMs, required this.iconData, this.tooltip = "", required this.appThemeData, this.padding});
  @override
  State<DetailIconButton> createState() => _DetailIconButtonState();
}

class _DetailIconButtonState extends State<DetailIconButton> implements ManageAble {
  bool grey = false;
  late bool enabled;
  late bool visible;
  @override
  initState() {
    super.initState();
    enabled = widget.enabled;
    visible = widget.visible;
  }

  @override
  Widget build(BuildContext context) {
    final double iSize = widget.appThemeData.iconSize;
    if (visible) {
      return IconButton(
        alignment: Alignment.center,
        padding: widget.padding ?? const EdgeInsets.all(0),
        tooltip: widget.tooltip,
        constraints: BoxConstraints.tightFor(width: iSize + widget.appThemeData.iconGap, height: iSize),
        icon: Icon(widget.iconData, size: iSize, color: widget.appThemeData.screenForegroundColour(widget.enabled && !grey)),
        onPressed: () {
          if (!enabled || grey) {
            return;
          }
          setState(() {
            grey = true;
          });
          Timer(const Duration(milliseconds: 5), () {
            if (mounted) {
              widget.onPressed(this);
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

  @override
  void setVisible(bool vi) {
    setState(() {
      visible = vi;
    });
  }

  @override
  void setEnabled(bool en) {
    setState(() {
      enabled = en;
    });
  }
}

class DetailButton extends StatefulWidget {
  const DetailButton({super.key, required this.onPressed, required this.text, this.timerMs = clickTimerMs, this.visible = true, this.enabled = true, required this.appThemeData});
  final bool visible;
  final bool enabled;
  final AppThemeData appThemeData;
  final Function() onPressed;
  final String text;
  final int timerMs;

  @override
  State<DetailButton> createState() => _DetailButtonState();
}

class _DetailButtonState extends State<DetailButton> implements ManageAble {
  bool grey = false;
  bool enableWidget = true;
  bool visibleButton = true;

  @override
  void setEnabled(bool en) {
    setState(() {
      enableWidget = en;
      grey = !en;
    });
  }

  @override
  void setVisible(bool vi) {
    setState(() {
      visibleButton = vi;
    });
  }

  @override
  initState() {
    super.initState();
    grey = !widget.enabled;
    enableWidget = widget.enabled;
    visibleButton = widget.visible;
  }

  @override
  Widget build(BuildContext context) {
    if (visibleButton) {
      final style = BorderSide(color: widget.appThemeData.screenForegroundColour(!grey), width: 2);
      return Row(
        children: [
          SizedBox(
            height: widget.appThemeData.buttonHeight,
            child: OutlinedButton(
              onPressed: () {
                if (grey || !enableWidget) {
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
          SizedBox(width: widget.appThemeData.buttonGap)
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
                    widget.onSelect(value, _currentSelect);
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

Widget inputTextField(final TextStyle ts, final TextSelectionThemeData theme, final bool isDarkMode, final TextEditingController controller, {final double width = 0, final double height = 0, final bool isPw = false, final String hint = "", final EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(5, 5, 0, 0), final Function(String)? onChange, final Function(String)? setValue}) {
  final Color bc;
  if (theme.cursorColor == null) {
    bc = Colors.black;
  } else {
    bc = theme.cursorColor!;
  }
  return SizedBox(
    height: height < 1 ? null : height,
    width: width < 1 ? null : width,
    child: Theme(
      data: ThemeData(
        textSelectionTheme: theme,
      ),
      child: TextField(
        style: ts,
        decoration: InputDecoration(
          hintText: hint,
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(width: 2, color: isDarkMode ? Colors.white : Colors.black)),
          border: const OutlineInputBorder(),
          contentPadding: padding,
        ),
        autofocus: true,
        onSubmitted: (value) {
          if (setValue != null) {
            setValue(value);
          }
        },
        onChanged: (value) {
          if (onChange != null) {
            onChange(value);
          }
        },
        obscureText: isPw,
        controller: controller,
      ),
    ),
  );
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
    // step back
    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: ListView(
        children: [
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
          SizedBox(
            height: widget.height,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ValidatedInputField extends StatefulWidget {
  ValidatedInputField({super.key, this.initialValue = "", this.isPassword = false, this.onSubmit, required this.onValidate, required this.prompt, this.options = const [], this.initialOption = optionsDataTypeEmpty, required this.appThemeData});
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
                      color: widget.appThemeData.screenForegroundColour(true),
                      onPressed: () {
                        setState(() {
                          obscurePw = !obscurePw;
                        });
                      },
                      icon: Icon(obscurePw ? Icons.visibility : Icons.visibility_outlined, size: widget.appThemeData.iconSize)),
                  Text(obscurePw ? "Show password" : "Hide password", style: widget.appThemeData.tsMedium)
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
                optionList: optionGroupUYesNo,
                selectedOption: OptionsTypeData.toTrueFalseOptionsType(current),
                onSelect: (value, option) {
                  current = option.key;
                  _validate();
                })
            : inputTextField(
                widget.appThemeData.tsMedium,
                widget.appThemeData.textSelectionThemeData,
                widget.appThemeData.darkMode,
                widget.controller,
                height: widget.appThemeData.textInputFieldHeight,
                isPw: widget.isPassword && obscurePw,
                setValue: (value) {
                  current = value;
                  _validate();
                  if (validateResponse.isEmpty && widget.onSubmit != null) {
                    widget.onSubmit!(current, currentOption);
                  }
                },
                onChange: (value) {
                  current = value;
                  _validate();
                },
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
