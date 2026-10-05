// CUDA WebShader 0.1.1. Generated from kernel mist_render.
@group(0) @binding(0) var<storage, read> b_field: array<vec4<f32>>;
@group(0) @binding(1) var<storage, read_write> b_pixels: array<u32>;
struct CWParams {
  p_n: i32,
  p_width: i32,
  p_height: i32,
  p_time: f32,
  p_yawOffset: f32,
  p_pitchOffset: f32,
  p_zoomScale: f32,
  p_bgra: i32,
  p_transparent: i32,
  cw_pad_36: u32,
  cw_pad_40: u32,
  cw_pad_44: u32,
}
@group(0) @binding(2) var<uniform> cw_params: CWParams;
const cw_block_size: vec3<u32> = vec3<u32>(8u, 8u, 1u);

fn cw_divide_f32(a: f32, b: f32) -> f32 { let q = a / b; if ((bitcast<u32>(q) & 0x7f800000u) == 0x7f800000u || (bitcast<u32>(q) & 0x7fffffffu) == 0u || (bitcast<u32>(b) & 0x7f800000u) == 0x7f800000u) { return q; } let residual = fma(-q, b, a); return q + residual / b; }

alias cw_f64 = vec2<u32>;
fn cw_d_shl(a: vec2<u32>, n: u32) -> vec2<u32> {
  if(n == 0u) { return a; }
  if(n >= 64u) { return vec2<u32>(0u); }
  if(n >= 32u) { return vec2<u32>(0u, a.x << (n - 32u)); }
  return vec2<u32>(a.x << n, (a.y << n) | (a.x >> (32u - n)));
}
fn cw_d_shr(a: vec2<u32>, n: u32) -> vec2<u32> {
  if(n == 0u) { return a; }
  if(n >= 64u) { return vec2<u32>(0u); }
  if(n >= 32u) { return vec2<u32>(a.y >> (n - 32u), 0u); }
  return vec2<u32>((a.x >> n) | (a.y << (32u - n)), a.y >> n);
}
fn cw_d_jam(a: vec2<u32>, n: u32) -> vec2<u32> {
  let shifted = cw_d_shr(a, n);
  return shifted | vec2<u32>(select(0u, 1u, any(cw_d_shl(shifted, n) != a)), 0u);
}
fn cw_d_uadd(a: vec2<u32>, b: vec2<u32>) -> vec2<u32> {
  let low = a.x + b.x;
  return vec2<u32>(low, a.y + b.y + select(0u, 1u, low < a.x));
}
fn cw_d_usub(a: vec2<u32>, b: vec2<u32>) -> vec2<u32> {
  return vec2<u32>(a.x - b.x, a.y - b.y - select(0u, 1u, a.x < b.x));
}
fn cw_d_uless(a: vec2<u32>, b: vec2<u32>) -> bool {
  return a.y < b.y || (a.y == b.y && a.x < b.x);
}
fn cw_d_nan(a: cw_f64) -> bool { return (a.y & 2147483647u) > 2146435072u || ((a.y & 2147483647u) == 2146435072u && a.x != 0u); }
fn cw_d_inf(a: cw_f64) -> bool { return (a.y & 2147483647u) == 2146435072u && a.x == 0u; }
fn cw_d_zero(a: cw_f64) -> bool { return (a.y & 2147483647u) == 0u && a.x == 0u; }

