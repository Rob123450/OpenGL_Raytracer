#version 330 core

out vec4 outColor;

in vec3 fragNormal;
in vec3 fragPosition;

uniform vec4 light_pos;
uniform vec3 eye_pos;

uniform vec3 material_color;

struct Hit{
    float d;
    vec3 point;
    vec3 normal;
};

struct Ray{
    vec3 dir;
    vec3 origin;
};


// RaycastFrag()


// This could potentially come later
// Denoiser()

vec3 computeDiffuse(vec3 N, vec3 L){
      return material_color * clamp(dot(L,N), 0.,1.);
}


void main(){
      vec3 N = normalize(fragNormal);
      vec3 L;
      if (light_pos.w==0.0)   L = normalize(light_pos.xyz);                   // directional light
      else                    L = normalize(light_pos.xyz-fragPosition);      // point light

      vec3 difuse = computeDiffuse(N, L);

      /*
            Implement
            for(int i; i < numBounces;i++)
                  Call raycast frag to get nearest intersected object
                  Calculate shadows
                  Change ray
            Potentially multiply by diffuse color
      */

      outColor = vec4(difuse, 1.0);


}