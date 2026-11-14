#!/usr/bin/env node
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');

const root = process.env.CODEX_HOME || path.join(os.homedir(), '.codex');
const store = path.join(root, 'turn-diffs');

const colors = {
  green: '\u001b[32m',
  red: '\u001b[31m',
  cyan: '\u001b[36m',
  dim: '\u001b[2m',
  reset: '\u001b[0m',
};

function showLatestTurn() {
  const onlyNonEmpty = process.argv.includes('--last');
  const showAll = process.argv.includes('--all');
  const repoRoot = showAll ? null : gitRoot(process.cwd());
  const turns = completedTurns(onlyNonEmpty, repoRoot);
  if (!turns.length) {
    console.log(onlyNonEmpty ? 'No non-empty turn diff saved yet.' : 'No completed turn diff yet.');
    return;
  }

  const turnDir = turns[0];
  const summary = readSummary(turnDir);
  if (!summary) {
    console.log('No summary saved for the latest turn.');
    return;
  }

  printSummary(summary);
  if (!summary.files.length) return;
  printPatch(path.join(turnDir, 'patch.diff'));
}

function completedTurns(onlyNonEmpty, repoRoot) {
  if (!fs.existsSync(store)) return [];

  return fs.readdirSync(store)
    .map(name => path.join(store, name))
    .filter(turnDir => {
      const patch = path.join(turnDir, 'patch.diff');
      const summaryPath = path.join(turnDir, 'summary.json');
      if (!fs.existsSync(patch) || !fs.existsSync(summaryPath)) return false;
      if (repoRoot && gitRootForTurn(turnDir) !== repoRoot) return false;
      return !onlyNonEmpty || readSummary(turnDir)?.files.length > 0;
    })
    .sort((a, b) => patchModifiedTime(b) - patchModifiedTime(a));
}

