const CACHE='pasir-gestion-v4.9.2';
const CORE=[
  './index.html?v=4.9.2','./manifest.webmanifest?v=4.9.2',
  './assets/css/styles.css?v=4.9.2','./assets/js/app-v4.9.2.js?v=4.9.2',
  './assets/icons/icon-192.png','./assets/icons/icon-512.png','./assets/icons/icon-maskable-512.png',
  './assets/icons/apple-touch-icon.png','./assets/icons/favicon-64.png','./assets/icons/pasir-logo.svg'
];
self.addEventListener('install',event=>event.waitUntil((async()=>{
  const c=await caches.open(CACHE); await c.addAll(CORE); await self.skipWaiting();
})()));
self.addEventListener('activate',event=>event.waitUntil((async()=>{
  const keys=await caches.keys();
  await Promise.all(keys.filter(k=>k!==CACHE&&!k.startsWith('pasir-durable-')).map(k=>caches.delete(k)));
  await self.clients.claim();
})()));
async function networkFirst(req){
  try{const res=await fetch(req,{cache:'no-store'}); if(res&&res.ok){const c=await caches.open(CACHE); c.put(req,res.clone());} return res;}
  catch(e){return (await caches.match(req))||(req.mode==='navigate'?caches.match('./index.html?v=4.9.2'):Response.error());}
}
self.addEventListener('fetch',event=>{
  if(event.request.method!=='GET')return;
  const u=new URL(event.request.url);
  if(u.origin===self.location.origin)event.respondWith(networkFirst(event.request));
});
