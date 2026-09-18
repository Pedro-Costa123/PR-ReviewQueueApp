const localAuthCallback = 'http://127.0.0.1:4173/';

// P05 must explicitly implement hosted login and CAPTCHA before widening this.
bool allowsLocalAuth({
  required String api,
  required String key,
  required Uri page,
}) =>
    api == 'http://127.0.0.1:54321' &&
    key.isNotEmpty &&
    page.origin == Uri.parse(localAuthCallback).origin &&
    page.userInfo.isEmpty &&
    page.path == '/' &&
    !page.hasQuery;
