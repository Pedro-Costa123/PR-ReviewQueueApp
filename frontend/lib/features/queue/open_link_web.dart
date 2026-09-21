import 'package:web/web.dart' as web;

void openEnterpriseLink(String url) {
  // Called synchronously from a user gesture, with a freshly validated URL.
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..target = '_blank'
    ..rel = 'noopener noreferrer'
    ..referrerPolicy = 'no-referrer';
  anchor.click();
}
