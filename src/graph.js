export const TYPES = {
  shape: {
    label: 'Shape · Sphere',
    category: 'SOURCE',
    color: '#9b8cf5',
    output: 'shape',
    inputs: {},
    fields: {
      radius: ['Radius', 0.2, 1.5, 0.01, 0.68],
      height: ['Height', 0.5, 2.8, 0.01, 1.7],
      offset: ['Horizontal offset', -1, 1, 0.01, 0],
    },
  },
  blend: {
    label: 'Shape blend',
    category: 'SHAPE',
    color: '#9b8cf5',
    output: 'shape',
    inputs: { a: 'shape', b: 'shape' },
    fields: { softness: ['Union softness', 0, 1, 0.01, 0.5] },
  },
  noise: {
    label: 'Turbulence',
    category: 'FORCE',
    color: '#dfad68',
    output: 'force',
    inputs: {},
    fields: {
      scale: ['Noise scale', 0.5, 6, 0.01, 2.7],
      strength: ['Strength', 0, 1.5, 0.01, 0.58],
      speed: ['Evolution', 0, 2, 0.01, 0.4],
    },
  },
  forceMix: {
    label: 'Force blend',
    category: 'FORCE',
    color: '#dfad68',
    output: 'force',
    inputs: { a: 'force', b: 'force' },
    fields: { mix: ['Blend', 0, 1, 0.01, 0.5] },
  },
  emitter: {
    label: 'Volume emitter',
    category: 'EMITTER',
    color: '#66cbb7',
    output: 'emitter',
    inputs: { shape: 'shape' },
    fields: { density: ['Density', 0, 4, 0.01, 1.8], lift: ['Rise speed', 0, 2, 0.01, 0.65] },
  },
  simulation: {
    label: 'Smoke simulation',
    category: 'SIMULATION',
    color: '#e78aa4',
    output: 'simulation',
    inputs: { emitter: 'emitter', force: 'force' },
    fields: {
      vorticity: ['Vorticity', 0, 8, 0.01, 3],
      dissipation: ['Dissipation', 0, 1, 0.001, 0.12],
      buoyancy: ['Buoyancy', 0, 3, 0.01, 1.25],
    },
  },
  volume: {
    label: 'Volume processing',
    category: 'VOLUME',
    color: '#ba9fe9',
    output: 'volume',
    inputs: { simulation: 'simulation' },
    fields: {
      absorption: ['Absorption', 0.2, 8, 0.01, 2.4],
      detail: ['Subvoxel detail', 0, 1, 0.01, 0.75],
      contrast: ['Density contrast', 0.5, 2, 0.01, 1.05],
    },
  },
  shading: {
    label: 'Volume shading',
    category: 'MATERIAL',
    color: '#8eb4f1',
    output: 'material',
    inputs: { volume: 'volume' },
    fields: {
      warmth: ['Warmth', 0, 1, 0.01, 0.24],
      light: ['Key light', 0, 3, 0.01, 1.5],
      ambient: ['Ambient', 0, 1, 0.01, 0.24],
    },
  },
  camera: {
    label: 'Camera',
    category: 'CAMERA',
    color: '#8fbfca',
    output: 'camera',
    inputs: {},
    fields: {
      distance: ['Distance', 3, 8, 0.01, 3.5],
      yaw: ['Orbit', -3.14, 3.14, 0.01, 0],
      pitch: ['Elevation', -0.8, 0.8, 0.01, 0.06],
    },
  },
  render: {
    label: 'Render',
    category: 'OUTPUT',
    color: '#c3d7a1',
    output: null,
    inputs: { material: 'material', camera: 'camera' },
    fields: { exposure: ['Exposure', 0.2, 3, 0.01, 1.7] },
  },
};
export function makeNode(type, id, x, y) {
  return {
    id,
    type,
    x,
    y,
    values: Object.fromEntries(Object.entries(TYPES[type].fields).map(([k, v]) => [k, v[4]])),
    keys: {},
  };
}
export function initialGraph() {
  const nodes = [
    makeNode('shape', 'shape', 30, 30),
    makeNode('noise', 'noise', 250, 220),
    makeNode('emitter', 'emitter', 250, 30),
    makeNode('simulation', 'simulation', 470, 70),
    makeNode('volume', 'volume', 690, 70),
    makeNode('shading', 'shading', 690, 290),
    makeNode('camera', 'camera', 30, 290),
    makeNode('render', 'render', 470, 290),
  ];
  nodes[0].values.radius = 0.68;
  nodes[0].values.height = 1.6;
  nodes[2].keys.density = [
    { t: 0, v: 2.4 },
    { t: 0.8, v: 2.4 },
    { t: 1.5, v: 0 },
    { t: 3.8, v: 0 },
    { t: 4.2, v: 2.2 },
    { t: 5, v: 2.2 },
    { t: 5.8, v: 0 },
    { t: 8, v: 0 },
  ];
  return {
    version: 1,
    name: 'Rising Mist',
    nodes,
    edges: [
      { from: 'shape', to: 'emitter', input: 'shape' },
      { from: 'emitter', to: 'simulation', input: 'emitter' },
      { from: 'noise', to: 'simulation', input: 'force' },
      { from: 'simulation', to: 'volume', input: 'simulation' },
      { from: 'volume', to: 'shading', input: 'volume' },
      { from: 'shading', to: 'render', input: 'material' },
      { from: 'camera', to: 'render', input: 'camera' },
    ],
  };
}
export function validateGraph(g) {
  if (
    !g ||
    g.version !== 1 ||
    typeof g.name !== 'string' ||
    g.name.length > 80 ||
    !Array.isArray(g.nodes) ||
    !Array.isArray(g.edges) ||
    g.nodes.length > 60 ||
    g.edges.length > 100
  )
    throw Error('Unsupported project.');
  const ids = new Set();
  for (const n of g.nodes) {
    if (!Object.hasOwn(TYPES, n.type) || !/^[a-zA-Z][\w-]{0,63}$/.test(n.id) || ids.has(n.id))
      throw Error('Invalid node identity.');
    ids.add(n.id);
    if (!Number.isFinite(n.x) || !Number.isFinite(n.y)) throw Error('Invalid node position.');
    if (
      !n.values ||
      typeof n.values !== 'object' ||
      Object.keys(n.values).some((k) => !Object.hasOwn(TYPES[n.type].fields, k)) ||
      Object.keys(n.keys || {}).some((k) => !Object.hasOwn(TYPES[n.type].fields, k))
    )
      throw Error('Unknown node parameter.');
    for (const [k, [, min, max]] of Object.entries(TYPES[n.type].fields)) {
      if (!Number.isFinite(n.values?.[k]) || n.values[k] < min || n.values[k] > max)
        throw Error(`Invalid ${k}.`);
      const keys = n.keys?.[k] || [];
      if (
        !Array.isArray(keys) ||
        keys.length > 100 ||
        keys.some(
          (v) =>
            !Number.isFinite(v.t) ||
            v.t < 0 ||
            v.t > 8 ||
            !Number.isFinite(v.v) ||
            v.v < min ||
            v.v > max,
        ) ||
        new Set(keys.map((v) => v.t)).size !== keys.length
      )
        throw Error(`Invalid ${k} keyframes.`);
    }
  }
  if (g.nodes.filter((n) => n.type === 'render').length !== 1)
    throw Error('The graph needs exactly one Render node.');
  const ports = new Set();
  for (const e of g.edges) {
    const a = g.nodes.find((n) => n.id === e.from),
      b = g.nodes.find((n) => n.id === e.to);
    if (!a || !b || !TYPES[a.type].output || TYPES[a.type].output !== TYPES[b.type].inputs[e.input])
      throw Error('Connect matching socket types.');
    const port = e.to + ':' + e.input;
    if (ports.has(port)) throw Error('An input may have only one connection.');
    ports.add(port);
  }
  const seen = new Set(),
    active = new Set();
  function visit(id) {
    if (active.has(id)) throw Error('Cycles are not supported.');
    if (seen.has(id)) return;
    active.add(id);
    for (const e of g.edges.filter((e) => e.to === id)) visit(e.from);
    active.delete(id);
    seen.add(id);
  }
  for (const n of g.nodes) visit(n.id);
  return g;
}
export function connectedNodes(g) {
  validateGraph(g);
  const result = [],
    seen = new Set();
  function visit(n) {
    if (seen.has(n.id)) return;
    seen.add(n.id);
    for (const input of Object.keys(TYPES[n.type].inputs)) {
      const edge = g.edges.find((e) => e.to === n.id && e.input === input);
      if (!edge) {
        if (n.type === 'simulation' && input === 'force') continue;
        throw Error(`${TYPES[n.type].label}: connect the ${input} input.`);
      }
      visit(g.nodes.find((n) => n.id === edge.from));
    }
    result.push(n);
  }
  visit(g.nodes.find((n) => n.type === 'render'));
  return result;
}
export function connect(g, from, to, input) {
  const next = structuredClone(g);
  next.edges = next.edges.filter((e) => !(e.to === to && e.input === input));
  next.edges.push({ from, to, input });
  validateGraph(next);
  return next;
}
export function sample(n, key, t) {
  const keys = [...(n.keys?.[key] || [])].sort((a, b) => a.t - b.t);
  if (!keys.length) return n.values[key];
  if (t <= keys[0].t) return keys[0].v;
  for (let i = 1; i < keys.length; i++)
    if (t <= keys[i].t) {
      const f = (t - keys[i - 1].t) / (keys[i].t - keys[i - 1].t);
      return keys[i - 1].v + (keys[i].v - keys[i - 1].v) * f;
    }
  return keys.at(-1).v;
}
