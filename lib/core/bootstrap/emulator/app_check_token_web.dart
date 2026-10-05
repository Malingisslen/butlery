import 'dart:convert';
import 'dart:js_interop';

@JS('firebase_core.getApp')
external JSObject _getApp();

@JS('firebase_app_check.initializeAppCheck')
external JSObject _initializeAppCheck(JSObject app, _AppCheckOptions options);

@JS('firebase_app_check.CustomProvider')
extension type _CustomProvider._(JSObject _) implements JSObject {
  external factory _CustomProvider(_CustomProviderOptions options);
}

extension type _CustomProviderOptions._(JSObject _) implements JSObject {
  external factory _CustomProviderOptions({JSFunction getToken});
}

extension type _AppCheckOptions._(JSObject _) implements JSObject {
  external factory _AppCheckOptions({
    _CustomProvider provider,
    bool isTokenAutoRefreshEnabled,
  });
}

extension type _Token._(JSObject _) implements JSObject {
  external factory _Token({String token, int expireTimeMillis});
}

/// Registers an App Check provider that hands out an unsigned token. The
/// functions emulator skips App Check signature verification but still
/// refuses a call that carries no token, so callables with enforceAppCheck
/// need one. Production verifies the signature, so this token is worthless
/// there.
void installEmulatorAppCheckToken(String appId) {
  String segment(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final expires = DateTime.now().add(const Duration(days: 1));
  final token = [
    segment({'alg': 'none', 'typ': 'JWT'}),
    segment({
      'sub': appId,
      'iss': 'local-emulator',
      'exp': expires.millisecondsSinceEpoch ~/ 1000,
    }),
    'unsigned',
  ].join('.');

  JSPromise<_Token> getToken() => Future.value(
    _Token(token: token, expireTimeMillis: expires.millisecondsSinceEpoch),
  ).toJS;

  _initializeAppCheck(
    _getApp(),
    _AppCheckOptions(
      provider: _CustomProvider(
        _CustomProviderOptions(getToken: getToken.toJS),
      ),
      isTokenAutoRefreshEnabled: false,
    ),
  );
}
