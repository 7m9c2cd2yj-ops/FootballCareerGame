#!/usr/bin/env python3
"""A tiny local stand-in for the Supabase endpoints the game uses.

For development and the online smoke test only. It mimics anonymous auth,
the PostgREST calls on profiles/careers/arena_entries, the delete_my_account
RPC and the submit-ranking edge function (which runs the real plausibility
check via Node). Each player only sees their own rows, like row-level
security. Data lives in memory.

Usage: python3 tools/mock_supabase.py --port 54400 --anon-key dev-anon-key
"""
import argparse
import json
import pathlib
import subprocess
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

ROOT = pathlib.Path(__file__).resolve().parent.parent
NAMES = set(json.loads((ROOT / "data/preset_names.json").read_text())["names"])
SERVERS = {s["id"] for s in json.loads((ROOT / "data/online.json").read_text())["servers"]}
STATE = {"tokens": {}, "refresh": {}, "users": set(), "profiles": {}, "careers": {}, "rankings": {}}


def eq(query, key):
    value = query.get(key, [None])[0]
    return value[3:] if value and value.startswith("eq.") else None


class Handler(BaseHTTPRequestHandler):
    anon_key = ""

    def log_message(self, *args):
        pass

    def reply(self, code, body=None):
        data = json.dumps(body if body is not None else {}).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def body(self):
        length = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(length) or b"{}")

    def user(self):
        token = (self.headers.get("Authorization") or "").removeprefix("Bearer ")
        return STATE["tokens"].get(token)

    def session_for(self, user_id):
        access, refresh = uuid.uuid4().hex, uuid.uuid4().hex
        STATE["tokens"][access] = user_id
        STATE["refresh"][refresh] = user_id
        return {"access_token": access, "refresh_token": refresh, "expires_in": 3600,
                "token_type": "bearer", "user": {"id": user_id}}

    def do_GET(self):
        url = urlparse(self.path)
        query = parse_qs(url.query)
        user = self.user()
        if self.headers.get("apikey") != self.anon_key or user is None:
            return self.reply(401, {"message": "unauthorized"})
        if url.path == "/rest/v1/profiles":
            profile = STATE["profiles"].get(user)
            return self.reply(200, [profile] if profile and eq(query, "id") == user else [])
        if url.path == "/rest/v1/careers":
            row = STATE["careers"].get((user, int(eq(query, "slot") or 0)))
            return self.reply(200, [{"envelope": row["envelope"]}] if row else [])
        if url.path == "/rest/v1/arena_entries":
            best = {}
            for (owner, _slot), row in STATE["rankings"].items():
                if owner not in best or row["hof_score"] > best[owner]["hof_score"]:
                    best[owner] = row
            server = eq(query, "server_id")
            rows = [r for r in best.values() if server is None or r["server_id"] == server]
            return self.reply(200, sorted(rows, key=lambda r: -r["hof_score"]))
        return self.reply(404, {"message": "not found"})

    def do_POST(self):
        url = urlparse(self.path)
        query = parse_qs(url.query)
        if self.headers.get("apikey") != self.anon_key:
            return self.reply(401, {"message": "bad apikey"})
        body = self.body()
        if url.path == "/auth/v1/signup":
            user_id = str(uuid.uuid4())
            STATE["users"].add(user_id)
            return self.reply(200, self.session_for(user_id))
        if url.path == "/auth/v1/token" and query.get("grant_type") == ["refresh_token"]:
            user_id = STATE["refresh"].pop(body.get("refresh_token"), None)
            if user_id not in STATE["users"]:
                return self.reply(400, {"error": "invalid_grant"})
            return self.reply(200, self.session_for(user_id))
        user = self.user()
        if user is None:
            return self.reply(401, {"message": "unauthorized"})
        if url.path == "/rest/v1/profiles":
            if body.get("id") != user:
                return self.reply(403, {"message": "row-level security"})
            if body.get("display_name") not in NAMES or body.get("server_id") not in SERVERS:
                return self.reply(409, {"code": "23503", "message": "foreign key violation"})
            STATE["profiles"][user] = body
            return self.reply(201)
        if url.path == "/rest/v1/careers":
            if body.get("owner") != user:
                return self.reply(403, {"message": "row-level security"})
            key = (user, int(body["slot"]))
            previous = STATE["careers"].get(key)
            body["backup_envelope"] = previous["envelope"] if previous else None
            STATE["careers"][key] = body
            return self.reply(201)
        if url.path == "/functions/v1/submit-ranking":
            return self.submit_ranking(user, int(body.get("slot", 0)))
        if url.path == "/rest/v1/rpc/delete_my_account":
            for table in ("careers", "rankings"):
                STATE[table] = {k: v for k, v in STATE[table].items() if k[0] != user}
            STATE["profiles"].pop(user, None)
            STATE["users"].discard(user)
            STATE["tokens"] = {t: u for t, u in STATE["tokens"].items() if u != user}
            return self.reply(204)
        return self.reply(404, {"message": "not found"})

    def submit_ranking(self, user, slot):
        profile = STATE["profiles"].get(user)
        saved = STATE["careers"].get((user, slot))
        if profile is None or saved is None:
            return self.reply(404, {"error": "upload the career first"})
        check = subprocess.run(
            ["node", "--experimental-strip-types", "--no-warnings",
             str(ROOT / "backend/tests/check_career_cli.ts")],
            input=json.dumps(saved["envelope"]["career"]), capture_output=True, text=True, check=True)
        result = json.loads(check.stdout)
        if not result["ok"]:
            return self.reply(422, {"error": "career failed validation", "problems": result["problems"]})
        row = dict(result["summary"], owner=user, slot=slot,
                   display_name=profile["display_name"], server_id=profile["server_id"])
        STATE["rankings"][(user, slot)] = row
        return self.reply(200, {"ranking": row})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=54400)
    parser.add_argument("--anon-key", default="dev-anon-key")
    args = parser.parse_args()
    Handler.anon_key = args.anon_key
    ThreadingHTTPServer(("127.0.0.1", args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
