#!/usr/bin/env bash
# FND-002A — browser capability probe.
#
# Feature-detects the browser APIs the web notification and persistence
# strategies depend on, in the real installed browser, over an http://localhost
# origin (a secure context — file:// is not, and would report false negatives
# for service workers and OPFS).
#
# What this DOES prove: whether the APIs exist in this browser.
# What this does NOT prove: that FCM delivers a message, or that Drift's OPFS
# backend works end to end. Those need a Firebase project and a built web app.
set -uo pipefail
cd "$(dirname "$0")/.."

CHROME="${CHROME_BIN:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
if [ ! -x "$CHROME" ]; then
  echo "NOT RUN: Chrome not found at '$CHROME' (override with CHROME_BIN)"
  exit 2
fi

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"; [ -n "${server_pid:-}" ] && kill "$server_pid" 2>/dev/null' EXIT

cat > "$workdir/probe.html" <<'HTML'
<!doctype html><meta charset="utf-8"><title>probe</title><body><pre id="out">
</pre><script>
const checks = {
  secureContext:        () => window.isSecureContext === true,
  serviceWorker:        () => 'serviceWorker' in navigator,
  pushManager:          () => 'PushManager' in window,
  notificationApi:      () => 'Notification' in window,
  notificationPerm:     () => ('Notification' in window) ? Notification.permission : 'n/a',
  indexedDB:            () => 'indexedDB' in window,
  sharedWorker:         () => typeof SharedWorker !== 'undefined',
  webWorker:            () => typeof Worker !== 'undefined',
  opfsGetDirectory:     () => !!(navigator.storage && navigator.storage.getDirectory),
  storageEstimate:      () => !!(navigator.storage && navigator.storage.estimate),
  storagePersist:       () => !!(navigator.storage && navigator.storage.persist),
  crossOriginIsolated:  () => window.crossOriginIsolated === true,
  wasm:                 () => typeof WebAssembly === 'object',
  atomicsWait:          () => typeof Atomics !== 'undefined' && typeof Atomics.wait === 'function',
  sharedArrayBuffer:    () => typeof SharedArrayBuffer !== 'undefined',
};
const lines = [];
for (const [k, fn] of Object.entries(checks)) {
  let v; try { v = fn(); } catch (e) { v = 'ERROR:' + e.message; }
  lines.push(k.padEnd(22) + ' = ' + v);
}
(async () => {
  try {
    const est = await navigator.storage.estimate();
    lines.push('storageQuotaBytes'.padEnd(22) + ' = ' + est.quota);
  } catch (e) { lines.push('storageQuotaBytes'.padEnd(22) + ' = unavailable'); }
  lines.push('userAgent'.padEnd(22) + ' = ' + navigator.userAgent);
  document.getElementById('out').textContent = lines.join('\n');
  document.title = 'PROBE-DONE';
})();
</script></body>
HTML

port=8731
(cd "$workdir" && python3 -m http.server "$port" >/dev/null 2>&1) &
server_pid=$!
for _ in $(seq 1 40); do
  curl -sf "http://localhost:$port/probe.html" >/dev/null 2>&1 && break
  perl -e 'select(undef,undef,undef,0.25)'
done

echo "==> browser: $("$CHROME" --version 2>/dev/null)"
echo "==> origin : http://localhost:$port (secure context)"
echo
"$CHROME" --headless --disable-gpu --no-sandbox --virtual-time-budget=6000 \
  --dump-dom "http://localhost:$port/probe.html" 2>/dev/null \
  | sed -n '/<pre id="out">/,/<\/pre>/p' \
  | sed -e 's/<[^>]*>//g' -e '/^[[:space:]]*$/d'
