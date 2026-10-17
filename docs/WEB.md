# Web version (play in a browser, no computer needed)

The game also builds for browsers, so it can be played on an iPhone in Safari
and added to the Home Screen. It is the quickest way to try the game. The
phone apps (`docs/RELEASE.md`) are still the way to publish in the stores.

## Turn it on (once, from a phone browser)

1. Push to `claude/football-career-game-m1-3xrppu`. The **Web build**
   workflow (`.github/workflows/web.yml`) builds the game and publishes it to
   the `gh-pages` branch. The first run downloads about 1.3 GB of Godot export
   templates, and later runs use the cache. Watch it under the repository's
   **Actions** tab.
2. In the repository open **Settings → Pages**. Under **Source** choose
   **Deploy from a branch**. Set the branch to **gh-pages** and the folder to
   **/ (root)**, then save.
3. After a minute the page is live at
   `https://<your-github-name>.github.io/FootballCareerGame/`. Open it in Safari.
4. To get an app icon: tap Share, then **Add to Home Screen**. It opens
   full screen like an app. The first load downloads about 12 MB, and later
   loads are faster.

If you make the repository private, Pages needs a paid GitHub plan. A public
repository is free.

## What is different from the phone app

- It uses the Compatibility renderer (browsers only support that). The 3D
  moments look the same in tests, but are a little slower on older phones.
- There is no vibration on iPhone web pages, so the haptics setting does nothing there.
- Saves are kept in the browser's storage for that page. Clearing Safari's
  website data or using a private tab deletes them. iOS can also clear
  storage of sites you haven't opened for a long time, and Home Screen apps
  keep their own separate storage from Safari. If you turn on online sync
  (`docs/SUPABASE_SETUP.md`), the careers are backed up online.
- Purchases are not available (there is no web store adapter), and the
  Locker only shows the free items.
- Rotating the phone works. Menus are laid out for portrait, so they are cramped in
  landscape. Key moments work in both.
- Online features are off unless the repository has the secrets `SUPABASE_URL` and
  `SUPABASE_ANON_KEY`. The anon key is meant to be public, protected by
  row-level security. Never add the service-role key.

## Build it yourself

```bash
./tools/build_web.sh          # writes build/web
cd build/web && python3 -m http.server 8060   # then open http://localhost:8060
```
