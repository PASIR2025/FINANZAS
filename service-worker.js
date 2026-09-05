const CACHE='pasir-gestion-v4.9.0-estable';
const CORE=[
  './','./index.html','./manifest.webmanifest?v=4.9.0','./assets/css/styles.css?v=4.9.0','./assets/js/app.js?v=4.9.0',
  './assets/icons/icon-192.png','./assets/icons/icon-512.png','./assets/icons/icon-maskable-512.png',
  './assets/icons/apple-touch-icon.png','./assets/icons/favicon-64.png','./assets/icons/pasir-logo.svg'
];
self.addEventListener('install',event=>{event.waitUntil(caches.open(CACHE).then(c=>c.addAll(CORE)).then(()=>self.skipWaiting()))});
self.addEventListener('activate',event=>{event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE&&!k.startsWith('pasir-durable-')).map(k=>caches.delete(k)))).then(()=>self.clients.claim()))});
async function networkFirst(request){try{const response=await fetch(request,{cache:'no-store'});if(response&&response.ok){const cache=await caches.open(CACHE);cache.put(request,response.clone())}return response}catch(e){return (await caches.match(request))||(request.mode==='navigate'?caches.match('./index.html'):Response.error())}}
self.addEventListener('fetch',event=>{if(event.request.method!=='GET')return;const url=new URL(event.request.url);if(url.origin===self.location.origin)event.respondWith(networkFirst(event.request))});
