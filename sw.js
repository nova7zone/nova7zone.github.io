// 최소 서비스 워커: 설치 가능 조건 충족 + 방문한 페이지 오프라인 열람.
// 페이지(HTML)는 네트워크 우선(최신 글 반영), 해시가 붙은 정적 자산은 캐시 우선,
// 해시 없는 자산(아이콘·매니페스트 등)은 네트워크 우선(갱신이 막히지 않게).
const CACHE = "evans-blog-v3";
const PRECACHE = ["/", "/manifest.webmanifest", "/icon-192.png"];
const MAX_PAGES = 60; // 방문 페이지 캐시 상한 (오래된 것부터 삭제)
const HASHED = /\.[0-9a-f]{16,}\.(css|js)(\?|$)/;

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(PRECACHE)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

function trim(cache) {
  return cache.keys().then((keys) => {
    const extra = keys.length - (MAX_PAGES + PRECACHE.length);
    return extra > 0 ? Promise.all(keys.slice(0, extra).map((k) => cache.delete(k))) : null;
  });
}

function put(req, res) {
  // 정상 응답(200)만 저장한다. 404·리다이렉트·오류 페이지는 저장하지 않는다.
  if (!res || res.status !== 200 || res.type === "opaque") return;
  const copy = res.clone();
  caches.open(CACHE).then((c) => c.put(req, copy).then(() => trim(c)));
}

self.addEventListener("fetch", (e) => {
  const req = e.request;
  if (req.method !== "GET" || new URL(req.url).origin !== location.origin) return;
  const url = new URL(req.url);
  const networkFirst = req.mode === "navigate" || !HASHED.test(url.pathname + url.search);
  if (networkFirst) {
    e.respondWith(
      fetch(req)
        .then((res) => {
          put(req, res);
          return res;
        })
        .catch(() => caches.match(req).then((r) => r || (req.mode === "navigate" ? caches.match("/") : Response.error())))
    );
    return;
  }
  e.respondWith(
    caches.match(req).then((hit) =>
      hit ||
      fetch(req).then((res) => {
        put(req, res);
        return res;
      })
    )
  );
});
