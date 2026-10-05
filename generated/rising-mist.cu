// V2Cuda — live graph → CUDA → WGSL → WebGPU
// Connected graph: shape → emitter → noise → simulation → volume → shading → camera → render
// 3D incompressible smoke: semi-Lagrangian advection, vorticity confinement,
// buoyancy, Jacobi pressure projection and lit volume ray marching.
// Animation curves are compiled below. All simulation and pixels execute in CUDA.
// Host dispatch contract: see README.md.

__device__ float p_shape_radius(float time) { return 0.680000f; }
__device__ float p_shape_height(float time) { return 1.600000f; }
__device__ float p_shape_offset(float time) { return 0.000000f; }
__device__ float p_blend_softness(float time) { return 0.500000f; }
__device__ float p_noise_scale(float time) { return 2.700000f; }
__device__ float p_noise_strength(float time) { return 0.580000f; }
__device__ float p_noise_speed(float time) { return 0.400000f; }
__device__ float p_forceMix_mix(float time) { return 0.500000f; }
__device__ float p_emitter_density(float time) {
  if (time <= 0.000000f) return 2.400000f;
  if (time <= 0.800000f) return 2.400000f + (0.000000f) * (time-0.000000f) / 0.800000f;
  if (time <= 1.500000f) return 2.400000f + (-2.400000f) * (time-0.800000f) / 0.700000f;
  if (time <= 3.800000f) return 0.000000f + (0.000000f) * (time-1.500000f) / 2.300000f;
  if (time <= 4.200000f) return 0.000000f + (2.200000f) * (time-3.800000f) / 0.400000f;
  if (time <= 5.000000f) return 2.200000f + (0.000000f) * (time-4.200000f) / 0.800000f;
  if (time <= 5.800000f) return 2.200000f + (-2.200000f) * (time-5.000000f) / 0.800000f;
  if (time <= 8.000000f) return 0.000000f + (0.000000f) * (time-5.800000f) / 2.200000f;
  return 0.000000f;
}
__device__ float p_emitter_lift(float time) { return 0.650000f; }
__device__ float p_simulation_vorticity(float time) { return 3.000000f; }
__device__ float p_simulation_dissipation(float time) { return 0.120000f; }
__device__ float p_simulation_buoyancy(float time) { return 1.250000f; }
__device__ float p_volume_absorption(float time) { return 2.400000f; }
__device__ float p_volume_detail(float time) { return 0.750000f; }
__device__ float p_volume_contrast(float time) { return 1.050000f; }
__device__ float p_shading_warmth(float time) { return 0.240000f; }
__device__ float p_shading_light(float time) { return 1.500000f; }
__device__ float p_shading_ambient(float time) { return 0.240000f; }
__device__ float p_camera_distance(float time) { return 3.500000f; }
__device__ float p_camera_yaw(float time) { return 0.000000f; }
__device__ float p_camera_pitch(float time) { return 0.060000f; }
__device__ float p_render_exposure(float time) { return 1.700000f; }
__device__ float node_0_radius(float time){return 0.680000f;}
__device__ float node_0_height(float time){return 1.600000f;}
__device__ float node_0_offset(float time){return 0.000000f;}
__device__ float node_0(float x,float y,float z,float time){float ex=(x-node_0_offset(time))/node_0_radius(time);float ey=(y+1.12f)/(node_0_height(time)*0.32f);float ez=z/node_0_radius(time);return sat(1.0f-ex*ex-ey*ey-ez*ez);}
__device__ float node_2_scale(float time){return 2.700000f;}
__device__ float node_2_strength(float time){return 0.580000f;}
__device__ float node_2_speed(float time){return 0.400000f;}
__device__ float3 node_2(float x,float y,float z,float time){float s=node_2_scale(time);float t=time*node_2_speed(time);return make_float3(noise3(x*s,y*s-t,z*s)-0.5f,(noise3(x*s+19.0f,y*s-t,z*s+8.0f)-0.5f)*0.3f,noise3(x*s+33.0f,y*s-t,z*s+12.0f)-0.5f)*node_2_strength(time);}
__device__ float emitter_shape(float x,float y,float z,float time){return node_0(x,y,z,time);}
__device__ float3 external_force(float x,float y,float z,float time){return node_2(x,y,z,time);}


