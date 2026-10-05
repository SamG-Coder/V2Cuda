// CUDA WebShader 0.1.1. Generated from kernel compute_curl.
@group(0) @binding(0) var<storage, read> b_field: array<vec4<f32>>;
@group(0) @binding(1) var<storage, read_write> b_curls: array<vec4<f32>>;
struct CWParams {
  p_n: i32,
  cw_pad_4: u32,
  cw_pad_8: u32,
  cw_pad_12: u32,
}
@group(0) @binding(2) var<uniform> cw_params: CWParams;
const cw_block_size: vec3<u32> = vec3<u32>(64u, 1u, 1u);





































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
  var v_l: vec4<f32> = b_field[f_at((v_x - 1i), v_y, v_z, cw_params.p_n, cw_thread, cw_block, cw_grid)];
  var v_r: vec4<f32> = b_field[f_at((v_x + 1i), v_y, v_z, cw_params.p_n, cw_thread, cw_block, cw_grid)];
  var v_b: vec4<f32> = b_field[f_at(v_x, (v_y - 1i), v_z, cw_params.p_n, cw_thread, cw_block, cw_grid)];
  var v_t: vec4<f32> = b_field[f_at(v_x, (v_y + 1i), v_z, cw_params.p_n, cw_thread, cw_block, cw_grid)];
  var v_f: vec4<f32> = b_field[f_at(v_x, v_y, (v_z - 1i), cw_params.p_n, cw_thread, cw_block, cw_grid)];
  var v_k: vec4<f32> = b_field[f_at(v_x, v_y, (v_z + 1i), cw_params.p_n, cw_thread, cw_block, cw_grid)];
  var v_cx: f32 = ((((v_t.z - v_b.z) - v_k.y) + v_f.y) * 0.5f);
  var v_cy: f32 = ((((v_k.x - v_f.x) - v_r.z) + v_l.z) * 0.5f);
  var v_cz: f32 = ((((v_r.y - v_l.y) - v_t.x) + v_b.x) * 0.5f);
  b_curls[v_i] = vec4<f32>(v_cx, v_cy, v_cz, sqrt((((v_cx * v_cx) + (v_cy * v_cy)) + (v_cz * v_cz))));
}