function gitRoot(cwd) {
  try {
    return execFileSync('git', ['rev-parse', '--show-toplevel'], {
      cwd,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch {
    return null;
  }
}

function gitRootForTurn(turnDir) {
  try {
    const manifest = JSON.parse(fs.readFileSync(path.join(turnDir, 'manifest.json'), 'utf8'));
    return gitRoot(manifest.cwd);
  } catch {
    return null;
  }
}

function patchModifiedTime(turnDir) {
  return fs.statSync(path.join(turnDir, 'patch.diff')).mtimeMs;
}

function readSummary(turnDir) {
  const summaryPath = path.join(turnDir, 'summary.json');
  if (!fs.existsSync(summaryPath)) return null;
  return JSON.parse(fs.readFileSync(summaryPath, 'utf8'));
}

function printSummary(summary) {
  console.log(`${colors.cyan}Turn diff${colors.reset} ${colors.dim}${summary.timestamp}${colors.reset}`);
  if (!summary.files.length) {
    console.log(`${colors.dim}No repo file changes in this turn.${colors.reset}`);
    return;
  }

  for (const file of summary.files) {
    const color = file.status === 'A' ? colors.green : file.status === 'D' ? colors.red : colors.cyan;
    console.log(`${color}${file.status}${colors.reset} ${file.path} ${colors.green}+${file.added}${colors.reset} ${colors.red}-${file.removed}${colors.reset}`);
  }
  console.log(`${colors.dim}${summary.files.length} file(s) changed; ${colors.green}+${summary.added}${colors.reset} ${colors.red}-${summary.removed}${colors.reset}`);
}

function printPatch(patchPath) {
  try {
    process.stdout.write(execFileSync('bat', ['--language=diff', '--style=plain', '--color=always', '--paging=never', patchPath], { encoding: 'utf8' }));
  } catch (error) {
    process.stdout.write(error.stdout || fs.readFileSync(patchPath, 'utf8'));
  }
}

function parseInput() {
  const rawInput = fs.readFileSync(0, 'utf8');
  try {
    return JSON.parse(rawInput);
  } catch (error) {
    console.error(`turn-diff hook received invalid JSON: ${error.message}; input length=${rawInput.length}`);
    process.stdout.write('{}\n');
    return null;
  }
}

function safeId(value) {
  return String(value || 'unknown').replace(/[^a-zA-Z0-9_.-]/g, '_');
}

function turnPaths(input) {
  const cwd = input.cwd || process.cwd();
  const thread = safeId(input.thread_id || input.session_id);
  let turn = input.turn_id ? safeId(input.turn_id) : null;
  const activeTurn = path.join(store, `${thread}-active-turn`);

  if (!turn && input.hook_event_name === 'UserPromptSubmit') {
    turn = `generated-${Date.now()}-${crypto.randomUUID()}`;
  } else if (!turn && input.hook_event_name === 'Stop') {
    try {
      turn = fs.readFileSync(activeTurn, 'utf8').trim();
    } catch {}
  }
  turn ||= `orphan-${Date.now()}-${crypto.randomUUID()}`;
  if (input.hook_event_name === 'UserPromptSubmit') {
    fs.mkdirSync(store, { recursive: true });
    fs.writeFileSync(activeTurn, turn);
  }
  const base = path.join(store, `${thread}-${turn}`);
  return {
    cwd,
    base,
    turn,
    activeTurn,
    manifest: path.join(base, 'manifest.json'),
    snapshot: path.join(base, 'files'),
  };
}

function repositoryFiles(cwd) {
  return execFileSync('git', ['ls-files', '-z', '--cached', '--others', '--exclude-standard'], { cwd })
    .toString()
    .split('\0')
    .filter(Boolean);
}

function captureSnapshot(cwd, destination) {
  fs.mkdirSync(destination, { recursive: true });
  const files = [];

  for (const relative of repositoryFiles(cwd)) {
    const source = path.join(cwd, relative);
    try {
      const stat = fs.lstatSync(source);
      if (!stat.isFile() && !stat.isSymbolicLink()) continue;
      const target = path.join(destination, relative);
      fs.mkdirSync(path.dirname(target), { recursive: true });
      const type = stat.isSymbolicLink() ? 'symlink' : 'file';
      if (type === 'symlink') {
        fs.writeFileSync(target, `symlink -> ${fs.readlinkSync(source)}\n`);
      } else {
        fs.copyFileSync(source, target);
      }
      files.push({ path: relative, type });
    } catch {}
  }
  return files;
}

function saveStartSnapshot(paths) {
  fs.mkdirSync(paths.base, { recursive: true });
  fs.rmSync(paths.snapshot, { recursive: true, force: true });
  const files = captureSnapshot(paths.cwd, paths.snapshot);
  fs.writeFileSync(paths.manifest, JSON.stringify({ cwd: paths.cwd, files }));
  process.stdout.write('{"continue":true}\n');
}

function createPatch(paths) {
  if (!fs.existsSync(paths.manifest)) return null;

  const before = JSON.parse(fs.readFileSync(paths.manifest, 'utf8'));
  const afterDir = path.join(paths.base, 'after');
  fs.rmSync(afterDir, { recursive: true, force: true });
  const after = captureSnapshot(paths.cwd, afterDir);
  const beforeFiles = new Map(before.files.map(file => [typeof file === 'string' ? file : file.path, typeof file === 'string' ? 'file' : file.type]));
  const afterFiles = new Map(after.map(file => [file.path, file.type]));
  const changedFiles = [...new Set([...beforeFiles.keys(), ...afterFiles.keys()])].sort();
  let output = '';

  for (const relative of changedFiles) {
    const oldType = beforeFiles.get(relative);
    const newType = afterFiles.get(relative);
    output += diffFile(
      relative,
      path.join(paths.snapshot, relative),
      path.join(afterDir, relative),
      oldType,
      newType,
    );
  }

  const patchPath = path.join(paths.base, 'patch.diff');
  fs.writeFileSync(patchPath, output || '(No file changes in this turn.)\n');
  return { output, patchPath };
}

function diffFile(relative, oldFile, newFile, oldType, newType) {
  const oldExists = fs.existsSync(oldFile);
  const newExists = fs.existsSync(newFile);
  if (oldExists && newExists && oldType === newType && fs.readFileSync(oldFile).equals(fs.readFileSync(newFile))) return '';
  if (oldExists && newExists && oldType !== newType && fs.readFileSync(oldFile).equals(fs.readFileSync(newFile))) {
    return `--- a/${relative}\n+++ b/${relative}\nFile type changed: ${oldType} to ${newType}.\n`;
  }

  const args = [
    '-u',
    '--label', oldExists ? `a/${relative}` : '/dev/null',
    '--label', newExists ? `b/${relative}` : '/dev/null',
    oldExists ? oldFile : '/dev/null',
    newExists ? newFile : '/dev/null',
  ];
  try {
    return execFileSync('diff', args, { encoding: 'utf8' });
  } catch (error) {
    const output = error.stdout || '';
    if (output.startsWith('Binary files ')) {
      return `--- ${oldExists ? `a/${relative}` : '/dev/null'}\n+++ ${newExists ? `b/${relative}` : '/dev/null'}\n${output}`;
    }
    return output;
  }
}

function summarizePatch(output) {
  const files = [];
  let current = null;

  for (const line of output.split('\n')) {
    if (line.startsWith('--- ')) {
      if (current) files.push(current);
      current = { oldPath: line.slice(4), newPath: '', added: 0, removed: 0 };
    } else if (current && line.startsWith('+++ ')) {
      current.newPath = line.slice(4);
    } else if (current && line.startsWith('+') && !line.startsWith('+++')) {
      current.added++;
    } else if (current && line.startsWith('-') && !line.startsWith('---')) {
      current.removed++;
    }
  }
  if (current) files.push(current);

  const summarized = files.map(file => {
    const added = file.oldPath === '/dev/null';
    const deleted = file.newPath === '/dev/null';
    const filePath = deleted ? file.oldPath : file.newPath;
    return {
      path: filePath.replace(/^[ab]\//, ''),
      status: added ? 'A' : deleted ? 'D' : 'M',
      added: file.added,
      removed: file.removed,
    };
  });

  return {
    timestamp: new Date().toLocaleString(),
    files: summarized,
    added: summarized.reduce((total, file) => total + file.added, 0),
    removed: summarized.reduce((total, file) => total + file.removed, 0),
  };
}

function saveTurnDiff(paths) {
  const patch = createPatch(paths);
  if (!patch) return null;

  const summary = summarizePatch(patch.output);
  fs.writeFileSync(path.join(paths.base, 'summary.json'), JSON.stringify(summary, null, 2));
  try {
    if (fs.readFileSync(paths.activeTurn, 'utf8').trim() === paths.turn) {
      fs.rmSync(paths.activeTurn, { force: true });
    }
  } catch {}
  process.stderr.write(`Saved turn diff: ${patch.patchPath}\n`);
  return summary;
}

function handleHook(input) {
  const paths = turnPaths(input);
  if (input.hook_event_name === 'UserPromptSubmit') {
    saveStartSnapshot(paths);
    return;
  }

  if (input.hook_event_name !== 'Stop') {
    process.stdout.write('{}\n');
    return;
  }

  const summary = saveTurnDiff(paths);
  if (!summary) {
    process.stdout.write('{}\n');
    return;
  }

  const lines = summary.files.map(file =>
    `${colors.cyan}${file.path}${colors.reset} ${colors.green}+${file.added}${colors.reset} ${colors.red}-${file.removed}${colors.reset}`,
  );
  const message = `turn-diff\n\n${lines.length ? lines.join('\n') : 'No repo file changes.'}`;
  process.stdout.write(JSON.stringify({ systemMessage: message }) + '\n');
}

if (process.argv[2] === 'show') {
  showLatestTurn();
  process.exit(0);
}

const input = parseInput();
if (input) {
  try {
    handleHook(input);
  } catch (error) {
    console.error(`turn-diff hook error: ${error.stack || error}`);
    process.stdout.write(JSON.stringify({ systemMessage: `turn-diff hook error: ${error.message || error}` }) + '\n');
  }
}
