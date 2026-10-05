// CUDA WebShader 0.1.1. Generated from kernel apply_forces.
@group(0) @binding(0) var<storage, read> b_field: array<vec4<f32>>;
@group(0) @binding(1) var<storage, read> b_curls: array<vec4<f32>>;
@group(0) @binding(2) var<storage, read_write> b_output: array<vec4<f32>>;
struct CWParams {
  p_n: i32,
  p_dt: f32,
  p_time: f32,
  cw_pad_12: u32,
}
@group(0) @binding(3) var<uniform> cw_params: CWParams;
const cw_block_size: vec3<u32> = vec3<u32>(64u, 1u, 1u);

fn cw_divide_f32(a: f32, b: f32) -> f32 { let q = a / b; if ((bitcast<u32>(q) & 0x7f800000u) == 0x7f800000u || (bitcast<u32>(q) & 0x7fffffffu) == 0u || (bitcast<u32>(b) & 0x7f800000u) == 0x7f800000u) { return q; } let residual = fma(-q, b, a); return q + residual / b; }








fn f_p_emitter_density(cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_time: f32 = cw_arg_time;
  if ((v_time <= 0.0f)) {
    return 2.4f;
  }
  if ((v_time <= 0.8f)) {
    return (2.4f + cw_divide_f32((0.0f * (v_time - 0.0f)), 0.8f));
  }
  if ((v_time <= 1.5f)) {
    return (2.4f + cw_divide_f32(((-2.4f) * (v_time - 0.8f)), 0.7f));
  }
  if ((v_time <= 3.8f)) {
    return (0.0f + cw_divide_f32((0.0f * (v_time - 1.5f)), 2.3f));
  }
  if ((v_time <= 4.2f)) {
    return (0.0f + cw_divide_f32((2.2f * (v_time - 3.8f)), 0.4f));
  }
  if ((v_time <= 5.0f)) {
    return (2.2f + cw_divide_f32((0.0f * (v_time - 4.2f)), 0.8f));
  }
  if ((v_time <= 5.8f)) {
    return (2.2f + cw_divide_f32(((-2.2f) * (v_time - 5.0f)), 0.8f));
  }
  if ((v_time <= 8.0f)) {
    return (0.0f + cw_divide_f32((0.0f * (v_time - 5.8f)), 2.2f));
  }
  return 0.0f;
}
fn f_p_emitter_lift(cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_time: f32 = cw_arg_time;
  return 0.65f;
}
fn f_p_simulation_vorticity(cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_time: f32 = cw_arg_time;
  return 3.0f;
}

fn f_p_simulation_buoyancy(cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_time: f32 = cw_arg_time;
  return 1.25f;
}










