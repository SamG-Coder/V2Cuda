import { cp, mkdir, readFile, readdir, rm, stat, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const output = path.resolve(root, 'dist');
if (path.dirname(output) !== root || path.basename(output) !== 'dist') {
  throw new Error('Refusing to replace a directory outside the project dist folder.');
}
await rm(output, { recursive: true, force: true });
await mkdir(output, { recursive: true });
for (const name of ['index.html', 'src', 'generated', 'vendor', 'docs', 'LICENSE', 'README.md']) {
  await cp(path.join(root, name), path.join(output, name), { recursive: true });
}
await writeFile(path.join(output, '.nojekyll'), '');

// Verify imports and compiler-worker URLs from the actual browser entrypoint.
const visited = new Set();
async function visit(file) {
  file = path.resolve(file);
  if (!file.startsWith(output + path.sep)) throw new Error(`Module escapes package: ${file}`);
  if (visited.has(file)) return;
  visited.add(file);
  const source = await readFile(file, 'utf8');
  const imports = /(?:\bfrom\s*|\bimport\s*\(|\bnew\s+URL\s*\()\s*['"]([^'"]+)['"]/g;
  for (const match of source.matchAll(imports)) {
    const specifier = match[1];
    if (!specifier.startsWith('.')) throw new Error(`Non-relative dependency: ${specifier}`);
    await visit(path.resolve(path.dirname(file), specifier));
  }
}
await visit(path.join(output, 'src/app.js'));
await stat(path.join(output, 'src/style.css'));
const files = {};
async function inventory(dir) {
  for (const entry of (await readdir(dir, { withFileTypes: true })).sort((a, b) =>
    a.name.localeCompare(b.name),
  )) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) await inventory(file);
    else {
      const bytes = await readFile(file);
      files[path.relative(output, file).split(path.sep).join('/')] = {
        bytes: bytes.length,
        sha256: createHash('sha256').update(bytes).digest('hex'),
      };
    }
  }
}
await inventory(output);
await writeFile(
  path.join(output, 'manifest.json'),
  JSON.stringify({ version: 1, files }, null, 2) + '\n',
);
console.log(
  `Pages package: ${Object.keys(files).length} files; ${visited.size} reachable JavaScript modules verified.`,
);
