// CUDA WebShader 0.1.1. Generated from kernel pressure_solve.
@group(0) @binding(0) var<storage, read> b_pressure: array<f32>;
@group(0) @binding(1) var<storage, read> b_div: array<f32>;
@group(0) @binding(2) var<storage, read_write> b_output: array<f32>;
struct CWParams {
  p_n: i32,
  cw_pad_4: u32,
  cw_pad_8: u32,
  cw_pad_12: u32,
}
@group(0) @binding(3) var<uniform> cw_params: CWParams;
const cw_block_size: vec3<u32> = vec3<u32>(64u, 1u, 1u);

fn cw_divide_f32(a: f32, b: f32) -> f32 { let q = a / b; if ((bitcast<u32>(q) & 0x7f800000u) == 0x7f800000u || (bitcast<u32>(q) & 0x7fffffffu) == 0u || (bitcast<u32>(b) & 0x7f800000u) == 0x7f800000u) { return q; } let residual = fma(-q, b, a); return q + residual / b; }



































fn f_at(cw_arg_x: i32, cw_arg_y: i32, cw_arg_z: i32, cw_arg_n: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> i32 {
  var v_x: i32 = cw_arg_x;
  var v_y: i32 = cw_arg_y;
  var v_z: i32 = cw_arg_z;
  var v_n: i32 = cw_arg_n;
  return ((((max(0i, min((v_n - 1i), v_z)) * v_n) + max(0i, min((v_n - 1i), v_y))) * v_n) + max(0i, min((v_n - 1i), v_x)));
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
  b_output[v_i] = cw_divide_f32(((((((b_pressure[f_at((v_x - 1i), v_y, v_z, cw_params.p_n, cw_thread, cw_block, cw_grid)] + b_pressure[f_at((v_x + 1i), v_y, v_z, cw_params.p_n, cw_thread, cw_block, cw_grid)]) + b_pressure[f_at(v_x, (v_y - 1i), v_z, cw_params.p_n, cw_thread, cw_block, cw_grid)]) + b_pressure[f_at(v_x, (v_y + 1i), v_z, cw_params.p_n, cw_thread, cw_block, cw_grid)]) + b_pressure[f_at(v_x, v_y, (v_z - 1i), cw_params.p_n, cw_thread, cw_block, cw_grid)]) + b_pressure[f_at(v_x, v_y, (v_z + 1i), cw_params.p_n, cw_thread, cw_block, cw_grid)]) - b_div[v_i]), 6.0f);
}
