# Backend (Supabase)

Empty until **M7**. It will contain:

- `migrations/`: SQL for `profiles`, `careers` (versioned JSON save data) and
  `rankings`, with row-level security so a player can only write their own rows.
- `functions/`: an edge function that validates ranking submissions
  server-side (rating and trophy counts within plausible bounds). The client
  is never trusted.

Credentials come from environment variables (see `../.env.example`) and
must never be committed.
