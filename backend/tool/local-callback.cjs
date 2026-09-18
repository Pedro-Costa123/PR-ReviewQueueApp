// Only migrate the known P04 local setting. Never print or rotate the secret,
// or silently replace an unrelated/hosted callback configuration.
exports.migrateLocalCallback = content => content.replace(
  /^APP_CALLBACK_URL=http:\/\/127\.0\.0\.1:4173\/PR-Review-App-Queue\/(?=\r?$)/m,
  'APP_CALLBACK_URL=http://127.0.0.1:4173/',
);
