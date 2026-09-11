#!/usr/local/bin/node
// MCP start-time gate (02.3 SF-7, Interface Contract 6, T29/T32).
//
// Reads the per-agent inventory Contract 2 installed at /opt/agent-pack/mcp-inventory.json
// (SF-6, pack-plan.sh + Dockerfile's per-stage promotion) and compares it against the fixed,
// per-agent enumerated set of capability-declaration files and plugin/skill directories
// measured and recorded in docs/records/mcp-inventory.md. Fails closed:
//
//   exit 0 -- every live entry is inventoried and matches its recorded baseline.
//   exit 3 -- an uninventoried entry, or a baseline/live hash mismatch (T29).
//   exit 2 -- the inventory or a capability-declaration file exists but does not parse.
//
// Called from images/entrypoint.sh AFTER the home seed and the codex config.toml merge --
// both must have run so this reads the same file the agent's session will.
//
// Bundle-level plugin/skill hashing (recorded limitation, docs/records/mcp-inventory.md
// "Recorded as still open"): codex and agy ship ONE checksum per skill bundle, not one per
// entry, so this gate compares the bundle marker (or, absent one, a hash of the directory's
// own file listing) against a single inventory entry named for the bundle as a whole. A
// change to any one skill inside the bundle drifts the whole bundle -- coarser than
// capability_baseline's per-entry shape, but the finest grain the shipped agents expose.

'use strict';
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

function die(code, msg) {
  process.stderr.write(`mcp-gate: ${msg}\n`);
  process.exit(code);
}

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--agent') out.agent = argv[++i];
    else if (argv[i] === '--inventory') out.inventory = argv[++i];
  }
  if (!out.agent || !out.inventory) {
    die(2, 'usage: mcp-gate.js --agent <agent> --inventory <path>');
  }
  return out;
}

function sortedCanonical(value) {
  if (Array.isArray(value)) return value.map(sortedCanonical);
  if (value && typeof value === 'object') {
    const out = {};
    for (const k of Object.keys(value).sort()) out[k] = sortedCanonical(value[k]);
    return out;
  }
  return value;
}

function sha256Hex(s) {
  return crypto.createHash('sha256').update(s, 'utf8').digest('hex');
}

function canonicalHash(value) {
  return sha256Hex(JSON.stringify(sortedCanonical(value)));
}

// Recursive extraction: any object with a key named "mcpServers" contributes its entries.
// Covers claude's `.projects["<cwd>"].mcpServers` nesting and a flat top-level
// `{"mcpServers": {...}}` shape (agy, /workspace/.mcp.json) with the same walk.
function extractJsonServers(obj, out) {
  if (!obj || typeof obj !== 'object') return;
  if (obj.mcpServers && typeof obj.mcpServers === 'object' && !Array.isArray(obj.mcpServers)) {
    for (const [name, cfg] of Object.entries(obj.mcpServers)) out[name] = cfg;
  }
  for (const v of Object.values(obj)) {
    if (v && typeof v === 'object') extractJsonServers(v, out);
  }
}

// Minimal TOML `[mcp_servers.<name>]` table extraction. Codex rewrites config.toml wholesale
// on every start (docs/records/mcp-inventory.md), so this only needs to read the shape our
// own entrypoint and the agent itself produce -- flat `key = value` lines inside the table,
// terminated by the next `[...]` header of any depth.
function extractTomlServers(text, out) {
  const lines = text.split(/\r?\n/);
  let current = null;
  let currentLines = null;
  const flush = () => {
    if (current !== null) out[current] = currentLines;
  };
  for (const line of lines) {
    const header = line.match(/^\[mcp_servers\.([^\]]+)\]\s*$/);
    const anyHeader = line.match(/^\[.*\]\s*$/);
    if (header) {
      flush();
      current = header[1];
      currentLines = {};
      continue;
    }
    if (anyHeader) {
      flush();
      current = null;
      currentLines = null;
      continue;
    }
    if (current !== null) {
      const kv = line.match(/^\s*([A-Za-z0-9_.-]+)\s*=\s*(.+?)\s*$/);
      if (kv) {
        let v = kv[2];
        if (v.startsWith('"') && v.endsWith('"')) v = v.slice(1, -1);
        currentLines[kv[1]] = v;
      }
    }
  }
  flush();
}

