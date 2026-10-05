import {
  TYPES,
  initialGraph,
  makeNode,
  connect,
  validateGraph,
  connectedNodes,
  sample,
} from './graph.js';
import { generate, ENTRIES } from './generator.js';
import { SmokeEngine } from './engine.js';
const $ = (id) => document.getElementById(id),
  esc = (s) =>
    String(s).replace(
      /[&<>"']/g,
      (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c],
    );
let graph = initialGraph(),
  engine,
  selected = 'simulation',
  selectedProp = 'vorticity',
  playing = true,
  loop = true,
  busy = false,
  compileBusy = false,
  compilePending = false,
  ready = false,
  revision = 0,
  compileTimer,
  source = '',
  activeSource = '',
  activeSim = '',
  tab = 'graph',
  pendingSocket = null,
  view = { x: 25, y: 100, scale: 0.5 },
  undo = [],
  redo = [],
  seekTarget = null,
  frameCount = 0,
  fpsStart = performance.now(),
  lastTick = 0,
  toastTimer;
const descriptions = {
  blend: 'Combines two independent emitter shapes into a soft union.',
  forceMix:
    'Blends two force fields. Connect turbulence nodes with different scales for layered motion.',
  shape: 'Defines the ellipsoid that emits smoke into the 3D field.',
  noise: 'A time-varying noise force disturbs velocity and breaks up the plume.',
  emitter: 'Injects density and upward velocity into the connected shape.',
  simulation:
    'Advects the field, confines vorticity and projects velocity through a pressure solve.',
  volume: 'Shapes the density response and optical thickness of the volume.',
  shading: 'A soft directional key and ambient fill illuminate the ray-marched smoke.',
  camera: 'An animated perspective camera. Orbit the viewport to apply an inspection offset.',
  render: 'Composites the lit volume and maps radiance into display pixels.',
};
try {
  const saved = localStorage.getItem('v2cuda-project');
  if (saved) {
    graph = validateGraph(JSON.parse(saved));
  }
} catch {}
function toast(message) {
  $('toast').textContent = message;
  $('toast').classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => $('toast').classList.remove('show'), 3800);
}
function error(e) {
  console.error(e);
  $('compile-status').textContent = 'Could not apply changes';
  $('compile-detail').textContent = e.message || String(e);
  $('compile-detail').classList.add('error');
  $('compile-dot').className = 'status-dot error';
  $('bottom-status').textContent = ready
    ? 'Last valid shader retained'
    : 'Connect the graph to start the shader';
  if (!ready) {
    $('loading').querySelector('b').textContent = 'Graph needs attention';
    $('loading-text').textContent = e.message || String(e);
    $('loading').querySelector('.spinner').style.display = 'none';
  }
}
function persist() {
  try {
    localStorage.setItem('v2cuda-project', JSON.stringify(graph));
    $('save-state').textContent = 'Saved locally';
  } catch {
    $('save-state').textContent = 'Local storage unavailable';
  }
}
function remember() {
  undo.push(JSON.stringify(graph));
  if (undo.length > 60) undo.shift();
  redo = [];
  historyUI();
}
function historyUI() {
  $('undo').disabled = !undo.length;
  $('redo').disabled = !redo.length;
}
function historyStep(forward = false) {
  const a = forward ? redo : undo,
    b = forward ? undo : redo;
  if (!a.length) return;
  b.push(JSON.stringify(graph));
  graph = JSON.parse(a.pop());
  selected = graph.nodes.find((n) => n.id === selected)?.id || graph.nodes[0].id;
  refresh();
  scheduleCompile();
  historyUI();
}
function refresh() {
  document
    .querySelectorAll('[data-preset]')
    .forEach((b) =>
      b.classList.toggle(
        'active',
        { rising: 'Rising Mist', wispy: 'Wispy Mist', fog: 'Low Fog' }[b.dataset.preset] ===
          graph.name,
      ),
    );
  drawGraph();
  drawInspector();
  drawTimeline();
  $('project-name').value = graph.name;
  $('effect-title').textContent = graph.name;
  persist();
}
function simSignature() {
  return JSON.stringify(
    connectedNodes(graph)
      .filter((n) =>
        ['shape', 'blend', 'noise', 'forceMix', 'emitter', 'simulation'].includes(n.type),
      )
      .map((n) => ({ type: n.type, values: n.values, keys: n.keys })),
  );
}
function scheduleCompile(immediate = false) {
  compilePending = true;
  const version = ++revision;
  clearTimeout(compileTimer);
  try {
    source = generate(graph);
    drawCode();
    $('compile-status').textContent = 'CUDA regenerated';
    $('compile-detail').textContent =
      `${source.split('\n').length} source lines · compiling 8 kernels in a worker`;
    $('compile-detail').classList.remove('error');
    $('compile-dot').className = 'status-dot busy';
  } catch (e) {
    compilePending = false;
    error(e);
    persist();
    return;
  }
  persist();
  compileTimer = setTimeout(() => recompile(version), immediate ? 0 : 280);
}
async function recompile(version) {
  if (!engine) return;
  if (compileBusy || busy) {
    compileTimer = setTimeout(() => {
      if (version === revision) recompile(version);
    }, 100);
    return;
  }
  if (source === activeSource) {
    compilePending = false;
    $('compile-detail').classList.remove('error');
    $('bottom-status').textContent = 'CUDA WebShader ready';
    $('compile-status').textContent = 'Live · shader up to date';
    $('compile-detail').textContent =
      'Connected graph unchanged. Disconnected nodes do not affect the program.';
    $('compile-dot').className = 'status-dot';
    return;
  }
  compileBusy = true;
  const current = source;
  try {
    $('compile-status').textContent = 'Compiling CUDA → WGSL';
    const result = await engine.compile(current);
    if (version !== revision || !result) return;
    busy = true;
    const sig = simSignature(),
      reset = sig !== activeSim || !ready,
      target = ready ? engine.frame : 90;
    engine.install(result, reset);
    activeSource = current;
    activeSim = sig;
    if (reset) {
      $('compile-status').textContent = 'Replaying simulation';
      await engine.seek(target, (f) => {
        $('loading-text').textContent = `Simulating frame ${f} / ${target}`;
        updateTime();
      });
    }
    engine.render();
    await engine.runtime.idle();
    if (!ready) {
      fpsStart = performance.now();
      frameCount = 0;
    }
    ready = true;
    $('loading').hidden = true;
    $('compile-status').textContent = 'Live · 8 kernels compiled';
    $('compile-time').textContent = `${Math.round(result.ms)} ms`;
    $('compile-detail').textContent =
      'Graph edits generate CUDA. The installed GPU program is shown in the source tabs.';
    $('compile-dot').className = 'status-dot';
    $('gpu-status').textContent = 'WebGPU connected';
    $('bottom-status').textContent = 'CUDA WebShader ready';
    drawCode();
    updateTime();
    window.studio.ready = true;
  } catch (e) {
    error(e);
    $('loading').hidden = true;
  } finally {
    compileBusy = false;
    busy = false;
    if (version === revision) compilePending = false;
  }
}
function portY(n, input) {
  const keys = Object.keys(TYPES[n.type].inputs);
  return n.y + 63 + keys.indexOf(input) * 27;
}
function outputY(n) {
  return n.y + 63 + Object.keys(TYPES[n.type].inputs).length * 27;
}
function drawGraph() {
  $('nodes').innerHTML = graph.nodes
    .map((n) => {
      const d = TYPES[n.type];
      return `<div class="node ${n.id === selected ? 'selected' : ''}" data-id="${n.id}" style="left:${n.x}px;top:${n.y}px;--node-color:${d.color}"><div class="node-head">${d.label}</div><div class="node-category">${d.category}</div>${Object.keys(
        d.inputs,
      )
        .map(
          (k) =>
            `<div class="node-port"><button class="socket ${graph.edges.some((e) => e.to === n.id && e.input === k) ? 'connected' : ''}" data-node="${n.id}" data-input="${k}" aria-label="${d.label} ${k} input"></button>${k}</div>`,
        )
        .join(
          '',
        )}${d.output ? `<div class="node-port output">${d.output}<button class="socket ${graph.edges.some((e) => e.from === n.id) ? 'connected' : ''}" data-node="${n.id}" data-output="${d.output}" aria-label="${d.label} output"></button></div>` : ''}<div class="node-summary">${Object.entries(
        n.values,
      )
        .slice(0, 2)
        .map(([k, v]) => `${k} ${v.toFixed(2)}`)
        .join(' · ')}</div></div>`;
    })
    .join('');
  drawWires();
  $('node-count').textContent = `${graph.nodes.length} nodes · ${graph.edges.length} connections`;
  for (const el of $('nodes').querySelectorAll('.node')) {
    el.onpointerdown = (e) => {
      if (e.target.closest('.socket')) return;
      selectNode(el.dataset.id);
      if (!e.target.closest('.node-head')) return;
      remember();
      const n = graph.nodes.find((n) => n.id === el.dataset.id),
        start = { x: e.clientX, y: e.clientY, nx: n.x, ny: n.y };
      el.setPointerCapture(e.pointerId);
      el.onpointermove = (e) => {
        n.x = Math.max(-400, Math.min(1800, start.nx + (e.clientX - start.x) / view.scale));
        n.y = Math.max(-300, Math.min(1000, start.ny + (e.clientY - start.y) / view.scale));
        el.style.left = n.x + 'px';
        el.style.top = n.y + 'px';
        drawWires();
      };
      el.onpointerup = () => {
        el.onpointermove = null;
        persist();
      };
      e.stopPropagation();
    };
  }
  for (const socket of $('nodes').querySelectorAll('.socket')) {
    socket.onclick = (e) => {
      e.stopPropagation();
      const n = socket.dataset.node;
      if (socket.dataset.output) {
        pendingSocket = n;
        $('graph-hint').textContent = `Connect ${socket.dataset.output} output to a matching input`;
        document.querySelectorAll('.socket').forEach((s) => s.classList.remove('pending'));
        socket.classList.add('pending');
      } else if (pendingSocket) {
        try {
          const next = connect(graph, pendingSocket, n, socket.dataset.input);
          remember();
          graph = next;
          pendingSocket = null;
          refresh();
          scheduleCompile();
          $('graph-hint').textContent = 'Connected · the live CUDA program is updating';
        } catch (e) {
          toast(e.message);
        }
      }
    };
    socket.oncontextmenu = (e) => {
      e.preventDefault();
      e.stopPropagation();
      if (socket.dataset.input) disconnect(nKey(socket));
    };
  }
}
function nKey(socket) {
  return { to: socket.dataset.node, input: socket.dataset.input };
}
function disconnect(edge) {
  remember();
  graph.edges = graph.edges.filter((e) => !(e.to === edge.to && e.input === edge.input));
  refresh();
  scheduleCompile();
}
function drawWires() {
  $('wires').innerHTML = graph.edges
    .map((e, i) => {
      const a = graph.nodes.find((n) => n.id === e.from),
        b = graph.nodes.find((n) => n.id === e.to),
        x = a.x + 184,
        y = outputY(a),
        tx = b.x,
        ty = portY(b, e.input),
        bend = Math.max(50, Math.abs(tx - x) * 0.5);
      return `<path class="wire" data-edge="${i}" stroke="${TYPES[a.type].color}" d="M${x} ${y} C${x + bend} ${y},${tx - bend} ${ty},${tx} ${ty}"/>`;
    })
    .join('');
  for (const p of $('wires').querySelectorAll('path'))
    p.oncontextmenu = (e) => {
      e.preventDefault();
      disconnect(graph.edges[+p.dataset.edge]);
    };
}
function selectNode(id) {
  selected = id;
  const n = graph.nodes.find((n) => n.id === id);
  if (!(selectedProp in n.values)) selectedProp = Object.keys(n.values)[0];
  document
    .querySelectorAll('.node')
    .forEach((el) => el.classList.toggle('selected', el.dataset.id === id));
  drawInspector();
  drawTimeline();
}
function drawInspector() {
  const n = graph.nodes.find((n) => n.id === selected);
  if (!n) return;
  const d = TYPES[n.type];
  $('delete-node').disabled = n.type === 'render';
  $('inspector-content').innerHTML =
    `<div class="inspector-title" style="--node-color:${d.color}"><small>${d.category}</small><h2>${d.label}</h2><p>${descriptions[n.type]}</p></div><div class="property-group"><div class="group-label">PARAMETERS</div>${Object.entries(
      d.fields,
    )
      .map(
        ([k, [label, min, max, step]]) =>
          `<div class="property ${k === selectedProp ? 'selected' : ''}" data-property="${k}"><div class="property-label"><label for="number-${k}">${label}</label><input id="number-${k}" aria-label="${label} value" type="number" min="${min}" max="${max}" step="${step}" value="${sample(n, k, (engine?.frame || 0) / 30).toFixed(3)}"><button class="key-button ${n.keys?.[k]?.length ? 'keyed' : ''}" data-key="${k}" title="Keyframe ${label}" aria-label="Keyframe ${label}">◇</button></div><input id="range-${k}" aria-label="${label}" type="range" min="${min}" max="${max}" step="${step}" value="${sample(n, k, (engine?.frame || 0) / 30).toFixed(3)}"><div class="property-range"><span>${min}</span><span>${n.keys?.[k]?.length ? `${n.keys[k].length} keys · linear` : 'Constant'}</span><span>${max}</span></div></div>`,
      )
      .join('')}</div><div class="connection-list"><div class="group-label">CONNECTIONS</div>${
      Object.keys(d.inputs)
        .map((k) => {
          const e = graph.edges.find((e) => e.to === n.id && e.input === k);
          return `<div class="connection-item"><span>${k}</span><b>${e ? TYPES[graph.nodes.find((a) => a.id === e.from).type].label : 'Not connected'}</b></div>`;
        })
        .join('') || '<div class="connection-item">Source node · no inputs</div>'
    }<div class="connection-item"><span>Output</span><b>${d.output || 'GPU viewport'}</b></div></div>`;
  for (const [k, [, min, max]] of Object.entries(d.fields)) {
    const range = $('range-' + k),
      number = $('number-' + k);
    for (const input of [range, number]) {
      input.onpointerdown = () => {
        remember();
        selectedProp = k;
        if (n.keys?.[k]?.length) setPlaying(false);
      };
      input.onfocus = () => {
        selectedProp = k;
      };
      input.onchange = () => {
        if (!Number.isFinite(+input.value) || input.value === '') {
          input.value = n.values[k];
          return;
        }
        const v = Math.min(max, Math.max(min, +input.value));
        setParameter(n, k, v);
        range.value = number.value = v;
        scheduleCompile();
      };
      input.oninput = () => {
        const v = +input.value;
        if (input.value === '' || !Number.isFinite(v) || v < min || v > max) return;
        setParameter(n, k, v);
        range.value = number.value = v;
        selectedProp = k;
        document
          .querySelectorAll('.property')
          .forEach((p) => p.classList.toggle('selected', p.dataset.property === k));
        scheduleCompile();
      };
    }
  }
  for (const b of $('inspector-content').querySelectorAll('.key-button'))
    b.onclick = () => {
      selectedProp = b.dataset.key;
      addKey();
    };
}
function setParameter(n, key, value) {
  n.values[key] = value;
  if (n.keys?.[key]?.length && engine) {
    setPlaying(false);
    const t = engine.frame / 30;
    n.keys[key] = n.keys[key].filter((k) => Math.abs(k.t - t) > 0.0001);
    n.keys[key].push({ t, v: value });
    n.keys[key].sort((a, b) => a.t - b.t);
    drawTimeline();
  }
}
function addKey() {
  if (!ready) return;
  const n = graph.nodes.find((n) => n.id === selected);
  remember();
  n.keys ??= {};
  n.keys[selectedProp] ??= [];
  const t = engine.frame / 30;
  n.keys[selectedProp] = n.keys[selectedProp].filter((k) => Math.abs(k.t - t) > 0.0001);
  n.keys[selectedProp].push({
    t,
    v: Number($('number-' + selectedProp)?.value ?? n.values[selectedProp]),
  });
  n.keys[selectedProp].sort((a, b) => a.t - b.t);
  drawInspector();
  drawTimeline();
  scheduleCompile();
  toast(`Keyframe added at frame ${engine.frame}`);
}
function tracks() {
  const rows = [];
  for (const n of graph.nodes)
    for (const [k, keys] of Object.entries(n.keys || {}))
      if (keys.length) rows.push({ n, k, keys });
  const n = graph.nodes.find((n) => n.id === selected);
  if (n && !rows.some((r) => r.n === n && r.k === selectedProp))
    rows.push({ n, k: selectedProp, keys: [] });
  if (rows.length < 3)
    for (const [type, k] of [
      ['emitter', 'density'],
      ['noise', 'strength'],
      ['simulation', 'vorticity'],
    ]) {
      const n = graph.nodes.find((n) => n.type === type);
      if (n && !rows.some((r) => r.n === n && r.k === k))
        rows.push({ n, k, keys: n.keys?.[k] || [] });
      if (rows.length >= 3) break;
    }
  return rows;
}
function drawTimeline() {
  const rows = tracks();
  $('ruler').innerHTML = Array.from(
    { length: 9 },
    (_, i) => `<span>${String(i).padStart(2, '0')}s</span>`,
  ).join('');
  $('track-names').innerHTML = rows
    .map(
      ({ n, k, keys }) =>
        `<div class="track-label" style="--track-color:${TYPES[n.type].color}" data-node="${n.id}" data-prop="${k}"><i></i>${TYPES[n.type].fields[k][0]}<span>${keys.length ? keys.length + ' keys' : '—'}</span></div>`,
    )
    .join('');
  $('tracks').innerHTML = rows
    .map(
      ({ n, k, keys }) =>
        `<div class="track" style="--track-color:${TYPES[n.type].color}"><div class="track-line"></div>${keys.map((key, i) => `<button class="diamond" style="left:${Math.max(0.7, Math.min(99.3, (key.t / 8) * 100))}%" data-node="${n.id}" data-prop="${k}" data-index="${i}" title="Frame ${Math.round(key.t * 30)} · ${key.v.toFixed(2)}. Right-click to remove" aria-label="${TYPES[n.type].fields[k][0]} key at frame ${Math.round(key.t * 30)}"></button>`).join('')}</div>`,
    )
    .join('');
  for (const el of $('track-names').querySelectorAll('.track-label'))
    el.onclick = () => {
      selectedProp = el.dataset.prop;
      selectNode(el.dataset.node);
    };
  for (const el of $('tracks').querySelectorAll('.diamond')) {
    el.onclick = () => {
      const n = graph.nodes.find((n) => n.id === el.dataset.node);
      setPlaying(false);
      queueSeek(n.keys[el.dataset.prop][+el.dataset.index].t * 30);
    };
    el.oncontextmenu = (e) => {
      e.preventDefault();
      remember();
      graph.nodes
        .find((n) => n.id === el.dataset.node)
        .keys[el.dataset.prop].splice(+el.dataset.index, 1);
      drawInspector();
      drawTimeline();
      scheduleCompile();
    };
  }
  updateTime();
}
function updateTime() {
  const frame = engine?.frame || 0;
  $('playhead').style.left = `${(frame / 240) * 100}%`;
  $('scrubber').value = frame;
  $('timecode').textContent =
    `00:${String(Math.floor(frame / 30)).padStart(2, '0')}:${String(frame % 30).padStart(2, '0')}`;
  $('cache-status').textContent = `GPU state cache · ${engine?.cache.size || 0} checkpoints`;
}
function setPlaying(value) {
  playing = value;
  $('play').textContent = playing ? 'Ⅱ' : '▶';
  $('play').setAttribute('aria-label', playing ? 'Pause' : 'Play');
}
async function queueSeek(frame) {
  seekTarget = Math.round(frame);
  if (!ready || busy) return;
  busy = true;
  try {
    while (seekTarget !== null) {
      const target = seekTarget;
      seekTarget = null;
      $('bottom-status').textContent = `Replaying to frame ${target}`;
      await engine.seek(target, () => updateTime());
      engine.render();
      updateTime();
    }
    $('bottom-status').textContent = 'CUDA WebShader ready';
  } catch (e) {
    error(e);
  } finally {
    busy = false;
  }
}
function applyView() {
  $('graph-world').style.transform = `translate(${view.x}px,${view.y}px) scale(${view.scale})`;
  $('graph-zoom').textContent = Math.round(view.scale * 100) + '%';
}
function fitGraph() {
  const rect = $('graph-view').getBoundingClientRect(),
    xs = graph.nodes.map((n) => n.x),
    ys = graph.nodes.map((n) => n.y),
    minx = Math.min(...xs),
    miny = Math.min(...ys),
    width = Math.max(...xs) + 205 - minx,
    height = Math.max(...ys) + 170 - miny;
  view.scale = Math.max(0.2, Math.min(1, (rect.width - 45) / width, (rect.height - 95) / height));
  view.x = (rect.width - width * view.scale) / 2 - minx * view.scale;
  view.y = (rect.height - height * view.scale) / 2 - miny * view.scale + 3;
  applyView();
}
function zoomGraph(
  factor,
  x = $('graph-view').clientWidth / 2,
  y = $('graph-view').clientHeight / 2,
) {
  const old = view.scale;
  view.scale = Math.max(0.2, Math.min(1.8, old * factor));
  view.x = x - ((x - view.x) * view.scale) / old;
  view.y = y - ((y - view.y) * view.scale) / old;
  applyView();
}
$('graph-view').onpointerdown = (e) => {
  if (e.target.closest('.node,.graph-tools,.wire')) return;
  const x = e.clientX,
    y = e.clientY,
    vx = view.x,
    vy = view.y;
  $('graph-view').setPointerCapture(e.pointerId);
  $('graph-view').onpointermove = (e) => {
    view.x = vx + e.clientX - x;
    view.y = vy + e.clientY - y;
    applyView();
  };
  $('graph-view').onpointerup = () => {
    $('graph-view').onpointermove = null;
  };
};
$('graph-view').addEventListener(
  'wheel',
  (e) => {
    e.preventDefault();
    const r = $('graph-view').getBoundingClientRect();
    zoomGraph(e.deltaY < 0 ? 1.1 : 1 / 1.1, e.clientX - r.left, e.clientY - r.top);
  },
  { passive: false },
);
function drawCode() {
  if (tab === 'graph') return;
  const text =
    tab === 'cuda'
      ? source
      : engine?.artifacts?.[$('kernel-select').value]?.wgsl ||
        '// Waiting for the first successful compile.';
  $('code-name').textContent =
    tab === 'cuda' ? 'live-graph.cu' : $('kernel-select').value + '.wgsl';
  $('kernel-select').hidden = tab !== 'wgsl';
  $('source-code').innerHTML = text
    .split('\n')
    .map((line, i) => {
      let html = esc(line);
      if (line.trim().startsWith('//')) html = `<span class="code-comment">${html}</span>`;
      else
        html = html.replace(
          /\b(__global__|__device__|float4|float|int|unsigned|void|return|if|for|const|fn|var|let|struct)\b/g,
          '<span class="code-keyword">$1</span>',
        );
      return `<span class="code-line"><span class="line-no">${i + 1}</span>${html}</span>`;
    })
    .join('');
}
for (const b of document.querySelectorAll('[data-tab]'))
  b.onclick = () => {
    tab = b.dataset.tab;
    document.querySelectorAll('[data-tab]').forEach((e) => e.classList.toggle('active', e === b));
    $('graph-view').hidden = tab !== 'graph';
    $('code-view').hidden = tab === 'graph';
    $('add-node').hidden = tab !== 'graph';
    drawCode();
  };
