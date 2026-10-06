// Deletes the signed-in member. Their profile, posts, reports and devices go with it (on delete cascade).
import { createClient } from 'npm:@supabase/supabase-js@2.117.2';

const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  const jwt = req.headers.get('Authorization')?.replace(/^Bearer /, '') ?? '';
  const { data } = await admin.auth.getUser(jwt);
  if (!data.user) return new Response('Not signed in', { status: 401, headers: cors });
  const { error } = await admin.auth.admin.deleteUser(data.user.id);
  if (error) return new Response(error.message, { status: 500, headers: cors });
  return new Response(JSON.stringify({ deleted: true }), { headers: { ...cors, 'Content-Type': 'application/json' } });
});
