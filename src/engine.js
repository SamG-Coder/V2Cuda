import { GpuRuntime } from '../vendor/cuda-webshader/src/runtime/runtime.js';
import { CompilerClient } from '../vendor/cuda-webshader/src/compiler/client.js';
import { ENTRIES } from './generator.js';
export class SmokeEngine {
  static async create(canvas, onError) {
    const e = new SmokeEngine();
    e.canvas = canvas;
    e.errors = [];
    e.runtime = await GpuRuntime.create({
      backend: 'webgpu',
      onError: (error) => {
        e.errors.push(String(error));
        onError(error);
      },
    });
    e.device = e.runtime.device;
    e.device.lost.then((info) =>
      onError(Error(`GPU device lost: ${info.message}. Reload to reconnect.`)),
    );
    e.compiler = new CompilerClient();
    e.format = navigator.gpu.getPreferredCanvasFormat();
    e.ctx = canvas.getContext('webgpu');
    e.ctx.configure({
      device: e.device,
      format: e.format,
      alphaMode: 'premultiplied',
      usage: GPUTextureUsage.COPY_DST | GPUTextureUsage.RENDER_ATTACHMENT,
    });
    e.yaw = 0;
    e.pitch = 0;
    e.zoom = 1;
    e.transparent = false;
    e.frame = 0;
    e.generation = 0;
    e.cache = new Map();
    e.kernels = {};
    e.bindings = new Map();
    e.n = 64;
    e.iterations = 16;
    e.allocate();
    return e;
  }
  allocate() {
    for (const b of [
      this.a,
      this.b,
      this.curl,
      this.div,
      this.p0,
      this.p1,
      this.pixels,
      ...this.cache.values(),
    ].filter(Boolean))
      this.runtime.destroyBuffer(b);
    this.cache.clear();
    const n = this.n ** 3;
    this.a = this.runtime.createBuffer(n * 16);
    this.b = this.runtime.createBuffer(n * 16);
    this.curl = this.runtime.createBuffer(n * 16);
    this.div = this.runtime.createBuffer(n * 4);
    this.p0 = this.runtime.createBuffer(n * 4);
    this.p1 = this.runtime.createBuffer(n * 4);
    this.pixels = this.runtime.createBuffer(this.canvas.width * this.canvas.height * 4);
    this.bindings.clear();
    this.frame = 0;
  }
  async compile(source) {
    const generation = ++this.generation,
      start = performance.now(),
      artifacts = {};
    for (const entry of ENTRIES) {
      const result = await this.compiler.compile(source, {
        entry,
        workgroupSize: entry === 'mist_render' ? [8, 8, 1] : [64, 1, 1],
      });
      if (generation !== this.generation) return null;
      artifacts[entry] = result.artifact;
    }
    const kernels = {};
    for (const entry of ENTRIES) {
      kernels[entry] = await this.runtime.kernel(artifacts[entry]);
      if (generation !== this.generation) return null;
    }
    return { kernels, artifacts, ms: performance.now() - start, generation };
  }
  install(result, reset = true) {
    this.kernels = result.kernels;
    this.artifacts = result.artifacts;
    this.bindings.clear();
    this.revision = (this.revision || 0) + 1;
    while (this.runtime.pipelineCache.size > 80)
      this.runtime.pipelineCache.delete(this.runtime.pipelineCache.keys().next().value);
    if (reset) this.reset();
  }
  dispatch(batch, name, buffers, scalars, grid = [Math.ceil(this.n ** 3 / 64), 1, 1]) {
    const key =
      name +
      Object.values(buffers)
        .map((b) => ':' + b.id)
        .join('');
    let binding = this.bindings.get(key);
    if (binding) binding.setScalars(scalars);
    else {
      binding = this.kernels[name].bind(buffers, scalars);
      this.bindings.set(key, binding);
    }
    batch.dispatch(binding, grid);
  }
  reset() {
    for (const b of this.cache.values()) this.runtime.destroyBuffer(b);
    this.cache.clear();
    this.frame = 0;
    const batch = this.runtime.batch();
    this.dispatch(batch, 'clear_field', { field: this.a, pressure: this.p0 }, { n: this.n });
    batch.submit();
  }
  step() {
    const batch = this.runtime.batch(),
      n = this.n,
      dt = 1 / 30,
      time = this.frame / 30;
    this.dispatch(batch, 'advect', { field: this.a, output: this.b }, { n, dt, time });
    this.dispatch(batch, 'compute_curl', { field: this.b, curls: this.curl }, { n });
    this.dispatch(
      batch,
      'apply_forces',
      { field: this.b, curls: this.curl, output: this.a },
      { n, dt, time },
    );
    this.dispatch(batch, 'divergence', { field: this.a, div: this.div, pressure: this.p0 }, { n });
    let p = this.p0,
      q = this.p1;
    for (let i = 0; i < this.iterations; i++) {
      this.dispatch(batch, 'pressure_solve', { pressure: p, div: this.div, output: q }, { n });
      [p, q] = [q, p];
    }
    this.dispatch(batch, 'project', { field: this.a, pressure: p, output: this.b }, { n });
    batch.submit();
    [this.a, this.b] = [this.b, this.a];
    this.frame++;
    if (this.frame % 30 === 0 && !this.cache.has(this.frame)) {
      const snapshot = this.runtime.createBuffer(n ** 3 * 16);
      this.runtime.batch().copy(this.a, snapshot).submit();
      this.cache.set(this.frame, snapshot);
    }
  }
  async seek(target, progress = () => {}) {
    target = Math.max(0, Math.min(240, Math.round(target)));
    if (target < this.frame) {
      const cached = [...this.cache.keys()].filter((k) => k <= target).sort((a, b) => b - a)[0];
      if (cached !== undefined) {
        this.runtime.batch().copy(this.cache.get(cached), this.a).submit();
        this.frame = cached;
      } else {
        const b = this.runtime.batch();
        this.dispatch(b, 'clear_field', { field: this.a, pressure: this.p0 }, { n: this.n });
        b.submit();
        this.frame = 0;
      }
    }
    while (this.frame < target) {
      for (let i = 0; i < 6 && this.frame < target; i++) this.step();
      await this.runtime.idle();
      progress(this.frame);
      await new Promise((r) => setTimeout(r, 0));
    }
  }
  render() {
    const batch = this.runtime.batch();
    this.dispatch(
      batch,
      'mist_render',
      { field: this.a, pixels: this.pixels },
      {
        n: this.n,
        width: this.canvas.width,
        height: this.canvas.height,
        time: this.frame / 30,
        yawOffset: this.yaw,
        pitchOffset: this.pitch,
        zoomScale: this.zoom,
        bgra: this.format.startsWith('bgra') ? 1 : 0,
        transparent: this.transparent ? 1 : 0,
      },
      [Math.ceil(this.canvas.width / 8), Math.ceil(this.canvas.height / 8), 1],
    );
    batch.submit();
    const encoder = this.device.createCommandEncoder();
    encoder.copyBufferToTexture(
      { buffer: this.pixels.gpuBuffer, bytesPerRow: this.canvas.width * 4 },
      { texture: this.ctx.getCurrentTexture() },
      [this.canvas.width, this.canvas.height],
    );
    this.device.queue.submit([encoder.finish()]);
  }
  async field() {
    return this.runtime.read(this.a, Float32Array);
  }
  async pixelsRGBA() {
    const result = new Uint8Array((await this.runtime.read(this.pixels, Uint32Array)).buffer);
    if (this.format.startsWith('bgra'))
      for (let i = 0; i < result.length; i += 4)
        [result[i], result[i + 2]] = [result[i + 2], result[i]];
    return result;
  }
  diagnostics() {
    return {
      frame: this.frame,
      grid: this.n,
      revision: this.revision,
      kernels: Object.keys(this.kernels),
      cacheFrames: [...this.cache.keys()],
      errors: this.errors,
      adapter: this.runtime.adapter?.info || null,
    };
  }
}
