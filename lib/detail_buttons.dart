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
import 'package:data_repo/config.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'data_types.dart';

import 'path.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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

class InterfaceNotImplementedException implements Exception {
  final String message;
  InterfaceNotImplementedException(this.message);
  String error() {
    return message;
  }
}

abstract class ManageAble {
  void setVisible(bool x);
  bool getVisible();
  void setEnabled(bool x);
  bool getEnabled();
}

class IndicatorIconManager implements ManageAble {
  late final GlobalKey key;
  late final Widget widget;
  IndicatorIconManager(List<IconData> iconData, {required double size, required Color color, EdgeInsets? padding, required int period, required int Function(int, ManageAble) getState, void Function(int, ManageAble)? onClick, bool enabled = true, bool visible = true}) {
    key = GlobalKey();
    widget = _IndicatorIcon(key: key, iconData, size: size, padding: padding, color: color, period: period, getState: getState, onClick: onClick, enabled: enabled, visible: visible);
  }

  ManageAble? _getInstance() {
    final cs = key.currentState;
    if (cs == null) {
      return null;
    }
    if (cs is ManageAble) {
      return (cs as ManageAble);
    }
    return null;
  }

  @override
  void setVisible(bool x) {
    final i = _getInstance();
    if (i != null) {
      i.setVisible(x);
    }
  }

  @override
  void setEnabled(bool x) {
    final i = _getInstance();
    if (i != null) {
      i.setEnabled(x);
    }
  }

  @override
  bool getEnabled() {
    final i = _getInstance();
    if (i != null) {
      return i.getEnabled();
    }
    return true;
  }

