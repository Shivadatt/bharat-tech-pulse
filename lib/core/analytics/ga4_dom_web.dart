import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('gtag')
external void _gtag(JSAny? a, [JSAny? b, JSAny? c]);

/// GA4 loader + beacon via the global `gtag` function. Init is idempotent
/// ([isLoaded]) so [AnalyticsService] can call it on every route without ever
/// double-injecting the tag or double-sending the initial `config` hit.
class Ga4Dom {
  static bool isLoaded = false;

  static void init(String measurementId) {
    if (isLoaded || measurementId.isEmpty) return;

    // send_page_view:false suppresses gtag's automatic page_view on `config`
    // so the only page views are the ones AnalyticsService fires deliberately
    // — the guarantee that a route change is measured exactly once.
    web.document.head?.append(_inline(
      r"window.dataLayer=window.dataLayer||[];"
      r"function gtag(){dataLayer.push(arguments);}"
      r"gtag('js',new Date());"
      "gtag('config',"
      "${jsonEncode(measurementId)},"
      r"{'send_page_view':false});",
    ));
    web.document.head?.append(_async(
      'https://www.googletagmanager.com/gtag/js?id=${Uri.encodeComponent(measurementId)}',
    ));
    isLoaded = true;
  }

  static void pageView(String path, {String? title}) {
    if (!isLoaded) return;
    _gtag(
      'event'.toJS,
      'page_view'.toJS,
      <String, Object?>{
        'page_path': path,
        'page_title': ?title,
      }.jsify(),
    );
  }

  static void event(String name, [Map<String, Object?>? params]) {
    if (!isLoaded) return;
    _gtag('event'.toJS, name.toJS, (params ?? const <String, Object?>{}).jsify());
  }

  static web.HTMLScriptElement _inline(String body) {
    final s = web.HTMLScriptElement()..text = body;
    return s;
  }

  static web.HTMLScriptElement _async(String src) {
    final s = web.HTMLScriptElement()
      ..src = src
      ..async = true;
    return s;
  }
}