// Per-agent enumerated file set, fixed by SF-6's measurement (docs/records/mcp-inventory.md).
function agentSpec(agent, home) {
  const claudeConfigDir = process.env.CLAUDE_CONFIG_DIR || path.join(home, '.claude');
  const specs = {
    claude: {
      files: [
        { file: path.join(claudeConfigDir, '.claude.json'), format: 'json' },
        { file: '/workspace/.mcp.json', format: 'json' },
      ],
      bundles: [
        {
          dir: path.join(claudeConfigDir, 'plugins', 'marketplaces'),
          marker: null,
          name: 'claude-plugin-marketplaces',
        },
      ],
    },
    codex: {
      files: [{ file: path.join(home, '.codex', 'config.toml'), format: 'toml' }],
      bundles: [
        {
          dir: path.join(home, '.codex', 'skills', '.system'),
          marker: '.codex-system-skills.marker',
          name: 'codex-system-skills',
        },
      ],
    },
    agy: {
      files: [{ file: path.join(home, '.gemini', 'config', 'mcp_config.json'), format: 'json' }],
      bundles: [
        {
          dir: path.join(home, '.gemini', 'antigravity-cli', 'builtin', 'skills'),
          marker: '.checksum',
          name: 'agy-builtin-skills',
        },
      ],
    },
  };
  const spec = specs[agent];
  if (!spec) die(2, `unknown agent '${agent}' (expected claude, codex or agy)`);
  return spec;
}

function listFilesRecursive(dir) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...listFilesRecursive(p));
    else out.push(p);
  }
  return out.sort();
}

function main() {
  const { agent, inventory: inventoryPath } = parseArgs(process.argv.slice(2));
  const home = process.env.HOME || '/home/agent';

  let inventory;
  try {
    inventory = JSON.parse(fs.readFileSync(inventoryPath, 'utf8'));
  } catch (e) {
    die(2, `cannot read or parse inventory at ${inventoryPath}: ${e.message}`);
  }

  const serverBaseline = {};
  for (const s of inventory.servers || []) serverBaseline[s.name] = s;
  const bundleBaseline = {};
  for (const p of [...(inventory.plugins || []), ...(inventory.skills || [])]) bundleBaseline[p.name] = p;

  const spec = agentSpec(agent, home);
  const findings = [];

  for (const { file, format } of spec.files) {
    if (!fs.existsSync(file)) continue;
    let raw;
    try {
      raw = fs.readFileSync(file, 'utf8');
    } catch (e) {
      die(2, `cannot read capability-declaration file ${file}: ${e.message}`);
    }
    const live = {};
    try {
      if (format === 'json') {
        extractJsonServers(JSON.parse(raw), live);
      } else {
        extractTomlServers(raw, live);
      }
    } catch (e) {
      die(2, `capability-declaration file ${file} exists but does not parse (${format}): ${e.message}`);
    }
    for (const [name, cfg] of Object.entries(live)) {
      const baseline = serverBaseline[name];
      if (!baseline) {
        findings.push(`REFUSED uninventoried server '${name}' in ${file} (R7.14, T29)`);
        continue;
      }
      const liveHash = canonicalHash(cfg);
      const baseHash = baseline.capability_baseline && baseline.capability_baseline.config_sha256;
      if (liveHash !== baseHash) {
        findings.push(`DRIFT '${name}' in ${file}: baseline ${baseHash} != live ${liveHash} (R7.14, T29)`);
      }
    }
  }

  for (const { dir, marker, name } of spec.bundles) {
    if (!fs.existsSync(dir)) continue;
    let entries;
    try {
      entries = fs.readdirSync(dir);
    } catch (e) {
      die(2, `cannot read skill/plugin directory ${dir}: ${e.message}`);
    }
    if (entries.length === 0) continue;

    let liveHash;
    if (marker && fs.existsSync(path.join(dir, marker))) {
      try {
        liveHash = fs.readFileSync(path.join(dir, marker), 'utf8').trim();
      } catch (e) {
        die(2, `cannot read bundle marker ${path.join(dir, marker)}: ${e.message}`);
      }
    } else {
      // No bundle marker (claude's plugin directories carry none, per SF-6's measurement):
      // hash the sorted relative file listing as the coarsest available baseline.
      const rels = listFilesRecursive(dir).map((p) => path.relative(dir, p));
      liveHash = sha256Hex(JSON.stringify(rels));
    }

    const baseline = bundleBaseline[name];
    if (!baseline) {
      findings.push(`REFUSED uninventoried server '${name}' in ${dir} (R7.14, T29)`);
      continue;
    }
    if (liveHash !== baseline.sha256) {
      findings.push(`DRIFT '${name}' in ${dir}: baseline ${baseline.sha256} != live ${liveHash} (R7.14, T29)`);
    }
  }

  if (findings.length > 0) {
    for (const line of findings) process.stderr.write(`mcp-gate: ${line}\n`);
    process.exit(3);
  }
  process.exit(0);
}

if (require.main === module) {
  main();
} else {
  // Exposed so the acceptance harness can compute a fixture's expected
  // capability_baseline.config_sha256 with the exact same canonicalization the
  // gate itself uses, instead of re-implementing (and risking drift from) it.
  module.exports = { sortedCanonical, canonicalHash, sha256Hex };
}
