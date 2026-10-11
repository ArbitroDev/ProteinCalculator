import 'package:flutter/foundation.dart';

/// An entry of the day deleted on the watch, maybe while out of range of the
/// phone, for the phone to delete. The watch gives it an [id], the same each
/// time it sends it, so it is never made twice.
@immutable
class WatchDeletion {
  const WatchDeletion({
    required this.id,
    required this.entryId,
    required this.time,
  });

  /// Deletion sent by the plugin `watch_link`, null if a value is missing.
  static WatchDeletion? fromChannel(Object? value) {
    if (value case {
      'id': final String id,
      'entryId': final int entryId,
      'time': final int time,
    }) {
      return WatchDeletion(
        id: id,
        entryId: entryId,
        time: DateTime.fromMillisecondsSinceEpoch(time),
      );
    }
    return null;
  }

  final String id;
  final int entryId;

  /// When the entry was added, as the watch got it: the entry of [entryId]
  /// is deleted only if it has that time, its id may name another entry
  /// after a backup was restored.
  final DateTime time;

  bool get isValid => id.isNotEmpty;
}

/// What the phone made of a [WatchDeletion], see `DeleteStatus` in
/// `android/wear/protocol`.
enum WatchDeletionStatus {
  deleted,

  /// Already made from an earlier sending.
  duplicate,

  /// No entry of that id and time: already deleted on the phone, or changed
  /// by a backup restored.
  missing,

  /// Values the phone cannot read.
  invalid,
}
