import 'package:flutter/foundation.dart';

/// Selected bottom-navigation tab, so any screen can switch tabs.
class ShellController extends ChangeNotifier {
  static const home = 0;
  static const map = 1;
  static const history = 2;
  static const impact = 3;

  int _index = home;

  int get index => _index;

  void goTo(int index) {
    if (index == _index) return;
    _index = index;
    notifyListeners();
  }
}
