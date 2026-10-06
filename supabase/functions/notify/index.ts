// Called by the app right after a member posts. Pushes a notification to every
// member whose home suburb radius covers the post and who wants that post type.
import { createClient } from 'npm:@supabase/supabase-js@2.117.2';
import webpush from 'npm:web-push@3.6.7';

webpush.setVapidDetails(
  'https://github.com/isaacbax-work/LocalHands',
  Deno.env.get('VAPID_PUBLIC_KEY')!,
  Deno.env.get('VAPID_PRIVATE_KEY')!,
);
const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

const LABEL: Record<string, string> = {
  sale: 'For sale', free: 'Giving away', task: 'Needs a hand', service: 'Service', group: 'Group / gathering',
};
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const json = (body: unknown) => new Response(JSON.stringify(body), { headers: { ...cors, 'Content-Type': 'application/json' } });

export function km(a: { lat: number; lng: number }, b: { lat: number; lng: number }) {
  const rad = Math.PI / 180, dLat = (b.lat - a.lat) * rad, dLng = (b.lng - a.lng) * rad;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLng / 2) ** 2;
  return 12742 * Math.asin(Math.sqrt(h));
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  const { post_id } = await req.json().catch(() => ({}));
  if (typeof post_id !== 'string') return json({ sent: 0 });

  // Claim the post so each one notifies at most once, however often this is called
  const { data: post } = await db.from('posts').update({ notified_at: new Date().toISOString() })
    .eq('id', post_id).is('notified_at', null).select().maybeSingle();
  if (!post) return json({ sent: 0 });

  // ponytail: scans every opted-in profile; move the distance filter into SQL (PostGIS) past a few thousand members
  const { data: people } = await db.from('profiles').select('id, lat, lng, radius_km, notify_types')
    .eq('notify', true).neq('id', post.user_id).not('lat', 'is', null);
  const near = (people ?? []).filter((p) => p.notify_types.includes(post.type) && km(p, post) <= p.radius_km).map((p) => p.id);
  if (!near.length) return json({ sent: 0 });

  const { data: subs } = await db.from('push_subscriptions').select('*').in('user_id', near);
  const payload = JSON.stringify({
    title: `${LABEL[post.type]} near you`,
    body: post.title + (post.km ? ` · ${post.km} km route` : post.price ? ` · ${post.price}` : ''),
    url: `./#${post.id}`,
  });
  let sent = 0;
  await Promise.all((subs ?? []).map((s) =>
    webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload, { TTL: 86400 })
      .then(() => sent++)
      .catch((e: { statusCode?: number }) => {
        console.error('push failed', s.endpoint.slice(0, 60), e.statusCode ?? e);
        // Device unsubscribed or uninstalled: forget it
        if (e.statusCode === 404 || e.statusCode === 410) return db.from('push_subscriptions').delete().eq('endpoint', s.endpoint);
      })));
  return json({ sent });
});
