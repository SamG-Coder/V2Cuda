import test from 'node:test';
import assert from 'node:assert/strict';
import {
  initialGraph,
  makeNode,
  connect,
  connectedNodes,
  validateGraph,
  sample,
} from '../src/graph.js';
import { generate, ENTRIES } from '../src/generator.js';
import { compile } from '../vendor/cuda-webshader/src/compiler/compiler.js';
test('all solver and rendering entries compile through the actual WebShader compiler', () => {
  const src = generate(initialGraph());
  for (const entry of ENTRIES) {
    const a = compile(src, {
      entry,
      workgroupSize: entry === 'mist_render' ? [8, 8, 1] : [64, 1, 1],
    });
    assert.ok(a.wgsl.includes('@compute'));
  }
});
test('disconnected nodes cannot affect generated CUDA', () => {
  const g = initialGraph(),
    src = generate(g);
  g.nodes.push(makeNode('noise', 'unused', 0, 0));
  assert.equal(generate(g), src);
});
test('port types, missing inputs, duplicate connections and cycles are rejected', () => {
  const g = initialGraph();
  assert.throws(() => connect(g, 'noise', 'emitter', 'shape'), /matching/);
  const broken = structuredClone(g);
  broken.edges = broken.edges.filter((e) => e.to !== 'render');
  assert.throws(() => generate(broken), /connect/);
  const dup = structuredClone(g);
  dup.edges.push(dup.edges[0]);
  assert.throws(() => validateGraph(dup), /one connection/);
  g.nodes.push(makeNode('blend', 'blend', 0, 0));
  assert.throws(() => connect(g, 'blend', 'blend', 'a'), /Cycles/);
});
test('unconnected optional force removes force contribution', () => {
  const g = initialGraph();
  g.edges = g.edges.filter((e) => e.from !== 'noise');
  assert.ok(!connectedNodes(g).some((n) => n.type === 'noise'));
  assert.match(generate(g), /external_force[^\n]+return make_float3\(0.0f,0.0f,0.0f\)/);
});
test('two emitter shapes and two noise layers generate independent functions', () => {
  let g = initialGraph();
  g.nodes.push(
    makeNode('shape', 'second', 0, 0),
    makeNode('blend', 'union', 0, 0),
    makeNode('noise', 'fine', 0, 0),
    makeNode('forceMix', 'forces', 0, 0),
  );
  g.nodes.find((n) => n.id === 'second').values.offset = 0.8;
  g.nodes.find((n) => n.id === 'fine').values.scale = 5;
  for (const [a, b, k] of [
    ['shape', 'union', 'a'],
    ['second', 'union', 'b'],
    ['union', 'emitter', 'shape'],
    ['noise', 'forces', 'a'],
    ['fine', 'forces', 'b'],
    ['forces', 'simulation', 'force'],
  ])
    g = connect(g, a, b, k);
  const src = generate(g);
  assert.match(src, /0.800000f/);
  assert.match(src, /5.000000f/);
  assert.ok(
    compile(src, { entry: 'apply_forces', workgroupSize: [64, 1, 1] }).wgsl.includes('node_'),
  );
});
test('keyframe sampling clamps endpoints and interpolates in seconds', () => {
  const n = makeNode('noise', 'n', 0, 0);
  n.keys.strength = [
    { t: 1, v: 0.2 },
    { t: 3, v: 1.2 },
  ];
  assert.equal(sample(n, 'strength', 0), 0.2);
  assert.equal(sample(n, 'strength', 2), 0.7);
  assert.equal(sample(n, 'strength', 8), 1.2);
  const g = initialGraph();
  g.nodes.find((n) => n.id === 'noise').keys = n.keys;
  assert.ok(compile(generate(g), { entry: 'apply_forces', workgroupSize: [64, 1, 1] }));
});
test('project values and keyframes are bounded before compilation', () => {
  for (const bad of [NaN, Infinity, -1, 99]) {
    const g = initialGraph();
    g.nodes[0].values.radius = bad;
    assert.throws(() => validateGraph(g), /Invalid radius/);
  }
  const g = initialGraph();
  g.nodes[0].keys.radius = [
    { t: 1, v: 0.4 },
    { t: 1, v: 0.5 },
  ];
  assert.throws(() => validateGraph(g), /keyframes/);
});
