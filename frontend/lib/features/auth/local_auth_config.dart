const localAuthCallback = 'http://127.0.0.1:4173/';

// The local adapter stays separate from P05's explicit hosted trial config.
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