  @override
  bool getVisible() {
    final i = _getInstance();
    if (i != null) {
      return i.getVisible();
    }
    return true;
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
  late bool _enabled;
  late bool _visible;
  late Timer _timer;
  late List<Icon> _icons;
  int _state = 0;

  void _setStateMounted(final Function() f) {
    if (mounted) {
      setState(() {
        f();
      });
    }
  }

  @override
  initState() {
    super.initState();
    _enabled = widget.enabled;
    _visible = widget.visible;
    _icons = [];

    for (var icd in widget._iconData) {
      if (widget.size > 2) {
        _icons.add(Icon(icd, color: widget.color, size: widget.size));
      } else {
        _icons.add(Icon(icd, color: widget.color));
      }
    }

    if (_icons.isEmpty) {
      if (widget.size > 2) {
        _icons.add(Icon(Icons.check_box_outline_blank, color: widget.color, size: widget.size));
      } else {
        _icons.add(Icon(Icons.check_box_outline_blank, color: widget.color));
      }
    }

    if (_icons.length == 1) {
      if (widget.size > 2) {
        _icons.add(Icon(Icons.indeterminate_check_box_outlined, color: widget.color, size: widget.size));
      } else {
        _icons.add(Icon(Icons.indeterminate_check_box_outlined, color: widget.color));
      }
    }

    _timer = Timer.periodic(Duration(milliseconds: widget.period), (timer) async {
      if (mounted) {
        if (_enabled) {
          final st = widget.getState(_state, this);
          if (st != _state) {
            _setStateMounted(() {
              _state = st;
            });
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_visible) {
      Widget icon = _icons[_state % _icons.length];
      if (widget.onClick != null) {
        icon = InkWell(
          child: icon,
          onTap: () {
            widget.onClick!(_state, this);
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
    _setStateMounted(() {
      _visible = vi;
    });
  }

  @override
  void setEnabled(bool en) {
    _setStateMounted(() {
      _enabled = en;
    });
  }

  @override
  bool getEnabled() {
    return _enabled;
  }

  @override
  bool getVisible() {
    return _visible;
  }

  @override
  void dispose() {
    if (_timer.isActive) {
      _timer.cancel();
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

  ManageAble? _getInstance() {
    final cs = key.currentState;
    if (cs == null) {
      return null;
    }
    if (cs is ManageAble) {
      return (cs as ManageAble);
    }
    return null;
  }

  @override
  void setVisible(bool x) {
    final i = _getInstance();
    if (i != null) {
      i.setVisible(x);
    }
  }

  @override
  void setEnabled(bool x) {
    final i = _getInstance();
    if (i != null) {
      i.setEnabled(x);
    }
  }

  @override
  bool getEnabled() {
    final i = _getInstance();
    if (i != null) {
      return i.getEnabled();
    }
    return true;
  }

  @override
  bool getVisible() {
    final i = _getInstance();
    if (i != null) {
      return i.getVisible();
    }
    return true;
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
  bool _grey = false;
  late bool _enabled;
  late bool _visible;
  @override
  initState() {
    super.initState();
    _enabled = widget.enabled;
    _visible = widget.visible;
  }

  void _setStateMounted(final Function() f) {
    if (mounted) {
      setState(() {
        f();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double iSize = widget.appThemeData.iconSize;
    if (_visible) {
      return IconButton(
        alignment: Alignment.center,
        padding: widget.padding ?? const EdgeInsets.all(0),
        tooltip: widget.tooltip,
        constraints: BoxConstraints.tightFor(width: iSize + widget.appThemeData.iconGap, height: iSize),
        icon: Icon(widget.iconData, size: iSize, color: widget.appThemeData.screenForegroundColour(_enabled && !_grey)),
        onPressed: () {
          if (!_enabled || _grey) {
            return;
          }
          setState(() {
            _grey = true;
          });
          Future.delayed(const Duration(milliseconds: 5), () {
            if (mounted) {
              widget.onPressed(this);
              Future.delayed(Duration(milliseconds: 15 + widget.timerMs), () {
                _setStateMounted(() {
                  _grey = false;
                });
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
    _setStateMounted(() {
      _visible = vi;
    });
  }

  @override
  void setEnabled(bool en) {
    _setStateMounted(() {
      _enabled = en;
    });
  }

  @override
  bool getEnabled() {
    return _enabled;
  }

  @override
  bool getVisible() {
    return _visible;
  }
}

class DetailTextButtonManager implements ManageAble {
  late final GlobalKey key;
  late final Widget widget;
  DetailTextButtonManager({bool visible = true, bool enabled = true, int timerMs = clickTimerMs, required String text, required AppThemeData appThemeData, required Function(ManageAble) onPressed}) {
    key = GlobalKey();
    widget = DetailTextButton(key: key, text: text, visible: visible, enabled: enabled, timerMs: timerMs, appThemeData: appThemeData, onPressed: onPressed);
  }

  ManageAble? _getInstance() {
    final cs = key.currentState;
    if (cs == null) {
      return null;
    }
    if (cs is ManageAble) {
      return (cs as ManageAble);
    }
    return null;
  }

  @override
  void setVisible(bool x) {
    final i = _getInstance();
    if (i != null) {
      i.setVisible(x);
    }
  }

  @override
  void setEnabled(bool x) {
    final i = _getInstance();
    if (i != null) {
      i.setEnabled(x);
    }
  }

  @override
  bool getEnabled() {
    final i = _getInstance();
    if (i != null) {
      return i.getEnabled();
    }
    return true;
  }

  @override
  bool getVisible() {
    final i = _getInstance();
    if (i != null) {
      return i.getVisible();
    }
    return true;
  }
}

class DetailTextButton extends StatefulWidget {
  const DetailTextButton({super.key, required this.onPressed, required this.text, this.timerMs = clickTimerMs, this.visible = true, this.enabled = true, this.gaps = 1, required this.appThemeData});
  final bool visible;
  final bool enabled;
  final AppThemeData appThemeData;
  final Function(ManageAble) onPressed;
  final String text;
  final int timerMs;
  final int gaps;

  @override
  State<DetailTextButton> createState() => _DetailTextButtonState();
}

class _DetailTextButtonState extends State<DetailTextButton> implements ManageAble {
  bool _grey = false;
  late bool _enabled;
  late bool _visible;
  @override
  initState() {
    super.initState();
    _enabled = widget.enabled;
    _visible = widget.visible;
  }

  void _setStateMounted(final Function() f) {
    if (mounted) {
      setState(() {
        f();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_visible) {
      final style = BorderSide(color: widget.appThemeData.screenForegroundColour(_enabled && !_grey), width: 2);
      final button = SizedBox(
        height: widget.appThemeData.buttonHeight,
        child: TextButton(
          onPressed: () {
            if (_grey || !_enabled) {
              return;
            }
            widget.onPressed(this);
            setState(() {
              _grey = true;
            });
            Future.delayed(Duration(milliseconds: 15 + widget.timerMs), () {
              _setStateMounted(() {
                _grey = false;
              });
            });
          },
          style: OutlinedButton.styleFrom(side: style),
          child: Text(widget.text, style: (_enabled && !_grey) ? widget.appThemeData.tsMedium : widget.appThemeData.tsMediumDisabled),
        ),
      );
      if (widget.gaps == 0) {
        return button;
      }
      return Row(
        children: [button, widget.appThemeData.buttonGapBox(widget.gaps)],
      );
    } else {
      return const SizedBox(width: 0);
    }
  }

  @override
  void setVisible(bool vi) {
    _setStateMounted(() {
      _visible = vi;
    });
  }

  @override
  void setEnabled(bool en) {
    _setStateMounted(() {
      _enabled = en;
    });
  }

  @override
  bool getEnabled() {
    return _enabled;
  }

  @override
  bool getVisible() {
    return _visible;
  }
}

class OptionListWidget extends StatefulWidget {
  final List<OptionsTypeData> optionList;
  final OptionsTypeData selectedOption;
  final void Function(OptionsTypeData) onSelect;
  final AppThemeData appThemeData;
  const OptionListWidget({super.key, required this.optionList, required this.selectedOption, required this.onSelect, required this.appThemeData});
  // Find the element type index for a given type name.
  //    -1 indicated not found
  int _findIndexFroOption(String type) {
    if (optionList.isNotEmpty) {
      for (int i = 0; i < optionList.length; i++) {
        if (optionList[i].functionalType == type) {
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
  int selIndex = 0;

  @override
  initState() {
    super.initState();
    _currentSelect = widget.selectedOption;
    selIndex = widget._findIndexFroOption(_currentSelect.functionalType);
    if (selIndex < 0) {
      selIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.optionList.isEmpty) {
      return const SizedBox(height: 0);
    }
    return Column(
      children: <Widget>[
        for (int i = 0; i < widget.optionList.length; i++) ...[
          Row(
            children: [
              DetailIconButton(
                  onPressed: (button) {
                    setState(() {
                      selIndex = i;
                      _currentSelect = widget.optionList[i];
                      widget.onSelect(_currentSelect);
                    });
                  },
                  iconData: (i == selIndex) ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  appThemeData: widget.appThemeData),
              Text(
                widget.optionList[i].description,
                style: widget.appThemeData.tsMediumBold,
              )
            ],
          ),
          widget.appThemeData.verticalGapBox(2),
        ],
      ],
    );
  }
}

Widget inputTextField(final TextStyle ts, final TextSelectionThemeData theme, final bool isDarkMode, final TextEditingController controller, {final double width = 0, final double height = 0, final bool isPw = false, final String hint = "", final EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(5, 5, 0, 0), final FocusNode? focusNode, final bool autoFocus = true, required final Function(String)? onChange, required final Function(String)? onSubmit}) {
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
        autofocus: autoFocus,
        focusNode: focusNode,
        onSubmitted: (value) {
          if (onSubmit != null) {
            onSubmit(value);
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

void markdownOnTapLink(String text, String? href, String title, Path Function(DetailAction) dataAction) {
  if (href != null) {
    dataAction(DetailAction(
      ActionType.link,
      true,
      Path.empty(),
      oldValue: href,
      oldValueType: optionTypeDataString,
    ));
  }
}

Widget markdownDisplayWidget(bool show, String text, Color background, void Function(String, String?, String) onTapLinkExt, {ScrollController? scrollController}) {
  if (show) {
    return Container(
        color: background,
        alignment: Alignment.topLeft,
        child: Markdown(
          controller: scrollController,
          data: text,
          selectable: true,
          shrinkWrap: true,
          styleSheetTheme: MarkdownStyleSheetBaseTheme.material,
          onTapLink: onTapLinkExt,
        ));
  } else {
    return const SizedBox(height: 0, width: 0);
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
              DetailTextButton(
                appThemeData: widget.appThemeData,
                text: widget.shouldDisplayHelp(false) ? 'Hide Help' : "Show Help",
                onPressed: (button) {
                  setState(() {
                    widget.shouldDisplayHelp(true);
                  });
                },
              ),
              DetailTextButton(
                appThemeData: widget.appThemeData,
                text: widget.shouldDisplayPreview(false) ? 'Hide Preview' : "Show Preview",
                onPressed: (button) {
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
                markdownDisplayWidget(widget.shouldDisplayPreview(false), controller.text, widget.appThemeData.secondary.light, (text, href, title) {
                  markdownOnTapLink(text, href, title, widget.dataAction);
                }),
                markdownDisplayWidget(widget.shouldDisplayHelp(false), helpText, widget.appThemeData.hiLight.light, (text, href, title) {
                  markdownOnTapLink(text, href, title, widget.dataAction);
                }),
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
  ValidatedInputField({super.key, this.initialValue = "", this.isPassword = false, this.autoFocus = true, required this.onSubmit, required this.onValidate, required this.prompt, this.options = const [], this.initialOption = optionsDataTypeEmpty, required this.appThemeData});
  final String initialValue;
  final List<OptionsTypeData> options;
  final OptionsTypeData initialOption;
  final String prompt;
  final bool isPassword;
  final bool autoFocus;
  final void Function(String, OptionsTypeData) onSubmit;
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
      validateResponse = widget.onValidate(initial, current.trim(), initialOption, currentOption);
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
            onSelect: (sel) {
              if (sel.initialValue.isEmpty) {
                current = initial;
              } else {
                current = sel.initialValue;
              }
              widget.controller.text = current;
              currentOption = sel;
              _validate();
            }),
        currentOption.isEmpty
            ? const SizedBox(height: 0)
            : Container(
                alignment: Alignment.topLeft,
                child: Column(
                  children: [Text(widget.prompt.replaceAll("[type]", currentOption.description), style: widget.appThemeData.tsMediumBold), widget.appThemeData.verticalGapBox(2)],
                )),
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
            : const SizedBox(height: 0),
        (validateResponse.isEmpty) // Need to display error message?
            ? const SizedBox(height: 0)
            : Column(children: [
                Container(
                  alignment: Alignment.centerLeft,
                  color: widget.appThemeData.error.light,
                  child: Text(
                    " $validateResponse ",
                    style: widget.appThemeData.tsMedium,
                  ),
                ),
                widget.appThemeData.verticalGapBox(1)
              ]),
        (currentOption.dataValueType == bool)
            ? OptionListWidget(
                // True or false
                appThemeData: widget.appThemeData,
                optionList: optionGroupUYesNo,
                selectedOption: OptionsTypeData.toTrueFalseOptionsType(current),
                onSelect: (option) {
                  current = option.functionalType;
                  _validate();
                })
            : inputTextField(
                // Text input
                widget.appThemeData.tsMedium,
                widget.appThemeData.textSelectionThemeData,
                widget.appThemeData.darkMode,
                widget.controller,
                height: widget.appThemeData.textInputFieldHeight,
                isPw: widget.isPassword && obscurePw,
                autoFocus: widget.autoFocus,
                onSubmit: (value) {
                  current = value;
                  _validate();
                  if (validateResponse.isEmpty) {
                    widget.onSubmit(current, currentOption);
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