struct CWDoubleParts { significand: vec2<u32>, exponent: i32, }
fn cw_d_parts(a: cw_f64) -> CWDoubleParts {
  let raw = (a.y >> 20u) & 2047u;
  var s = vec2<u32>(a.x, a.y & 1048575u);
  var e = i32(raw) - 1023i;
  if(raw != 0u) { s.y |= 1048576u; }
  else {
    e = -1022i;
    if(any(s != vec2<u32>(0u))) {
      loop { if((s.y & 1048576u) != 0u) { break; } s = cw_d_shl(s, 1u); e--; }
    }
  }
  return CWDoubleParts(s,e);
}
// Input has its leading bit at bit 55 and three guard/round/sticky bits.
fn cw_d_pack(sign: u32, exponent: i32, value: vec2<u32>) -> cw_f64 {
  var e = exponent; var v = value;
  if(e < -1022i) { v = cw_d_jam(v, u32(-1022i-e)); e = -1022i; }
  let tail = v.x & 7u;
  var s = cw_d_shr(v, 3u);
  if(tail > 4u || (tail == 4u && (s.x & 1u) != 0u)) { s = cw_d_uadd(s,vec2<u32>(1u,0u)); }
  if((s.y & 2097152u) != 0u) { s = cw_d_shr(s,1u); e++; }
  if(e > 1023i) { return vec2<u32>(0u,sign | 2146435072u); }
  let field = select(0u, u32(e+1023i), (s.y & 1048576u) != 0u);
  return vec2<u32>(s.x, sign | (field << 20u) | (s.y & 1048575u));
}
fn cw_d_from_f32(a: f32) -> cw_f64 {
  let bits = bitcast<u32>(a); let sign = bits & 2147483648u;
  let field = (bits >> 23u) & 255u; var mantissa = bits & 8388607u;
  if(field == 255u) { return vec2<u32>(0u,sign | 2146435072u | select(0u,524288u,mantissa != 0u)); }
  if(field == 0u && mantissa == 0u) { return vec2<u32>(0u,sign); }
  var e = i32(field)-127i;
  if(field == 0u) { e = -126i; loop { if((mantissa & 8388608u) != 0u) { break; } mantissa <<= 1u; e--; } }
  let s = cw_d_shl(vec2<u32>(mantissa & 8388607u,0u),29u);
  return vec2<u32>(s.x,sign | (u32(e+1023i) << 20u) | s.y);
}
fn cw_d_from_u32(a: u32) -> cw_f64 {
  if(a == 0u) { return vec2<u32>(0u); }
  let e = 31u-countLeadingZeros(a); let s = cw_d_shl(vec2<u32>(a,0u),52u-e);
  return vec2<u32>(s.x,((e+1023u) << 20u) | (s.y & 1048575u));
}

fn cw_d_to_f32(a: cw_f64) -> f32 {
  let sign = a.y & 2147483648u;
  if(cw_d_nan(a)) { return bitcast<f32>(sign | 2143289344u); }
  if(cw_d_inf(a)) { return bitcast<f32>(sign | 2139095040u); }
  if(cw_d_zero(a)) { return bitcast<f32>(sign); }
  let p = cw_d_parts(a); var e = p.exponent;
  let shift = 29u + u32(max(-126i-e,0i));
  // Keep three rounding bits while reducing the 53-bit significand to 24 bits.
  let v = cw_d_jam(p.significand,shift-3u); let tail = v.x & 7u;
  var s = cw_d_shr(v,3u).x;
  if(tail > 4u || (tail == 4u && (s & 1u) != 0u)) { s++; }
  e = max(e,-126i);
  if(s >= 16777216u) { s >>= 1u; e++; }
  if(e > 127i) { return bitcast<f32>(sign | 2139095040u); }
  let field = select(0u,u32(e+127i),s >= 8388608u);
  return bitcast<f32>(sign | (field << 23u) | (s & 8388607u));
}






fn cw_d_mul(a: cw_f64,b: cw_f64) -> cw_f64 {
  let sign = (a.y ^ b.y) & 2147483648u;
  if(cw_d_nan(a) || cw_d_nan(b) || (cw_d_inf(a) && cw_d_zero(b)) || (cw_d_inf(b) && cw_d_zero(a))) { return vec2<u32>(0u,2146959360u); }
  if(cw_d_inf(a) || cw_d_inf(b)) { return vec2<u32>(0u,sign | 2146435072u); }
  if(cw_d_zero(a) || cw_d_zero(b)) { return vec2<u32>(0u,sign); }
  let pa = cw_d_parts(a); let pb = cw_d_parts(b);
  if(all(pa.significand == vec2<u32>(0u,1048576u))) { return cw_d_pack(sign,pa.exponent+pb.exponent,cw_d_shl(pb.significand,3u)); }
  if(all(pb.significand == vec2<u32>(0u,1048576u))) { return cw_d_pack(sign,pa.exponent+pb.exponent,cw_d_shl(pa.significand,3u)); }
  var product = vec4<u32>(0u); var term = vec4<u32>(pa.significand,0u,0u); var multiplier = pb.significand;
  for(var i = 0u; i < 53u; i++) {
    if((multiplier.x & 1u) != 0u) {
      var carry = 0u;
      for(var j = 0u; j < 4u; j++) {
        let p = product[j]; let s = p + term[j]; let t = s + carry;
        carry = select(0u,1u,s < p || t < s); product[j] = t;
      }
    }
    term = vec4<u32>(term.x << 1u,(term.y << 1u) | (term.x >> 31u),(term.z << 1u) | (term.y >> 31u),(term.w << 1u) | (term.z >> 31u));
    multiplier = cw_d_shr(multiplier,1u);
  }
  let extra = select(0u,1u,(product.w & 512u) != 0u);
  for(var i = 0u; i < 49u+extra; i++) {
    product = vec4<u32>((product.x >> 1u) | (product.y << 31u) | (product.x & 1u),(product.y >> 1u) | (product.z << 31u),(product.z >> 1u) | (product.w << 31u),product.w >> 1u);
  }
  return cw_d_pack(sign,pa.exponent+pb.exponent+i32(extra),product.xy);
}
fn cw_d_div(a: cw_f64,b: cw_f64) -> cw_f64 {
  let sign = (a.y ^ b.y) & 2147483648u;
  if(cw_d_nan(a) || cw_d_nan(b) || (cw_d_inf(a) && cw_d_inf(b)) || (cw_d_zero(a) && cw_d_zero(b))) { return vec2<u32>(0u,2146959360u); }
  if(cw_d_inf(a) || cw_d_zero(b)) { return vec2<u32>(0u,sign | 2146435072u); }
  if(cw_d_zero(a) || cw_d_inf(b)) { return vec2<u32>(0u,sign); }
  let pa = cw_d_parts(a); let pb = cw_d_parts(b); var e = pa.exponent-pb.exponent;
  var remainder = pa.significand; var q = vec2<u32>(0u);
  if(cw_d_uless(remainder,pb.significand)) { remainder = cw_d_shl(remainder,1u); e--; }
  for(var i = 0u; i < 56u; i++) {
    q = cw_d_shl(q,1u);
    if(!cw_d_uless(remainder,pb.significand)) { remainder = cw_d_usub(remainder,pb.significand); q.x |= 1u; }
    if(i < 55u) { remainder = cw_d_shl(remainder,1u); }
  }
  if(any(remainder != vec2<u32>(0u))) { q.x |= 1u; }
  return cw_d_pack(sign,e,q);
}

