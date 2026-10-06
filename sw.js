// Shows LocalHands push notifications and opens the post when tapped
self.addEventListener('push', e => {
  const d = e.data ? e.data.json() : { title: 'LocalHands', body: 'New post near you', url: './' };
  e.waitUntil(self.registration.showNotification(d.title, {
    body: d.body, icon: 'icon-192.png', badge: 'icon-192.png',
    data: { url: new URL(d.url, self.registration.scope).href },
  }));
});

self.addEventListener('notificationclick', e => {
  e.notification.close();
  const url = e.notification.data.url;
  e.waitUntil(clients.matchAll({ type: 'window', includeUncontrolled: true }).then(open => {
    const app = open.find(c => c.url.startsWith(self.registration.scope));
    if (!app) return clients.openWindow(url);
    // Reuse the open app instead of starting a second copy
    app.postMessage({ open: new URL(url).hash });
    return app.focus();
  }));
});
