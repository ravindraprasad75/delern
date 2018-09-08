import 'dart:async';

import 'package:delern_flutter/models/base/stream_muxer.dart';
import 'package:test/test.dart';

void main() {
  test('empty stream', () async {
    var muxer = StreamMuxer({
      'test': Stream.empty(),
    });

    expect(await muxer.isEmpty, true);
  });

  test('error stack trace forwarding', () {
    var muxer = StreamMuxer({
      'test': () async* {
        throw Error();
      }(),
    });

    expect(muxer.first, throwsA((e) => e.stackTrace != null));
  });

  test('error stack trace null when not error', () {
    var muxer = StreamMuxer({
      'test': () async* {
        throw 'nothing';
      }(),
    });

    expect(
        muxer.first,
        throwsA((e) =>
            e.stackTrace == null &&
            e.toString() == '[muxed stream "test"]: nothing'));
  });
}
