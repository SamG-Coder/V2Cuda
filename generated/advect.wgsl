// CUDA WebShader 0.1.1. Generated from kernel advect.
@group(0) @binding(0) var<storage, read> b_field: array<vec4<f32>>;
@group(0) @binding(1) var<storage, read_write> b_output: array<vec4<f32>>;
struct CWParams {
  p_n: i32,
  p_dt: f32,
  p_time: f32,
  cw_pad_12: u32,
}
@group(0) @binding(2) var<uniform> cw_params: CWParams;
const cw_block_size: vec3<u32> = vec3<u32>(64u, 1u, 1u);













fn f_p_simulation_dissipation(cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_time: f32 = cw_arg_time;
  return 0.12f;
}























fn f_at(cw_arg_x: i32, cw_arg_y: i32, cw_arg_z: i32, cw_arg_n: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> i32 {
  var v_x: i32 = cw_arg_x;
  var v_y: i32 = cw_arg_y;
  var v_z: i32 = cw_arg_z;
  var v_n: i32 = cw_arg_n;
  return ((((max(0i, min((v_n - 1i), v_z)) * v_n) + max(0i, min((v_n - 1i), v_y))) * v_n) + max(0i, min((v_n - 1i), v_x)));
}


fn f_cw_buffer_helper_0(cw_buffer_arg_0: i32, cw_arg_x: f32, cw_arg_y: f32, cw_arg_z: f32, cw_arg_n: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec4<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_x: f32 = cw_arg_x;
  var v_y: f32 = cw_arg_y;
  var v_z: f32 = cw_arg_z;
  var v_n: i32 = cw_arg_n;
  v_x = min((f32(v_n) - 1.001f), max(0.0f, v_x));
  v_y = min((f32(v_n) - 1.001f), max(0.0f, v_y));
  v_z = min((f32(v_n) - 1.001f), max(0.0f, v_z));
  var v_ix: i32 = i32(floor(v_x));
  var v_iy: i32 = i32(floor(v_y));
  var v_iz: i32 = i32(floor(v_z));
  var v_a: f32 = (v_x - f32(v_ix));
  var v_b: f32 = (v_y - f32(v_iy));
  var v_c: f32 = (v_z - f32(v_iz));
  var v_q0: vec4<f32> = ((b_field[(cw_buffer_offset_0 + f_at(v_ix, v_iy, v_iz, v_n, cw_thread, cw_block, cw_grid))] * vec4<f32>((1.0f - v_a))) + (b_field[(cw_buffer_offset_0 + f_at((v_ix + 1i), v_iy, v_iz, v_n, cw_thread, cw_block, cw_grid))] * vec4<f32>(v_a)));
  var v_q1: vec4<f32> = ((b_field[(cw_buffer_offset_0 + f_at(v_ix, (v_iy + 1i), v_iz, v_n, cw_thread, cw_block, cw_grid))] * vec4<f32>((1.0f - v_a))) + (b_field[(cw_buffer_offset_0 + f_at((v_ix + 1i), (v_iy + 1i), v_iz, v_n, cw_thread, cw_block, cw_grid))] * vec4<f32>(v_a)));
  var v_q2: vec4<f32> = ((b_field[(cw_buffer_offset_0 + f_at(v_ix, v_iy, (v_iz + 1i), v_n, cw_thread, cw_block, cw_grid))] * vec4<f32>((1.0f - v_a))) + (b_field[(cw_buffer_offset_0 + f_at((v_ix + 1i), v_iy, (v_iz + 1i), v_n, cw_thread, cw_block, cw_grid))] * vec4<f32>(v_a)));
  var v_q3: vec4<f32> = ((b_field[(cw_buffer_offset_0 + f_at(v_ix, (v_iy + 1i), (v_iz + 1i), v_n, cw_thread, cw_block, cw_grid))] * vec4<f32>((1.0f - v_a))) + (b_field[(cw_buffer_offset_0 + f_at((v_ix + 1i), (v_iy + 1i), (v_iz + 1i), v_n, cw_thread, cw_block, cw_grid))] * vec4<f32>(v_a)));
  return ((((v_q0 * vec4<f32>((1.0f - v_b))) + (v_q1 * vec4<f32>(v_b))) * vec4<f32>((1.0f - v_c))) + (((v_q2 * vec4<f32>((1.0f - v_b))) + (v_q3 * vec4<f32>(v_b))) * vec4<f32>(v_c)));
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
  var v_back: vec4<f32> = f_cw_buffer_helper_0(0i, (f32(v_x) - (v_v.x * cw_params.p_dt)), (f32(v_y) - (v_v.y * cw_params.p_dt)), (f32(v_z) - (v_v.z * cw_params.p_dt)), cw_params.p_n, cw_thread, cw_block, cw_grid);
  v_back.x = (v_back.x * 0.998f);
  v_back.y = (v_back.y * 0.998f);
  v_back.z = (v_back.z * 0.998f);
  v_back.w = (v_back.w * exp(((-cw_params.p_dt) * f_p_simulation_dissipation(cw_params.p_time, cw_thread, cw_block, cw_grid))));
  if (((((((v_x < 2i) || (v_x > (cw_params.p_n - 3i))) || (v_y < 2i)) || (v_y > (cw_params.p_n - 3i))) || (v_z < 2i)) || (v_z > (cw_params.p_n - 3i)))) {
    v_back.w = (v_back.w * 0.85f);
  }
  b_output[v_i] = v_back;
}
