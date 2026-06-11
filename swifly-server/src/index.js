const crypto = require('crypto');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const { Pool } = require('pg');
const { z } = require('zod');

const PORT = Number(process.env.PORT || 3000);
const ADMIN_API_KEY = process.env.ADMIN_API_KEY || '';
const HEARTBEAT_TTL_SECONDS = Number(process.env.HEARTBEAT_TTL_SECONDS || 180);

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_URL && !process.env.DATABASE_URL.includes('localhost')
    ? { rejectUnauthorized: false }
    : false,
});

const serverSchema = z.object({
  name: z.string().trim().min(3).max(64),
  mode: z.enum(['mp', 'zm', 'cp']).default('zm'),
  map: z.string().trim().min(1).max(64).default('zm_zod'),
  gametype: z.string().trim().max(64).default(''),
  region: z.string().trim().max(32).default(''),
  description: z.string().trim().max(256).default(''),
  address: z.string().trim().max(128).optional(),
  port: z.number().int().min(1).max(65535).default(27017),
  players: z.number().int().min(0).max(64).default(0),
  maxPlayers: z.number().int().min(1).max(64).default(8),
  passworded: z.boolean().default(false),
  hidden: z.boolean().default(false),
  verified: z.boolean().default(true),
});

const heartbeatSchema = serverSchema.partial().extend({
  version: z.string().trim().max(64).optional(),
});

function makeToken() {
  return crypto.randomBytes(32).toString('base64url');
}

function hashToken(token) {
  return crypto.createHash('sha256').update(token, 'utf8').digest('hex');
}

function bearerToken(req) {
  const header = req.header('authorization') || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match ? match[1] : '';
}

function clientIp(req) {
  const forwarded = req.header('x-forwarded-for');
  return forwarded ? forwarded.split(',')[0].trim() : (req.socket.remoteAddress || '');
}

function requireAdmin(req, res, next) {
  if (!ADMIN_API_KEY) {
    return res.status(500).json({ error: 'ADMIN_API_KEY is not configured' });
  }
  if ((req.header('x-admin-key') || '') !== ADMIN_API_KEY) {
    return res.status(401).json({ error: 'invalid admin key' });
  }
  next();
}

async function migrate() {
  await pool.query(`
    create extension if not exists pgcrypto;
    create table if not exists servers (
      id uuid primary key default gen_random_uuid(),
      name text not null,
      mode text not null default 'zm',
      map text not null default 'zm_zod',
      gametype text not null default '',
      region text not null default '',
      description text not null default '',
      address text,
      port integer not null default 27017,
      players integer not null default 0,
      max_players integer not null default 8,
      passworded boolean not null default false,
      version text not null default '',
      token_hash text not null,
      verified boolean not null default true,
      hidden boolean not null default false,
      last_heartbeat_at timestamptz,
      created_at timestamptz not null default now(),
      updated_at timestamptz not null default now()
    );
  `);
}

function publicServer(row) {
  return {
    id: row.id,
    name: row.name,
    address: row.address,
    port: row.port,
    mode: row.mode,
    map: row.map,
    gametype: row.gametype,
    region: row.region,
    description: row.description,
    players: row.players,
    maxPlayers: row.max_players,
    passworded: row.passworded,
    version: row.version,
    lastHeartbeatAt: row.last_heartbeat_at,
  };
}

const app = express();
app.set('trust proxy', true);
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '64kb' }));
app.use(morgan('tiny'));

app.get('/health', (_req, res) => {
  res.json({ ok: true, service: 'swifly-server-registry' });
});

app.get('/api/servers', async (_req, res, next) => {
  try {
    const result = await pool.query(`
      select * from servers
      where verified = true
        and hidden = false
        and address is not null
        and last_heartbeat_at > now() - ($1::int * interval '1 second')
      order by players desc, last_heartbeat_at desc, name asc
    `, [HEARTBEAT_TTL_SECONDS]);
    res.json(result.rows.map(publicServer));
  } catch (error) {
    next(error);
  }
});

app.get('/api/admin/servers', requireAdmin, async (_req, res, next) => {
  try {
    const result = await pool.query('select * from servers order by created_at desc');
    res.json(result.rows.map((row) => ({ ...publicServer(row), verified: row.verified, hidden: row.hidden, createdAt: row.created_at })));
  } catch (error) {
    next(error);
  }
});

app.post('/api/admin/servers', requireAdmin, async (req, res, next) => {
  try {
    const body = serverSchema.parse(req.body || {});
    const token = makeToken();
    const result = await pool.query(`
      insert into servers (name, mode, map, gametype, region, description, address, port, players, max_players, passworded, token_hash, verified, hidden)
      values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
      returning *
    `, [body.name, body.mode, body.map, body.gametype, body.region, body.description, body.address || null, body.port, body.players, body.maxPlayers, body.passworded, hashToken(token), body.verified, body.hidden]);
    res.status(201).json({ server: publicServer(result.rows[0]), token });
  } catch (error) {
    next(error);
  }
});

app.post('/api/servers/:id/heartbeat', async (req, res, next) => {
  try {
    const token = bearerToken(req);
    if (!token) return res.status(401).json({ error: 'missing bearer token' });

    const current = await pool.query('select * from servers where id = $1', [req.params.id]);
    if (!current.rowCount) return res.status(404).json({ error: 'server not found' });

    const row = current.rows[0];
    if (hashToken(token) !== row.token_hash) {
      return res.status(401).json({ error: 'invalid token' });
    }

    const body = heartbeatSchema.parse(req.body || {});
    const address = body.address || clientIp(req);
    const result = await pool.query(`
      update servers set
        name = coalesce($1, name),
        mode = coalesce($2, mode),
        map = coalesce($3, map),
        gametype = coalesce($4, gametype),
        region = coalesce($5, region),
        description = coalesce($6, description),
        address = coalesce($7, address),
        port = coalesce($8, port),
        players = coalesce($9, players),
        max_players = coalesce($10, max_players),
        passworded = coalesce($11, passworded),
        version = coalesce($12, version),
        last_heartbeat_at = now(),
        updated_at = now()
      where id = $13
      returning *
    `, [body.name, body.mode, body.map, body.gametype, body.region, body.description, address, body.port, body.players, body.maxPlayers, body.passworded, body.version, row.id]);

    res.json({ ok: true, server: publicServer(result.rows[0]) });
  } catch (error) {
    next(error);
  }
});

app.delete('/api/admin/servers/:id', requireAdmin, async (req, res, next) => {
  try {
    await pool.query('delete from servers where id = $1', [req.params.id]);
    res.status(204).end();
  } catch (error) {
    next(error);
  }
});

app.use((error, _req, res, _next) => {
  if (error instanceof z.ZodError) {
    return res.status(400).json({ error: 'validation failed', details: error.errors });
  }
  console.error(error);
  res.status(500).json({ error: 'internal server error' });
});

migrate().then(() => {
  app.listen(PORT, () => console.log(`Swifly registry listening on ${PORT}`));
}).catch((error) => {
  console.error(error);
  process.exit(1);
});
