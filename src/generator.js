import { connectedNodes, TYPES } from './graph.js';
import { FLUID_SOURCE } from './solver-source.js';
const f = (v) => Number(v).toFixed(6) + 'f';
export const ENTRIES = [
  'clear_field',
  'advect',
  'compute_curl',
  'apply_forces',
  'divergence',
  'pressure_solve',
  'project',
  'mist_render',
];
export function generate(g) {
  const nodes = connectedNodes(g),
    functions = [];
  for (const [type, def] of Object.entries(TYPES))
    for (const [key, field] of Object.entries(def.fields)) {
      const n = nodes.find((n) => n.type === type),
        name = `p_${type}_${key}`,
        keys = [...(n?.keys?.[key] || [])].sort((a, b) => a.t - b.t);
      if (!keys.length) {
        functions.push(
          `__device__ float ${name}(float time) { return ${f(n ? n.values[key] : type === 'noise' ? 0 : field[4])}; }`,
        );
        continue;
      }
      functions.push(
        `__device__ float ${name}(float time) {\n  if (time <= ${f(keys[0].t)}) return ${f(keys[0].v)};\n${keys
          .slice(1)
          .map(
            (k, i) =>
              `  if (time <= ${f(k.t)}) return ${f(keys[i].v)} + (${f(k.v - keys[i].v)}) * (time-${f(keys[i].t)}) / ${f(k.t - keys[i].t)};`,
          )
          .join('\n')}\n  return ${f(keys.at(-1).v)};\n}`,
      );
    }
  const id = (n) => 'node_' + nodes.indexOf(n),
    input = (n, k) =>
      nodes.find((a) => a.id === g.edges.find((e) => e.to === n.id && e.input === k)?.from);
  for (const n of nodes.filter((n) => ['shape', 'blend', 'noise', 'forceMix'].includes(n.type))) {
    for (const [key, value] of Object.entries(n.values)) {
      const keys = [...(n.keys?.[key] || [])].sort((a, b) => a.t - b.t),
        name = id(n) + '_' + key;
      const body = !keys.length
        ? `return ${f(value)};`
        : `if(time<=${f(keys[0].t)})return ${f(keys[0].v)};\n${keys
            .slice(1)
            .map(
              (k, i) =>
                `if(time<=${f(k.t)})return ${f(keys[i].v)}+${f(k.v - keys[i].v)}*(time-${f(keys[i].t)})/${f(k.t - keys[i].t)};`,
            )
            .join('\n')}return ${f(keys.at(-1).v)};`;
      functions.push(`__device__ float ${name}(float time){${body}}`);
    }
    const v = (k) => `${id(n)}_${k}(time)`,
      call = (k) => `${id(input(n, k))}(x,y,z,time)`;
    if (n.type === 'shape')
      functions.push(
        `__device__ float ${id(n)}(float x,float y,float z,float time){float ex=(x-${v('offset')})/${v('radius')};float ey=(y+1.12f)/(${v('height')}*0.32f);float ez=z/${v('radius')};return sat(1.0f-ex*ex-ey*ey-ez*ez);}`,
      );
    if (n.type === 'blend')
      functions.push(
        `__device__ float ${id(n)}(float x,float y,float z,float time){float a=${call('a')};float b=${call('b')};return mixf(fmaxf(a,b),sat(a+b),${v('softness')});}`,
      );
    if (n.type === 'noise')
      functions.push(
        `__device__ float3 ${id(n)}(float x,float y,float z,float time){float s=${v('scale')};float t=time*${v('speed')};return make_float3(noise3(x*s,y*s-t,z*s)-0.5f,(noise3(x*s+19.0f,y*s-t,z*s+8.0f)-0.5f)*0.3f,noise3(x*s+33.0f,y*s-t,z*s+12.0f)-0.5f)*${v('strength')};}`,
      );
    if (n.type === 'forceMix')
      functions.push(
        `__device__ float3 ${id(n)}(float x,float y,float z,float time){return ${call('a')}*(1.0f-${v('mix')})+${call('b')}*${v('mix')};}`,
      );
  }
  const emitter = nodes.find((n) => n.type === 'emitter'),
    simulation = nodes.find((n) => n.type === 'simulation'),
    force = input(simulation, 'force');
  functions.push(
    `__device__ float emitter_shape(float x,float y,float z,float time){return ${id(input(emitter, 'shape'))}(x,y,z,time);}`,
  );
  functions.push(
    `__device__ float3 external_force(float x,float y,float z,float time){return ${force ? id(force) + '(x,y,z,time)' : 'make_float3(0.0f,0.0f,0.0f)'};}`,
  );
  return `// V2Cuda — live graph → CUDA → WGSL → WebGPU\n// Connected graph: ${nodes.map((n) => n.type).join(' → ')}\n// 3D incompressible smoke: semi-Lagrangian advection, vorticity confinement,\n// buoyancy, Jacobi pressure projection and lit volume ray marching.\n// Animation curves are compiled below. All simulation and pixels execute in CUDA.\n// Host dispatch contract: see README.md.\n\n${functions.join('\n')}\n\n${FLUID_SOURCE}`;
}
