// ✅ Service Worker para FCM en Flutter Web
// NOTA: NO usar importScripts() con CDNs externos en service workers

// Escuchar mensajes push
self.addEventListener('push', function (event) {
	if (event.data) {
		const data = event.data.json();
		console.log('[FCM SW] Push recibido:', data);

		const title = data.notification?.title || 'Footrix';
		const options = {
			body: data.notification?.body || '',
			icon: '/icons/Icon-192.png',
			badge: '/icons/Icon-192.png',
			data: data.data || {},
			tag: 'footrix-notification',
		};

		event.waitUntil(self.registration.showNotification(title, options));
	}
});

// Escuchar clicks en notificaciones
self.addEventListener('notificationclick', function (event) {
	event.preventDefault();

	const route = event.notification.data?.route || '/fixture';
	console.log('[FCM SW] Click en notificación, navegando a:', route);

	event.waitUntil(
		clients
			.matchAll({ type: 'window', includeUncontrolled: true })
			.then(function (windowClients) {
				// Si hay una ventana abierta, navegarla
				for (let client of windowClients) {
					if (client.url.includes(route)) {
						return client.focus();
					}
				}
				// Si no, navegar la primera ventana disponible
				if (windowClients.length > 0) {
					const client = windowClients[0];
					return client.navigate(route).then(function (client) {
						return client.focus();
					});
				}
				// Si no hay ventanas, abrir nueva
				return clients.openWindow(route);
			})
			.catch(function (err) {
				console.error('[FCM SW] Error navegando:', err);
			}),
	);
});

// Manejar instalación del SW
self.addEventListener('install', function (event) {
	console.log('[FCM SW] Instalado');
	self.skipWaiting();
});

// Manejar activación del SW
self.addEventListener('activate', function (event) {
	console.log('[FCM SW] Activado');
	event.waitUntil(clients.claim());
});