$('kernel-select').innerHTML = ENTRIES.map((e) => `<option>${e}</option>`).join('');
$('kernel-select').value = 'mist_render';
$('kernel-select').onchange = drawCode;
$('copy-code').onclick = async () => {
  try {
    await navigator.clipboard.writeText(
      tab === 'cuda' ? source : engine.artifacts[$('kernel-select').value].wgsl,
    );
    toast('Source copied.');
  } catch {
    toast('Clipboard unavailable. Select and copy the source text.');
  }
};
$('node-library').innerHTML = Object.entries(TYPES)
  .filter(([k]) => k !== 'render')
  .map(
    ([k, d]) =>
      `<button data-type="${k}" style="--node-color:${d.color}"><small>${d.category}</small>${d.label}</button>`,
  )
  .join('');
for (const b of $('node-library').querySelectorAll('button'))
  b.onclick = () => {
    remember();
    const type = b.dataset.type,
      id = type + '_' + crypto.randomUUID().slice(0, 8),
      r = $('graph-view').getBoundingClientRect();
    graph.nodes.push(
      makeNode(type, id, (r.width / 2 - view.x) / view.scale, (r.height / 2 - view.y) / view.scale),
    );
    selected = id;
    selectedProp = Object.keys(TYPES[type].fields)[0];
    refresh();
    $('node-dialog').close();
    toast('Node added. Connect it to include it in the shader.');
  };
