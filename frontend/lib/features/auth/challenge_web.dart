import 'dart:js_interop';

import 'challenge.dart';

@JS('prQueueChallenge.request')
external JSPromise<JSString> _request(JSString siteKey, JSString theme);
@JS('prQueueChallenge.cancel')
external void _cancel();

Future<String> requestChallenge(String siteKey, String theme) async {
  try {
    return (await _request(siteKey.toJS, theme.toJS).toDart).toDart;
  } catch (_) {
    throw const ChallengeException();
  }
}

void cancelChallenge() => _cancel();
