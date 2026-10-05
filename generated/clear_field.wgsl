// CUDA WebShader 0.1.1. Generated from kernel clear_field.
@group(0) @binding(0) var<storage, read_write> b_field: array<vec4<f32>>;
@group(0) @binding(1) var<storage, read_write> b_pressure: array<f32>;
struct CWParams {
  p_n: i32,
  cw_pad_4: u32,
  cw_pad_8: u32,
  cw_pad_12: u32,
}
@group(0) @binding(2) var<uniform> cw_params: CWParams;
const cw_block_size: vec3<u32> = vec3<u32>(64u, 1u, 1u);









































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
  b_field[v_i] = vec4<f32>(0.0f, 0.0f, 0.0f, 0.0f);
  b_pressure[v_i] = 0.0f;
}