fn f_node_0_radius(cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_time: f32 = cw_arg_time;
  return 0.68f;
}
fn f_node_0_height(cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_time: f32 = cw_arg_time;
  return 1.6f;
}
fn f_node_0_offset(cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_time: f32 = cw_arg_time;
  return 0.0f;
}
fn f_node_0(cw_arg_x: f32, cw_arg_y: f32, cw_arg_z: f32, cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_x: f32 = cw_arg_x;
  var v_y: f32 = cw_arg_y;
  var v_z: f32 = cw_arg_z;
  var v_time: f32 = cw_arg_time;
  var v_ex: f32 = cw_divide_f32((v_x - f_node_0_offset(v_time, cw_thread, cw_block, cw_grid)), f_node_0_radius(v_time, cw_thread, cw_block, cw_grid));
  var v_ey: f32 = cw_divide_f32((v_y + 1.12f), (f_node_0_height(v_time, cw_thread, cw_block, cw_grid) * 0.32f));
  var v_ez: f32 = cw_divide_f32(v_z, f_node_0_radius(v_time, cw_thread, cw_block, cw_grid));
  return f_sat((((1.0f - (v_ex * v_ex)) - (v_ey * v_ey)) - (v_ez * v_ez)), cw_thread, cw_block, cw_grid);
}
fn f_node_2_scale(cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_time: f32 = cw_arg_time;
  return 2.7f;
}
fn f_node_2_strength(cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_time: f32 = cw_arg_time;
  return 0.58f;
}
fn f_node_2_speed(cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_time: f32 = cw_arg_time;
  return 0.4f;
}
fn f_node_2(cw_arg_x: f32, cw_arg_y: f32, cw_arg_z: f32, cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_x: f32 = cw_arg_x;
  var v_y: f32 = cw_arg_y;
  var v_z: f32 = cw_arg_z;
  var v_time: f32 = cw_arg_time;
  var v_s: f32 = f_node_2_scale(v_time, cw_thread, cw_block, cw_grid);
  var v_t: f32 = (v_time * f_node_2_speed(v_time, cw_thread, cw_block, cw_grid));
  return (vec3<f32>((f_noise3((v_x * v_s), ((v_y * v_s) - v_t), (v_z * v_s), cw_thread, cw_block, cw_grid) - 0.5f), ((f_noise3(((v_x * v_s) + 19.0f), ((v_y * v_s) - v_t), ((v_z * v_s) + 8.0f), cw_thread, cw_block, cw_grid) - 0.5f) * 0.3f), (f_noise3(((v_x * v_s) + 33.0f), ((v_y * v_s) - v_t), ((v_z * v_s) + 12.0f), cw_thread, cw_block, cw_grid) - 0.5f)) * vec3<f32>(f_node_2_strength(v_time, cw_thread, cw_block, cw_grid)));
}
fn f_emitter_shape(cw_arg_x: f32, cw_arg_y: f32, cw_arg_z: f32, cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_x: f32 = cw_arg_x;
  var v_y: f32 = cw_arg_y;
  var v_z: f32 = cw_arg_z;
  var v_time: f32 = cw_arg_time;
  return f_node_0(v_x, v_y, v_z, v_time, cw_thread, cw_block, cw_grid);
}
fn f_external_force(cw_arg_x: f32, cw_arg_y: f32, cw_arg_z: f32, cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_x: f32 = cw_arg_x;
  var v_y: f32 = cw_arg_y;
  var v_z: f32 = cw_arg_z;
  var v_time: f32 = cw_arg_time;
  return f_node_2(v_x, v_y, v_z, v_time, cw_thread, cw_block, cw_grid);
}
fn f_sat(cw_arg_x: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_x: f32 = cw_arg_x;
  return min(1.0f, max(0.0f, v_x));
}
fn f_mixf(cw_arg_a: f32, cw_arg_b: f32, cw_arg_t: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_a: f32 = cw_arg_a;
  var v_b: f32 = cw_arg_b;
  var v_t: f32 = cw_arg_t;
  return (v_a + ((v_b - v_a) * v_t));
}
fn f_at(cw_arg_x: i32, cw_arg_y: i32, cw_arg_z: i32, cw_arg_n: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> i32 {
  var v_x: i32 = cw_arg_x;
  var v_y: i32 = cw_arg_y;
  var v_z: i32 = cw_arg_z;
  var v_n: i32 = cw_arg_n;
  return ((((max(0i, min((v_n - 1i), v_z)) * v_n) + max(0i, min((v_n - 1i), v_y))) * v_n) + max(0i, min((v_n - 1i), v_x)));
}
fn f_hash3(cw_arg_x: i32, cw_arg_y: i32, cw_arg_z: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_x: i32 = cw_arg_x;
  var v_y: i32 = cw_arg_y;
  var v_z: i32 = cw_arg_z;
  var v_h: u32 = (((u32(v_x) * 374761393u) + (u32(v_y) * 668265263u)) + (u32(v_z) * 2246822519u));
  v_h = ((v_h ^ (v_h >> 13u)) * 1274126177u);
  return cw_divide_f32(f32(((v_h ^ (v_h >> 16u)) & 65535u)), 65535.0f);
}
fn f_noise3(cw_arg_x: f32, cw_arg_y: f32, cw_arg_z: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_x: f32 = cw_arg_x;
  var v_y: f32 = cw_arg_y;
  var v_z: f32 = cw_arg_z;
  var v_ix: i32 = i32(floor(v_x));
  var v_iy: i32 = i32(floor(v_y));
  var v_iz: i32 = i32(floor(v_z));
  var v_a: f32 = (v_x - floor(v_x));
  var v_b: f32 = (v_y - floor(v_y));
  var v_c: f32 = (v_z - floor(v_z));
  v_a = ((v_a * v_a) * (3.0f - (2.0f * v_a)));
  v_b = ((v_b * v_b) * (3.0f - (2.0f * v_b)));
  v_c = ((v_c * v_c) * (3.0f - (2.0f * v_c)));
  var v_q0: f32 = f_mixf(f_hash3(v_ix, v_iy, v_iz, cw_thread, cw_block, cw_grid), f_hash3((v_ix + 1i), v_iy, v_iz, cw_thread, cw_block, cw_grid), v_a, cw_thread, cw_block, cw_grid);
  var v_q1: f32 = f_mixf(f_hash3(v_ix, (v_iy + 1i), v_iz, cw_thread, cw_block, cw_grid), f_hash3((v_ix + 1i), (v_iy + 1i), v_iz, cw_thread, cw_block, cw_grid), v_a, cw_thread, cw_block, cw_grid);
  var v_q2: f32 = f_mixf(f_hash3(v_ix, v_iy, (v_iz + 1i), cw_thread, cw_block, cw_grid), f_hash3((v_ix + 1i), v_iy, (v_iz + 1i), cw_thread, cw_block, cw_grid), v_a, cw_thread, cw_block, cw_grid);
  var v_q3: f32 = f_mixf(f_hash3(v_ix, (v_iy + 1i), (v_iz + 1i), cw_thread, cw_block, cw_grid), f_hash3((v_ix + 1i), (v_iy + 1i), (v_iz + 1i), cw_thread, cw_block, cw_grid), v_a, cw_thread, cw_block, cw_grid);
  return f_mixf(f_mixf(v_q0, v_q1, v_b, cw_thread, cw_block, cw_grid), f_mixf(v_q2, v_q3, v_b, cw_thread, cw_block, cw_grid), v_c, cw_thread, cw_block, cw_grid);
}

@compute @workgroup_size(64, 1, 1)
fn main(
  @builtin(local_invocation_id) cw_thread: vec3<u32>,
  @builtin(workgroup_id) cw_block: vec3<u32>,
  @builtin(num_workgroups) cw_grid: vec3<u32>
) {
  var v_i: i32 = i32(((cw_block.x * cw_block_size.x) + cw_thread.x));
  if ((v_i >= ((cw_params.p_n * cw_params.p_n) * cw_params.p_n))) {
    return;
  }
  var v_x: i32 = (v_i % cw_params.p_n);
  var v_y: i32 = ((v_i / cw_params.p_n) % cw_params.p_n);
  var v_z: i32 = (v_i / (cw_params.p_n * cw_params.p_n));
  var v_v: vec4<f32> = b_field[v_i];
  var v_c: vec4<f32> = b_curls[v_i];
  var v_nx: f32 = (b_curls[f_at((v_x + 1i), v_y, v_z, cw_params.p_n, cw_thread, cw_block, cw_grid)].w - b_curls[f_at((v_x - 1i), v_y, v_z, cw_params.p_n, cw_thread, cw_block, cw_grid)].w);
  var v_ny: f32 = (b_curls[f_at(v_x, (v_y + 1i), v_z, cw_params.p_n, cw_thread, cw_block, cw_grid)].w - b_curls[f_at(v_x, (v_y - 1i), v_z, cw_params.p_n, cw_thread, cw_block, cw_grid)].w);
  var v_nz: f32 = (b_curls[f_at(v_x, v_y, (v_z + 1i), cw_params.p_n, cw_thread, cw_block, cw_grid)].w - b_curls[f_at(v_x, v_y, (v_z - 1i), cw_params.p_n, cw_thread, cw_block, cw_grid)].w);
  var v_inv: f32 = cw_divide_f32(1.0f, max(0.0001f, sqrt((((v_nx * v_nx) + (v_ny * v_ny)) + (v_nz * v_nz)))));
  v_nx = (v_nx * v_inv);
  v_ny = (v_ny * v_inv);
  v_nz = (v_nz * v_inv);
  var v_vort: f32 = (f_p_simulation_vorticity(cw_params.p_time, cw_thread, cw_block, cw_grid) * cw_params.p_dt);
  v_v.x = (v_v.x + (((v_ny * v_c.z) - (v_nz * v_c.y)) * v_vort));
  v_v.y = (v_v.y + (((v_nz * v_c.x) - (v_nx * v_c.z)) * v_vort));
  v_v.z = (v_v.z + (((v_nx * v_c.y) - (v_ny * v_c.x)) * v_vort));
  var v_wx: f32 = ((cw_divide_f32(f32(v_x), f32(cw_params.p_n)) - 0.5f) * 4.0f);
  var v_wy: f32 = ((cw_divide_f32(f32(v_y), f32(cw_params.p_n)) - 0.5f) * 4.0f);
  var v_wz: f32 = ((cw_divide_f32(f32(v_z), f32(cw_params.p_n)) - 0.5f) * 4.0f);
  var v_force: vec3<f32> = f_external_force(v_wx, v_wy, v_wz, cw_params.p_time, cw_thread, cw_block, cw_grid);
  var v_forceScale: f32 = cw_divide_f32((((cw_params.p_dt * 45.0f) * f_sat(v_v.w, cw_thread, cw_block, cw_grid)) * f32(cw_params.p_n)), 64.0f);
  v_v.x = (v_v.x + (v_force.x * v_forceScale));
  v_v.y = (v_v.y + (v_force.y * v_forceScale));
  v_v.z = (v_v.z + (v_force.z * v_forceScale));
  v_v.y = (v_v.y + cw_divide_f32(((((cw_params.p_dt * f_p_simulation_buoyancy(cw_params.p_time, cw_thread, cw_block, cw_grid)) * v_v.w) * 3.0f) * f32(cw_params.p_n)), 64.0f));
  var v_shape: f32 = f_emitter_shape(v_wx, v_wy, v_wz, cw_params.p_time, cw_thread, cw_block, cw_grid);
  v_shape = (v_shape * f_sat(((f_noise3(((v_wx * 6.0f) + 10.0f), ((v_wy * 6.0f) - cw_params.p_time), (v_wz * 6.0f), cw_thread, cw_block, cw_grid) - 0.22f) * 3.5f), cw_thread, cw_block, cw_grid));
  var v_puff: f32 = (0.6f + (0.4f * f_noise3((v_wx * 7.0f), ((v_wy * 7.0f) - (cw_params.p_time * 1.2f)), (v_wz * 7.0f), cw_thread, cw_block, cw_grid)));
  var v_emit: f32 = ((((v_shape * v_puff) * f_p_emitter_density(cw_params.p_time, cw_thread, cw_block, cw_grid)) * cw_params.p_dt) * 4.0f);
  v_v.w = min(4.0f, (v_v.w + v_emit));
  v_v.y = (v_v.y + cw_divide_f32(((((v_shape * cw_params.p_dt) * f_p_emitter_lift(cw_params.p_time, cw_thread, cw_block, cw_grid)) * 22.0f) * f32(cw_params.p_n)), 64.0f));
  if (((v_x < 1i) || (v_x > (cw_params.p_n - 2i)))) {
    v_v.x = 0.0f;
  }
  if (((v_y < 1i) || (v_y > (cw_params.p_n - 2i)))) {
    v_v.y = 0.0f;
  }
  if (((v_z < 1i) || (v_z > (cw_params.p_n - 2i)))) {
    v_v.z = 0.0f;
  }
  b_output[v_i] = v_v;
}
