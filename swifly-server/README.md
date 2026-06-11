# Swifly Server Registry

Render-hosted API for Swifly-approved BO3/T7 server listings.

## What this does

- Stores Swifly-approved server entries in PostgreSQL.
- Gives each server a private heartbeat token.
- Exposes a public `GET /api/servers` endpoint for the Swifly client.
- Keeps servers hidden unless they have heartbeated recently.

## Render setup

1. Create a PostgreSQL database on Render.
2. Create a Web Service from this GitHub repo.
3. Set the service root directory to `swifly-server`.
4. Use build command:

```bash
npm install
```

5. Use start command:

```bash
npm start
```

6. Add environment variables:

```text
DATABASE_URL=<Render PostgreSQL internal database URL>
ADMIN_API_KEY=<long random admin secret>
HEARTBEAT_TTL_SECONDS=180
```

## Create a server entry

```bash
curl -X POST https://YOUR-APP.onrender.com/api/admin/servers \
  -H "content-type: application/json" \
  -H "x-admin-key: YOUR_ADMIN_API_KEY" \
  -d '{
    "name":"Swifly Zombies #1",
    "mode":"zm",
    "map":"zm_zod",
    "region":"NA",
    "port":27017,
    "maxPlayers":8
  }'
```

The response includes a private `token`. Save it. The server uses it to heartbeat.

## Heartbeat from a hosted server

```bash
curl -X POST https://YOUR-APP.onrender.com/api/servers/SERVER_ID/heartbeat \
  -H "content-type: application/json" \
  -H "authorization: Bearer SERVER_TOKEN" \
  -d '{
    "port":27017,
    "mode":"zm",
    "map":"zm_zod",
    "players":0,
    "maxPlayers":8,
    "version":"swifly-server-0.1.0"
  }'
```

## Public client list

```bash
curl https://YOUR-APP.onrender.com/api/servers
```

This returns only verified, non-hidden servers with recent heartbeats.

## Notes

This API does not distribute BO3 game files. Server hosts still need to install the BO3 Unranked Dedicated Server / BO3 files legitimately and use Swifly configs/scripts on top.