// Restoring square root: 56 root bits include guard/round/sticky for binary64.

















fn f_p_volume_absorption(cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_time: f32 = cw_arg_time;
  return 2.4f;
}
fn f_p_volume_detail(cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_time: f32 = cw_arg_time;
  return 0.75f;
}
fn f_p_volume_contrast(cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_time: f32 = cw_arg_time;
  return 1.05f;
}
fn f_p_shading_warmth(cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_time: f32 = cw_arg_time;
  return 0.24f;
}
fn f_p_shading_light(cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_time: f32 = cw_arg_time;
  return 1.5f;
}
fn f_p_shading_ambient(cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_time: f32 = cw_arg_time;
  return 0.24f;
}
fn f_p_camera_distance(cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_time: f32 = cw_arg_time;
  return 3.5f;
}
fn f_p_camera_yaw(cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_time: f32 = cw_arg_time;
  return 0.0f;
}
fn f_p_camera_pitch(cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_time: f32 = cw_arg_time;
  return 0.06f;
}
fn f_p_render_exposure(cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_time: f32 = cw_arg_time;
  return 1.7f;
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
fn f_cw_buffer_helper_0(cw_buffer_arg_0: i32, cw_arg_x: f32, cw_arg_y: f32, cw_arg_z: f32, cw_arg_n: i32, cw_arg_time: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_x: f32 = cw_arg_x;
  var v_y: f32 = cw_arg_y;
  var v_z: f32 = cw_arg_z;
  var v_n: i32 = cw_arg_n;
  var v_time: f32 = cw_arg_time;
  if ((((abs(v_x) > 1.96f) || (abs(v_y) > 1.96f)) || (abs(v_z) > 1.96f))) {
    return 0.0f;
  }
  var v_detail: f32 = f_p_volume_detail(v_time, cw_thread, cw_block, cw_grid);
  var v_warp: f32 = (f_noise3((v_x * 4.0f), ((v_y * 4.0f) - (v_time * 0.5f)), (v_z * 4.0f), cw_thread, cw_block, cw_grid) - 0.5f);
  v_x = (v_x + ((v_warp * v_detail) * 0.18f));
  v_z = (v_z + ((v_warp * v_detail) * 0.13f));
  var v_d: f32 = f_cw_buffer_helper_1((cw_buffer_offset_0 + 0i), (((v_x * 0.25f) + 0.5f) * f32(v_n)), (((v_y * 0.25f) + 0.5f) * f32(v_n)), (((v_z * 0.25f) + 0.5f) * f32(v_n)), v_n, cw_thread, cw_block, cw_grid).w;
  if ((v_d < 0.003f)) {
    return 0.0f;
  }
  var v_ny: f32 = (v_y - (v_time * 0.26f));
  var v_coarse: f32 = f_noise3((v_x * 5.5f), (v_ny * 5.5f), (v_z * 5.5f), cw_thread, cw_block, cw_grid);
  var v_fine: f32 = ((f_noise3(((v_x * 13.0f) + 7.0f), (v_ny * 13.0f), (v_z * 13.0f), cw_thread, cw_block, cw_grid) * 0.5f) + (f_noise3((v_x * 27.0f), (v_ny * 27.0f), (v_z * 27.0f), cw_thread, cw_block, cw_grid) * 0.22f));
  v_d = max(0.0f, (v_d - (((v_coarse + v_fine) * v_detail) * 1.15f)));
  v_d = (v_d * (1.0f + ((v_detail * (v_coarse - 0.5f)) * 0.8f)));
  return cw_pow_f32(v_d, f_p_volume_contrast(v_time, cw_thread, cw_block, cw_grid));
}
fn f_cw_buffer_helper_1(cw_buffer_arg_0: i32, cw_arg_x: f32, cw_arg_y: f32, cw_arg_z: f32, cw_arg_n: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec4<f32> {
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

fn cw_pow_f32(base: f32, exponent: f32) -> f32 {
  if(exponent >= -64.0f && exponent <= 64.0f && exponent == trunc(exponent)) {
    var count=u32(abs(exponent));
    var value=cw_d_from_f32(base);var product=cw_d_from_u32(1u);
    loop {
      if(count == 0u) { break; }
      if((count & 1u) != 0u) { product=cw_d_mul(product,value); }
      count >>= 1u;
      if(count != 0u) { value=cw_d_mul(value,value); }
    }
    if(exponent < 0.0f) { product=cw_d_div(cw_d_from_u32(1u),product); }
    return cw_d_to_f32(product);
  }
  return pow(base,exponent);
}

@compute @workgroup_size(8, 8, 1)
fn main(
  @builtin(local_invocation_id) cw_thread: vec3<u32>,
  @builtin(workgroup_id) cw_block: vec3<u32>,
  @builtin(num_workgroups) cw_grid: vec3<u32>
) {
  var v_ix: i32 = i32(((cw_block.x * cw_block_size.x) + cw_thread.x));
  var v_iy: i32 = i32(((cw_block.y * cw_block_size.y) + cw_thread.y));
  if (((v_ix >= cw_params.p_width) || (v_iy >= cw_params.p_height))) {
    return;
  }
  var v_u: f32 = cw_divide_f32(((f32(v_ix) + 0.5f) - (f32(cw_params.p_width) * 0.5f)), f32(cw_params.p_height));
  var v_v: f32 = cw_divide_f32((((f32(cw_params.p_height) * 0.5f) - f32(v_iy)) - 0.5f), f32(cw_params.p_height));
  var v_yaw: f32 = (cw_params.p_yawOffset + f_p_camera_yaw(cw_params.p_time, cw_thread, cw_block, cw_grid));
  var v_pitch: f32 = (cw_params.p_pitchOffset + f_p_camera_pitch(cw_params.p_time, cw_thread, cw_block, cw_grid));
  var v_zoom: f32 = (cw_params.p_zoomScale * f_p_camera_distance(cw_params.p_time, cw_thread, cw_block, cw_grid));
  var v_cx: f32 = ((sin(v_yaw) * cos(v_pitch)) * v_zoom);
  var v_cy: f32 = (sin(v_pitch) * v_zoom);
  var v_cz: f32 = ((cos(v_yaw) * cos(v_pitch)) * v_zoom);
  var v_dx: f32 = ((((v_u * 1.05f) * cos(v_yaw)) - (((v_v * 1.05f) * sin(v_yaw)) * sin(v_pitch))) - cw_divide_f32(v_cx, v_zoom));
  var v_dy: f32 = (((v_v * 1.05f) * cos(v_pitch)) - cw_divide_f32(v_cy, v_zoom));
  var v_dz: f32 = (((((-v_u) * 1.05f) * sin(v_yaw)) - (((v_v * 1.05f) * cos(v_yaw)) * sin(v_pitch))) - cw_divide_f32(v_cz, v_zoom));
  var v_inv: f32 = cw_divide_f32(1.0f, sqrt((((v_dx * v_dx) + (v_dy * v_dy)) + (v_dz * v_dz))));
  v_dx = (v_dx * v_inv);
  v_dy = (v_dy * v_inv);
  v_dz = (v_dz * v_inv);
  var v_trans: f32 = 1.0f;
  var v_red: f32 = 0.0f;
  var v_green: f32 = 0.0f;
  var v_blue: f32 = 0.0f;
  var v_step: f32 = 0.048f;
  var v_start: f32 = max(0.1f, (v_zoom - 2.8f));
  var v_jitter: f32 = (f_hash3(v_ix, v_iy, 4i, cw_thread, cw_block, cw_grid) * v_step);
  {
    var v_s: i32 = 0i;
    loop {
      if (!(v_s < 116i)) { break; }
      var v_t: f32 = ((v_start + (f32(v_s) * v_step)) + v_jitter);
      var v_x: f32 = (v_cx + (v_dx * v_t));
      var v_y: f32 = (v_cy + (v_dy * v_t));
      var v_z: f32 = (v_cz + (v_dz * v_t));
      var v_d: f32 = f_cw_buffer_helper_0(0i, v_x, v_y, v_z, cw_params.p_n, cw_params.p_time, cw_thread, cw_block, cw_grid);
      if (((v_d > 0.002f) && (v_trans > 0.015f))) {
        var v_shadow: f32 = (f_cw_buffer_helper_0(0i, (v_x - 0.12f), (v_y + 0.16f), (v_z + 0.13f), cw_params.p_n, cw_params.p_time, cw_thread, cw_block, cw_grid) * 0.18f);
        v_shadow = (v_shadow + (f_cw_buffer_helper_0(0i, (v_x - 0.3f), (v_y + 0.4f), (v_z + 0.32f), cw_params.p_n, cw_params.p_time, cw_thread, cw_block, cw_grid) * 0.3f));
        v_shadow = (v_shadow + (f_cw_buffer_helper_0(0i, (v_x - 0.65f), (v_y + 0.86f), (v_z + 0.7f), cw_params.p_n, cw_params.p_time, cw_thread, cw_block, cw_grid) * 0.5f));
        var v_lit: f32 = (f_p_shading_ambient(cw_params.p_time, cw_thread, cw_block, cw_grid) + ((f_p_shading_light(cw_params.p_time, cw_thread, cw_block, cw_grid) * exp(((-v_shadow) * f_p_volume_absorption(cw_params.p_time, cw_thread, cw_block, cw_grid)))) * 0.8f));
        var v_alpha: f32 = (1.0f - exp((((-v_d) * v_step) * f_p_volume_absorption(cw_params.p_time, cw_thread, cw_block, cw_grid))));
        var v_w: f32 = (v_alpha * v_trans);
        v_red = (v_red + ((v_w * v_lit) * (0.83f + (f_p_shading_warmth(cw_params.p_time, cw_thread, cw_block, cw_grid) * 0.17f))));
        v_green = (v_green + ((v_w * v_lit) * (0.88f + (f_p_shading_warmth(cw_params.p_time, cw_thread, cw_block, cw_grid) * 0.08f))));
        v_blue = (v_blue + ((v_w * v_lit) * (1.0f - (f_p_shading_warmth(cw_params.p_time, cw_thread, cw_block, cw_grid) * 0.22f))));
        v_trans = (v_trans * (1.0f - v_alpha));
      }
      continuing {
        v_s += i32(1);
      }
    }
  }
  var v_alpha: f32 = (1.0f - v_trans);
  var v_exposure: f32 = f_p_render_exposure(cw_params.p_time, cw_thread, cw_block, cw_grid);
  var v_r: f32 = f_sat((1.0f - exp(((-v_red) * v_exposure))), cw_thread, cw_block, cw_grid);
  var v_g: f32 = f_sat((1.0f - exp(((-v_green) * v_exposure))), cw_thread, cw_block, cw_grid);
  var v_b: f32 = f_sat((1.0f - exp(((-v_blue) * v_exposure))), cw_thread, cw_block, cw_grid);
  if ((cw_params.p_transparent == 0i)) {
    var v_vignette: f32 = (1.0f - (f_sat(((v_u * v_u) + (v_v * v_v)), cw_thread, cw_block, cw_grid) * 0.65f));
    v_r = (v_r + ((v_trans * 0.016f) * v_vignette));
    v_g = (v_g + ((v_trans * 0.019f) * v_vignette));
    v_b = (v_b + ((v_trans * 0.025f) * v_vignette));
    v_alpha = 1.0f;
  }
  if ((cw_params.p_bgra == 1i)) {
    var v_tmp: f32 = v_r;
    v_r = v_b;
    v_b = v_tmp;
  }
  b_pixels[((v_iy * cw_params.p_width) + v_ix)] = (((u32((f_sat(v_r, cw_thread, cw_block, cw_grid) * 255.0f)) | (u32((f_sat(v_g, cw_thread, cw_block, cw_grid) * 255.0f)) << 8u)) | (u32((f_sat(v_b, cw_thread, cw_block, cw_grid) * 255.0f)) << 16u)) | (u32((f_sat(v_alpha, cw_thread, cw_block, cw_grid) * 255.0f)) << 24u));
}
