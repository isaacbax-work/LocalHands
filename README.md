# LocalHands

A map of what's happening in your suburb: things for sale or free, people who need a hand, local services, and groups or gatherings (with run, walk and ride routes that follow the roads).

Members sign up with email, set a home suburb, and can get push notifications when someone posts nearby.

- `index.html`: the whole app (Leaflet map + Supabase)
- `sw.js`, `manifest.json`, `icon-*.png`: installable app and push notifications
- `supabase/migrations/`: database tables and security rules
- `supabase/functions/notify/`: sends push notifications for new posts
- `supabase/functions/delete-account/`: lets members delete their account and posts

## Going live

You need a free [Supabase](https://supabase.com) account. In your terminal, from this folder:

1. **Create the project:** on supabase.com, click New project. Note the database password you set.
2. **Connect this folder to it:**
   ```bash
   supabase login
   supabase link --project-ref YOUR-PROJECT-REF
   ```
   The project ref is the part of your project URL after `/project/`.
3. **Create the tables and deploy notifications:**
   ```bash
   supabase db push
   supabase secrets set --env-file supabase/.env
   supabase functions deploy
   ```
   `supabase/.env` holds the private push key. It is not in git; keep a backup somewhere safe, because if you lose it everyone has to turn notifications on again.
4. **Point the app at your project:** in Supabase go to Project Settings → API and copy the Project URL and the anon public key into the top of the script in `index.html` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`).
5. **Host it:** on GitHub, open the repo → Settings → Pages, set Source to `main` / root. The site appears at `https://isaacbax-work.github.io/LocalHands/`.
6. **Let sign-up emails link back to the site:** in Supabase go to Authentication → URL Configuration, set Site URL to your Pages address, and add it under Redirect URLs.

Before a real launch, set up your own email sender under Authentication → Emails → SMTP. Supabase's built-in sender only allows a few emails per hour.

## Moderation

- Members can report a post. Once three different members report it, it's hidden from everyone except its owner.
- To review, open the Supabase dashboard → Table Editor → `posts` and filter `hidden` = true. Set `hidden` back to false to restore a post, or delete the row to remove it.
- Each member can make up to 10 posts an hour, which keeps one account from flooding the map and everyone's notifications.

## Notifications on phones

- **Android, Windows, Mac:** works in Chrome, Edge, Firefox and Safari. Turn it on in Profile.
- **iPhone / iPad:** Apple only allows notifications for sites added to the home screen. Open the site in Safari, tap Share → Add to Home Screen, open LocalHands from the home screen, then turn notifications on in Profile.

## Running it locally

Needs Docker running.

```bash
supabase start
supabase functions serve --env-file supabase/.env
```

Then serve this folder (e.g. `python3 -m http.server 8123`) and temporarily set `SUPABASE_URL` to `http://127.0.0.1:54321` and `SUPABASE_ANON_KEY` to the anon key `supabase start` prints.