$('add-node').onclick = () => $('node-dialog').showModal();
$('help').onclick = () => $('help-dialog').showModal();
for (const b of document.querySelectorAll('.close-dialog'))
  b.onclick = () => b.closest('dialog').close();
function deleteNode() {
  const n = graph.nodes.find((n) => n.id === selected);
  if (!n || n.type === 'render') return;
  remember();
  graph.nodes = graph.nodes.filter((a) => a !== n);
  graph.edges = graph.edges.filter((e) => e.from !== n.id && e.to !== n.id);
  selected = graph.nodes[0].id;
  selectedProp = Object.keys(graph.nodes[0].values)[0];
  refresh();
  scheduleCompile();
}
$('delete-node').onclick = deleteNode;
$('undo').onclick = () => historyStep();
$('redo').onclick = () => historyStep(true);
$('add-key').onclick = addKey;
$('play').onclick = () => setPlaying(!playing);
$('restart').onclick = () => {
  setPlaying(false);
  queueSeek(0);
};
$('step-back').onclick = () => {
  setPlaying(false);
  queueSeek((engine?.frame || 0) - 1);
};
$('step-forward').onclick = () => {
  setPlaying(false);
  queueSeek((engine?.frame || 0) + 1);
};
$('loop').onclick = () => {
  loop = !loop;
  $('loop').classList.toggle('active', loop);
};
$('scrubber').oninput = (e) => {
  setPlaying(false);
  queueSeek(+e.target.value);
};
$('grid-toggle').onclick = () => {
  $('guides').hidden = !$('guides').hidden;
  $('grid-toggle').classList.toggle('active', !$('guides').hidden);
};
$('alpha-toggle').onclick = () => {
  if (!engine) return;
  engine.transparent = !engine.transparent;
  $('stage').classList.toggle('checker', engine.transparent);
  $('alpha-toggle').classList.toggle('active', engine.transparent);
};
$('camera-reset').onclick = () => {
  if (engine) {
    engine.yaw = engine.pitch = 0;
    engine.zoom = 1;
  }
};
$('fullscreen').onclick = () => {
  if (document.fullscreenElement) document.exitFullscreen();
  else $('stage').requestFullscreen();
};
$('preview').onpointerdown = (e) => {
  if (!engine) return;
  const start = { x: e.clientX, y: e.clientY, yaw: engine.yaw, pitch: engine.pitch };
  $('preview').setPointerCapture(e.pointerId);
  $('preview').onpointermove = (e) => {
    engine.yaw = start.yaw + (e.clientX - start.x) * 0.007;
    engine.pitch = Math.max(-0.9, Math.min(0.9, start.pitch + (e.clientY - start.y) * 0.006));
  };
  $('preview').onpointerup = () => {
    $('preview').onpointermove = null;
  };
};
$('preview').addEventListener(
  'wheel',
  (e) => {
    e.preventDefault();
    if (engine)
      engine.zoom = Math.max(0.7, Math.min(1.8, engine.zoom * (e.deltaY > 0 ? 1.06 : 0.94)));
  },
  { passive: false },
);
$('fit-graph').onclick = fitGraph;
$('zoom-in').onclick = () => zoomGraph(1.2);
$('zoom-out').onclick = () => zoomGraph(1 / 1.2);
new ResizeObserver(() => {
  if (tab === 'graph') fitGraph();
}).observe($('graph-view'));
$('rebuild').onclick = () => {
  activeSource = '';
  scheduleCompile(true);
};
$('project-name').onchange = () => {
  remember();
  graph.name = $('project-name').value.trim().slice(0, 80) || 'Untitled';
  $('effect-title').textContent = graph.name;
  persist();
};
function saveProject() {
  const blob = new Blob([JSON.stringify(graph, null, 2)], { type: 'application/json' }),
    url = URL.createObjectURL(blob),
    a = document.createElement('a');
  a.href = url;
  a.download = graph.name.replace(/[^\w -]/g, '').replaceAll(' ', '-') + '.v2cuda.json';
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 10000);
  toast('Editable graph and animation saved.');
}
$('save-project').onclick = saveProject;
$('open-project').onclick = () => $('project-file').click();
$('project-file').onchange = async (e) => {
  const file = e.target.files[0];
  if (!file) return;
  try {
    if (file.size > 1024 * 1024) throw Error('Project exceeds 1 MB.');
    const next = validateGraph(JSON.parse(await file.text()));
    remember();
    graph = next;
    selected = graph.nodes[0].id;
    selectedProp = Object.keys(graph.nodes[0].values)[0];
    refresh();
    fitGraph();
    scheduleCompile(true);
    toast('Project opened.');
  } catch (e) {
    toast(e.message);
  } finally {
    $('project-file').value = '';
  }
};
for (const b of document.querySelectorAll('[data-preset]'))
  b.onclick = () => {
    remember();
    graph = initialGraph();
    const n = (type) => graph.nodes.find((n) => n.type === type);
    if (b.dataset.preset === 'wispy') {
      graph.name = 'Wispy Mist';
      n('shape').values.radius = 0.28;
      n('emitter').values.density = 1.1;
      n('emitter').keys.density = [];
      n('noise').values.strength = 1.15;
      n('simulation').values.vorticity = 5.5;
      n('simulation').values.dissipation = 0.24;
      n('volume').values.absorption = 2.8;
      n('shading').values.light = 2;
    } else if (b.dataset.preset === 'fog') {
      graph.name = 'Low Fog';
      n('shape').values.radius = 1.1;
      n('shape').values.height = 0.55;
      n('emitter').values.lift = 0.12;
      n('simulation').values.buoyancy = 0.16;
      n('noise').values.strength = 0.8;
      n('simulation').values.vorticity = 1.2;
      n('emitter').values.density = 0.9;
      n('emitter').keys.density = [];
    }
    selected = 'simulation';
    selectedProp = 'vorticity';
    document
      .querySelectorAll('[data-preset]')
      .forEach((e) => e.classList.toggle('active', e === b));
    refresh();
    scheduleCompile(true);
  };
