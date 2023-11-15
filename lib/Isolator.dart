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
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_window_close/flutter_window_close.dart';

const String _prefix = ".data_repo_lock_";
const int _range = 100000;

class Isolator {
  late final String name;
  final String path;
  bool locked = false;

  Isolator(this.path) {
    _forEachLockFile(path, (fileName) {
      locked = true;
    });

    String r = "${_range + Random().nextInt(_range) - _range}";
    name = "$path${Platform.pathSeparator}$_prefix$r";

    if (locked) {
      return;
    }

    File(name).writeAsStringSync("LOCK");
  }

  clean() {
    _forEachLockFile(path, (fileName) {
      _removeLockFile(fileName);
    });
  }

  close() {
    _removeLockFile(name);
  }

  bool shouldStop() {
    return !File(name).existsSync();
  }

  MyLockedPage lockPage(String title) {
    return MyLockedPage(this, title);
  }

  _forEachLockFile(final String path, Function(String) onEach) {
    final dirList = Directory(path).listSync(recursive: false);
    for (FileSystemEntity n in dirList) {
      if (n is File) {
        final fn = File(n.path).uri.pathSegments.last;
        if (fn.startsWith(_prefix)) {
          onEach(fn);
        }
      }
    }
  }

  _removeLockFile(String fileName) {
    try {
      File(fileName).deleteSync();
    } catch (e) {
      debugPrint("$e");
    }
  }
}

class MyLockedPage extends StatefulWidget {
  const MyLockedPage(this._isolator, this.title, {super.key});
  final String title;
  final Isolator _isolator;

  @override
  State<MyLockedPage> createState() => _MyLockedPageState();
}

const double gap = 15;
const style = BorderSide(color: Colors.black, width: 2);
const tsLarge = TextStyle(fontSize: (25.0), color: Colors.black);
const tsLarger = TextStyle(fontSize: (40.0), color: Colors.black, fontWeight: FontWeight.bold);
const SizedBox spacer = SizedBox(height: gap);

class _MyLockedPageState extends State<MyLockedPage> {
  @override
  Widget build(BuildContext context) {
    FlutterWindowClose.setWindowShouldCloseHandler(() async {
      return true;
    });

    return Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.tealAccent,
        body: SafeArea(
          maintainBottomViewPadding: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("WARNING", style: tsLarger),
              spacer,
              const Text("The App is already running.", style: tsLarge),
              spacer,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    style: OutlinedButton.styleFrom(side: style, minimumSize: const Size(200, gap * 4)),
                    onPressed: () {
                      widget._isolator.clean();
                      Timer(const Duration(seconds: 2), () {
                        exit(0);
                      });
                    },
                    child: const Text("Unlock", style: tsLarge),
                  ),
                ],
              ),
              spacer,
              const Text("This will STOP the running App.", style: tsLarge),
              spacer,
              const Text("All changes made to the data", style: tsLarge),
              spacer,
              const Text("in the App WILL BE LOST.", style: tsLarge),
              spacer,
              const Text("You can then start the App again.", style: tsLarge),
              spacer,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    style: OutlinedButton.styleFrom(side: style, minimumSize: const Size(200, gap * 4)),
                    onPressed: () {
                      exit(0);
                    },
                    child: const Text("Close", style: tsLarge),
                  ),
                ],
              ),
              spacer,
              const Text("Will do nothing.", style: tsLarge),
            ],
          ),
        ));
  }
}
