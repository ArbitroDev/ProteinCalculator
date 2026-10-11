import 'package:flutter/foundation.dart';

/// Does nothing: the web has neither notifications nor watch.
VoidCallback listenToBackgroundChanges(VoidCallback onChange) => () {};

/// Does nothing: the web has neither notifications nor watch.
void notifyBackgroundChange() {}