$('quality').onchange = async () => {
  if (!ready || busy || compileBusy || compilePending) {
    $('quality').value = engine?.n || 64;
    return;
  }
  busy = true;
  const target = engine.frame;
  try {
    await engine.runtime.idle();
    engine.n = +$('quality').value;
    engine.iterations = engine.n === 128 ? 32 : engine.n === 96 ? 24 : engine.n === 48 ? 12 : 16;
    engine.allocate();
    engine.reset();
    $('solver-status').textContent =
      `3D smoke · ${engine.iterations} pressure iterations · GPU resident`;
    await engine.seek(target, updateTime);
    engine.render();
    updateTime();
  } catch (e) {
    error(e);
  } finally {
    busy = false;
  }
};
document.addEventListener('keydown', (e) => {
  if (e.target.matches('input,select,textarea') || document.querySelector('dialog[open]')) return;
  if (e.code === 'Space') {
    e.preventDefault();
    setPlaying(!playing);
  }
  if (e.key === 'Delete') deleteNode();
  if (e.key.toLowerCase() === 'f') fitGraph();
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'z') {
    e.preventDefault();
    historyStep(e.shiftKey);
  }
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's') {
    e.preventDefault();
    saveProject();
  }
  if (e.key === 'Escape') {
    pendingSocket = null;
    drawGraph();
    $('graph-hint').textContent = 'Connect matching sockets · Drag canvas to pan';
  }
});
async function tick(now) {
  requestAnimationFrame(tick);
  if (!ready || busy || document.hidden || now - lastTick < 31) return;
  lastTick = now;
  busy = true;
  try {
    if (playing) {
      if (engine.frame >= 240) {
        if (loop) engine.reset();
        else setPlaying(false);
      }
      if (playing) engine.step();
    }
    engine.render();
    await engine.runtime.idle();
    updateTime();
    frameCount++;
    if (now - fpsStart > 1000) {
      $('fps').textContent = `${Math.round((frameCount * 1000) / (now - fpsStart))} fps`;
      fpsStart = now;
      frameCount = 0;
    }
  } catch (e) {
    setPlaying(false);
    error(e);
  } finally {
    busy = false;
  }
  if (seekTarget !== null) queueSeek(seekTarget);
}
refresh();
historyUI();
setPlaying(true);
requestAnimationFrame(fitGraph);
window.studio = {
  ready: false,
  get engine() {
    return engine;
  },
  get graph() {
    return graph;
  },
  get source() {
    return source;
  },
  get activeSource() {
    return activeSource;
  },
  get busy() {
    return busy || compileBusy || compilePending;
  },
  setPlaying,
  seek: async (frame) => {
    setPlaying(false);
    await queueSeek(frame);
  },
  setValue: (id, key, value) => {
    const n = graph.nodes.find((n) => n.id === id);
    if (!n) throw Error('Node missing');
    const field = TYPES[n.type].fields[key];
    if (!field || !Number.isFinite(value) || value < field[1] || value > field[2])
      throw Error('Invalid parameter');
    remember();
    n.values[key] = value;
    refresh();
    scheduleCompile(true);
  },
  load: (g) => {
    validateGraph(g);
    connectedNodes(g);
    remember();
    graph = structuredClone(g);
    refresh();
    scheduleCompile(true);
  },
  diagnostics: () => engine?.diagnostics(),
};
SmokeEngine.create($('preview'), error)
  .then((e) => {
    engine = e;
    $('loading-text').textContent = 'Compiling eight CUDA kernels…';
    scheduleCompile(true);
    requestAnimationFrame(tick);
  })
  .catch((e) => {
    error(e);
    $('loading-text').textContent = e.message;
    $('loading').querySelector('b').textContent = 'WebGPU could not start';
  });
