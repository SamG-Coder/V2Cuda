import { mkdir, writeFile } from 'node:fs/promises';
import { generate, ENTRIES } from '../src/generator.js';
import { initialGraph } from '../src/graph.js';
import { compile, serializableArtifact } from '../vendor/cuda-webshader/src/compiler/compiler.js';
const source = generate(initialGraph());
await mkdir('generated', { recursive: true });
await writeFile('generated/rising-mist.cu', source);
for (const entry of ENTRIES) {
  const artifact = serializableArtifact(
    compile(source, { entry, workgroupSize: entry === 'mist_render' ? [8, 8, 1] : [64, 1, 1] }),
  );
  await writeFile(`generated/${entry}.json`, JSON.stringify(artifact));
  await writeFile(`generated/${entry}.wgsl`, artifact.wgsl);
  console.log(`${entry}: ${artifact.wgsl.length} WGSL characters`);
}