__device__ float sat(float x) { return fminf(1.0f,fmaxf(0.0f,x)); }
__device__ float mixf(float a,float b,float t) { return a+(b-a)*t; }
__device__ int at(int x,int y,int z,int n) { return (max(0,min(n-1,z))*n+max(0,min(n-1,y)))*n+max(0,min(n-1,x)); }
__device__ float hash3(int x,int y,int z) {
  unsigned int h=(unsigned int)x*374761393u+(unsigned int)y*668265263u+(unsigned int)z*2246822519u;
  h=(h^(h>>13u))*1274126177u;
  return (float)((h^(h>>16u))&65535u)/65535.0f;
}
__device__ float noise3(float x,float y,float z) {
  int ix=(int)floorf(x);int iy=(int)floorf(y);int iz=(int)floorf(z);
  float a=x-floorf(x);float b=y-floorf(y);float c=z-floorf(z);
  a=a*a*(3.0f-2.0f*a);b=b*b*(3.0f-2.0f*b);c=c*c*(3.0f-2.0f*c);
  float q0=mixf(hash3(ix,iy,iz),hash3(ix+1,iy,iz),a);
  float q1=mixf(hash3(ix,iy+1,iz),hash3(ix+1,iy+1,iz),a);
  float q2=mixf(hash3(ix,iy,iz+1),hash3(ix+1,iy,iz+1),a);
  float q3=mixf(hash3(ix,iy+1,iz+1),hash3(ix+1,iy+1,iz+1),a);
  return mixf(mixf(q0,q1,b),mixf(q2,q3,b),c);
}
// Field is float4: XYZ velocity in cells/second, W smoke density.
__device__ float4 sample_field(const float4* field,float x,float y,float z,int n) {
  x=fminf((float)n-1.001f,fmaxf(0.0f,x));y=fminf((float)n-1.001f,fmaxf(0.0f,y));z=fminf((float)n-1.001f,fmaxf(0.0f,z));
  int ix=(int)floorf(x);int iy=(int)floorf(y);int iz=(int)floorf(z);
  float a=x-(float)ix;float b=y-(float)iy;float c=z-(float)iz;
  float4 q0=field[at(ix,iy,iz,n)]*(1.0f-a)+field[at(ix+1,iy,iz,n)]*a;
  float4 q1=field[at(ix,iy+1,iz,n)]*(1.0f-a)+field[at(ix+1,iy+1,iz,n)]*a;
  float4 q2=field[at(ix,iy,iz+1,n)]*(1.0f-a)+field[at(ix+1,iy,iz+1,n)]*a;
  float4 q3=field[at(ix,iy+1,iz+1,n)]*(1.0f-a)+field[at(ix+1,iy+1,iz+1,n)]*a;
  return (q0*(1.0f-b)+q1*b)*(1.0f-c)+(q2*(1.0f-b)+q3*b)*c;
}
__global__ void clear_field(float4* field,float* pressure,int n) {
  int i=(int)(blockIdx.x*blockDim.x+threadIdx.x);if(i>=n*n*n)return;
  field[i]=make_float4(0.0f,0.0f,0.0f,0.0f);pressure[i]=0.0f;
}
__global__ void advect(const float4* field,float4* output,int n,float dt,float time) {
  int i=(int)(blockIdx.x*blockDim.x+threadIdx.x);if(i>=n*n*n)return;
  int x=i%n;int y=(i/n)%n;int z=i/(n*n);
  float4 v=field[i];float4 back=sample_field(field,(float)x-v.x*dt,(float)y-v.y*dt,(float)z-v.z*dt,n);
  back.x*=0.998f;back.y*=0.998f;back.z*=0.998f;
  back.w*=expf(-dt*p_simulation_dissipation(time));
  if(x<2||x>n-3||y<2||y>n-3||z<2||z>n-3)back.w*=0.85f;
  output[i]=back;
}
__global__ void compute_curl(const float4* field,float4* curls,int n) {
  int i=(int)(blockIdx.x*blockDim.x+threadIdx.x);if(i>=n*n*n)return;
  int x=i%n;int y=(i/n)%n;int z=i/(n*n);
  float4 l=field[at(x-1,y,z,n)];float4 r=field[at(x+1,y,z,n)];
  float4 b=field[at(x,y-1,z,n)];float4 t=field[at(x,y+1,z,n)];
  float4 f=field[at(x,y,z-1,n)];float4 k=field[at(x,y,z+1,n)];
  float cx=(t.z-b.z-k.y+f.y)*0.5f;float cy=(k.x-f.x-r.z+l.z)*0.5f;float cz=(r.y-l.y-t.x+b.x)*0.5f;
  curls[i]=make_float4(cx,cy,cz,sqrtf(cx*cx+cy*cy+cz*cz));
}
__global__ void apply_forces(const float4* field,const float4* curls,float4* output,int n,float dt,float time) {
  int i=(int)(blockIdx.x*blockDim.x+threadIdx.x);if(i>=n*n*n)return;
  int x=i%n;int y=(i/n)%n;int z=i/(n*n);float4 v=field[i];float4 c=curls[i];
  float nx=curls[at(x+1,y,z,n)].w-curls[at(x-1,y,z,n)].w;
  float ny=curls[at(x,y+1,z,n)].w-curls[at(x,y-1,z,n)].w;
  float nz=curls[at(x,y,z+1,n)].w-curls[at(x,y,z-1,n)].w;
  float inv=1.0f/fmaxf(0.0001f,sqrtf(nx*nx+ny*ny+nz*nz));nx*=inv;ny*=inv;nz*=inv;
  float vort=p_simulation_vorticity(time)*dt;
  v.x+=(ny*c.z-nz*c.y)*vort;v.y+=(nz*c.x-nx*c.z)*vort;v.z+=(nx*c.y-ny*c.x)*vort;
  float wx=((float)x/(float)n-0.5f)*4.0f;float wy=((float)y/(float)n-0.5f)*4.0f;float wz=((float)z/(float)n-0.5f)*4.0f;
  float3 force=external_force(wx,wy,wz,time);float forceScale=dt*45.0f*sat(v.w)*(float)n/64.0f;
  v.x+=force.x*forceScale;v.y+=force.y*forceScale;v.z+=force.z*forceScale;
  v.y+=dt*p_simulation_buoyancy(time)*v.w*3.0f*(float)n/64.0f;
  float shape=emitter_shape(wx,wy,wz,time);
  shape*=sat((noise3(wx*6.0f+10.0f,wy*6.0f-time,wz*6.0f)-0.22f)*3.5f);
  float puff=0.6f+0.4f*noise3(wx*7.0f,wy*7.0f-time*1.2f,wz*7.0f);
  float emit=shape*puff*p_emitter_density(time)*dt*4.0f;
  v.w=fminf(4.0f,v.w+emit);v.y+=shape*dt*p_emitter_lift(time)*22.0f*(float)n/64.0f;
  if(x<1||x>n-2)v.x=0.0f;if(y<1||y>n-2)v.y=0.0f;if(z<1||z>n-2)v.z=0.0f;
  output[i]=v;
}
__global__ void divergence(const float4* field,float* div,float* pressure,int n) {
  int i=(int)(blockIdx.x*blockDim.x+threadIdx.x);if(i>=n*n*n)return;
  int x=i%n;int y=(i/n)%n;int z=i/(n*n);
  div[i]=0.5f*(field[at(x+1,y,z,n)].x-field[at(x-1,y,z,n)].x+field[at(x,y+1,z,n)].y-field[at(x,y-1,z,n)].y+field[at(x,y,z+1,n)].z-field[at(x,y,z-1,n)].z);
  pressure[i]=0.0f;
}
__global__ void pressure_solve(const float* pressure,const float* div,float* output,int n) {
  int i=(int)(blockIdx.x*blockDim.x+threadIdx.x);if(i>=n*n*n)return;
  int x=i%n;int y=(i/n)%n;int z=i/(n*n);
  output[i]=(pressure[at(x-1,y,z,n)]+pressure[at(x+1,y,z,n)]+pressure[at(x,y-1,z,n)]+pressure[at(x,y+1,z,n)]+pressure[at(x,y,z-1,n)]+pressure[at(x,y,z+1,n)]-div[i])/6.0f;
}
__global__ void project(const float4* field,const float* pressure,float4* output,int n) {
  int i=(int)(blockIdx.x*blockDim.x+threadIdx.x);if(i>=n*n*n)return;
  int x=i%n;int y=(i/n)%n;int z=i/(n*n);float4 v=field[i];
  v.x-=0.5f*(pressure[at(x+1,y,z,n)]-pressure[at(x-1,y,z,n)]);
  v.y-=0.5f*(pressure[at(x,y+1,z,n)]-pressure[at(x,y-1,z,n)]);
  v.z-=0.5f*(pressure[at(x,y,z+1,n)]-pressure[at(x,y,z-1,n)]);
  if(x<1||x>n-2)v.x=0.0f;if(y<1||y>n-2)v.y=0.0f;if(z<1||z>n-2)v.z=0.0f;
  output[i]=v;
}
__device__ float smoke(const float4* field,float x,float y,float z,int n,float time) {
  if(fabsf(x)>1.96f||fabsf(y)>1.96f||fabsf(z)>1.96f)return 0.0f;
  float detail=p_volume_detail(time);
  float warp=noise3(x*4.0f,y*4.0f-time*0.5f,z*4.0f)-0.5f;
  x+=warp*detail*0.18f;z+=warp*detail*0.13f;
  float d=sample_field(field,(x*0.25f+0.5f)*(float)n,(y*0.25f+0.5f)*(float)n,(z*0.25f+0.5f)*(float)n,n).w;
  if(d<0.003f)return 0.0f;
  float ny=y-time*0.26f;
  float coarse=noise3(x*5.5f,ny*5.5f,z*5.5f);
  float fine=noise3(x*13.0f+7.0f,ny*13.0f,z*13.0f)*0.5f+noise3(x*27.0f,ny*27.0f,z*27.0f)*0.22f;
  d=fmaxf(0.0f,d-(coarse+fine)*detail*1.15f);
  d*=1.0f+detail*(coarse-0.5f)*0.8f;
  return powf(d,p_volume_contrast(time));
}
__global__ void mist_render(const float4* field,unsigned int* pixels,int n,int width,int height,float time,float yawOffset,float pitchOffset,float zoomScale,int bgra,int transparent) {
  int ix=(int)(blockIdx.x*blockDim.x+threadIdx.x);int iy=(int)(blockIdx.y*blockDim.y+threadIdx.y);
  if(ix>=width||iy>=height)return;
  float u=((float)ix+0.5f-(float)width*0.5f)/(float)height;float v=((float)height*0.5f-(float)iy-0.5f)/(float)height;
  float yaw=yawOffset+p_camera_yaw(time);float pitch=pitchOffset+p_camera_pitch(time);float zoom=zoomScale*p_camera_distance(time);
  float cx=sinf(yaw)*cosf(pitch)*zoom;float cy=sinf(pitch)*zoom;float cz=cosf(yaw)*cosf(pitch)*zoom;
  float dx=u*1.05f*cosf(yaw)-v*1.05f*sinf(yaw)*sinf(pitch)-cx/zoom;
  float dy=v*1.05f*cosf(pitch)-cy/zoom;
  float dz=-u*1.05f*sinf(yaw)-v*1.05f*cosf(yaw)*sinf(pitch)-cz/zoom;
  float inv=1.0f/sqrtf(dx*dx+dy*dy+dz*dz);dx*=inv;dy*=inv;dz*=inv;
  float trans=1.0f;float red=0.0f;float green=0.0f;float blue=0.0f;
  float step=0.048f;float start=fmaxf(0.1f,zoom-2.8f);float jitter=hash3(ix,iy,4)*step;
  for(int s=0;s<116;s++) {
    float t=start+(float)s*step+jitter;float x=cx+dx*t;float y=cy+dy*t;float z=cz+dz*t;
    float d=smoke(field,x,y,z,n,time);
    if(d>0.002f&&trans>0.015f) {
      float shadow=smoke(field,x-0.12f,y+0.16f,z+0.13f,n,time)*0.18f;
      shadow+=smoke(field,x-0.3f,y+0.4f,z+0.32f,n,time)*0.3f;
      shadow+=smoke(field,x-0.65f,y+0.86f,z+0.7f,n,time)*0.5f;
      float lit=p_shading_ambient(time)+p_shading_light(time)*expf(-shadow*p_volume_absorption(time))*0.8f;
      float alpha=1.0f-expf(-d*step*p_volume_absorption(time));float w=alpha*trans;
      red+=w*lit*(0.83f+p_shading_warmth(time)*0.17f);green+=w*lit*(0.88f+p_shading_warmth(time)*0.08f);blue+=w*lit*(1.0f-p_shading_warmth(time)*0.22f);
      trans*=1.0f-alpha;
    }
  }
  float alpha=1.0f-trans;float exposure=p_render_exposure(time);
  float r=sat(1.0f-expf(-red*exposure));float g=sat(1.0f-expf(-green*exposure));float b=sat(1.0f-expf(-blue*exposure));
  if(transparent==0){float vignette=1.0f-sat(u*u+v*v)*0.65f;r+=trans*0.016f*vignette;g+=trans*0.019f*vignette;b+=trans*0.025f*vignette;alpha=1.0f;}
  if(bgra==1){float tmp=r;r=b;b=tmp;}
  pixels[iy*width+ix]=(unsigned int)(sat(r)*255.0f)|((unsigned int)(sat(g)*255.0f)<<8u)|((unsigned int)(sat(b)*255.0f)<<16u)|((unsigned int)(sat(alpha)*255.0f)<<24u);
}
