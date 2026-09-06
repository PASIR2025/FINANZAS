/* PASIR Gestión V5.0.0 — Service Worker anti-cache obsoleto */
const PASIR_SW_VERSION='5.0.0';
const SHELL_CACHE=`pasir-shell-v${PASIR_SW_VERSION}`;
const DURABLE_PREFIX='pasir-durable-';
const CORE=[
  './index.html?v=5.0.0',
  './manifest.webmanifest?v=5.0.0',
  './assets/css/styles.css?v=5.0.0',
  './assets/js/app-v5.0.0.js?v=5.0.0',
  './assets/icons/icon-192.png',
  './assets/icons/icon-512.png',
  './assets/icons/icon-maskable-512.png',
  './assets/icons/apple-touch-icon.png',
  './assets/icons/favicon-64.png',
  './assets/icons/pasir-logo.svg'
];

self.addEventListener('install',event=>{
  event.waitUntil((async()=>{
    const cache=await caches.open(SHELL_CACHE);
    await cache.addAll(CORE);
    await self.skipWaiting();
  })());
});

self.addEventListener('activate',event=>{
  event.waitUntil((async()=>{
    const keys=await caches.keys();
    await Promise.all(keys
      .filter(name=>name!==SHELL_CACHE&&!name.startsWith(DURABLE_PREFIX))
      .map(name=>caches.delete(name)));
    if(self.registration.navigationPreload) {
      try{await self.registration.navigationPreload.enable()}catch(e){}
    }
    await self.clients.claim();
  })());
});

self.addEventListener('message',event=>{
  if(event.data?.type==='SKIP_WAITING')self.skipWaiting();
});

async function networkFirst(request,event){
  const cache=await caches.open(SHELL_CACHE);
  try{
    const preload=event?.preloadResponse?await event.preloadResponse:null;
    const response=preload||await fetch(request,{cache:'no-store'});
    if(response&&response.ok)await cache.put(request,response.clone());
    return response;
  }catch(error){
    const cached=await cache.match(request);
    if(cached)return cached;
    if(request.mode==='navigate'){
      const shell=await cache.match('./index.html?v=5.0.0');
      if(shell)return shell;
    }
    return Response.error();
  }
}

self.addEventListener('fetch',event=>{
  const request=event.request;
  if(request.method!=='GET')return;
  const url=new URL(request.url);
  if(url.origin!==self.location.origin)return;
  event.respondWith(networkFirst(request,event));
});
