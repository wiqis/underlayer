// underlayer_content — the installable web app's service worker source.
//
// This is a raw JavaScript artifact, served as `application/javascript` by an
// explicit same-origin route. Like content/src/theme_boot.ch it is one quoted
// literal (no string concatenation, no interpolation); the byte-for-byte source
// is checked by tools/pwa_check.py. The worker obeys a strict allow-list:
// same-origin GETs only, never `/api/*`, never a write response, and old caches
// are deleted on activate. No eval, no importScripts, no third-party origin.
using std::string

public namespace underlayer_content {

    public func service_worker_source() : string {
        return string("const UL_CACHE='ul-shell-v1';const UL_ALLOW=['/','/onboarding','/today','/courses','/learning-path','/help','/faq','/about','/privacy','/terms','/assets/theme-boot.js','/manifest.webmanifest'];self.addEventListener('install',function(e){e.waitUntil(caches.open(UL_CACHE).then(function(c){return c.addAll(UL_ALLOW).catch(function(){});}).then(function(){return self.skipWaiting();}));});self.addEventListener('activate',function(e){e.waitUntil(caches.keys().then(function(keys){return Promise.all(keys.map(function(k){if(k.indexOf('ul-')===0&&k!==UL_CACHE){return caches.delete(k);}return null;}));}).then(function(){return self.clients.claim();}));});function ulSafe(path){if(path.indexOf('/')!==0){return false;}if(path.indexOf('//')===0){return false;}if(path.indexOf('/api/')===0){return false;}return true;}self.addEventListener('fetch',function(e){var r=e.request;if(r.method!=='GET'){return;}var u=new URL(r.url);if(u.origin!==self.location.origin){return;}var path=u.pathname;if(!ulSafe(path)){return;}if(r.mode==='navigate'||path.indexOf('/courses/')===0){e.respondWith(fetch(r).then(function(res){if(res&&res.ok){var copy=res.clone();caches.open(UL_CACHE).then(function(c){return c.put(r,copy);}).catch(function(){});}return res;}).catch(function(){return caches.match(r).then(function(hit){return hit||caches.match('/');});}));return;}e.respondWith(caches.match(r).then(function(hit){if(hit){return hit;}return fetch(r).then(function(res){if(res&&res.ok){var copy=res.clone();caches.open(UL_CACHE).then(function(c){return c.put(r,copy);}).catch(function(){});}return res;});}));});self.addEventListener('message',function(e){var d=e.data;if(!d||d.type!=='cache-paths'||!d.paths){return;}var paths=[];var i=0;while(i<d.paths.length){if(ulSafe(d.paths[i])){paths.push(d.paths[i]);}i=i+1;}e.waitUntil(caches.open(UL_CACHE).then(function(c){return c.addAll(paths).catch(function(){});}));});")
    }

}
