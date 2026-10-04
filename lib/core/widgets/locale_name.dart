import 'package:flutter/widgets.dart';

extension LocaleName on BuildContext {
  /// Language of the app, to format numbers and dates: "fr", "en".
  String get localeName => Localizations.localeOf(this).toString();
}
