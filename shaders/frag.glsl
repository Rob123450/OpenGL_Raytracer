#version 420 core

out vec4 outColor;

in vec3 fragNormal;
in vec3 fragPosition;

uniform vec4 light_pos;
uniform vec3 eye_pos;
uniform float ambient_intensity;
uniform float roughness;
uniform float metallic;
uniform int mat_type;
uniform vec3 lightColor;
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

//The following 3 Funcitons are necessary for PBR feature
vec3 computeDiffuse(vec3 N, vec3 L, vec3 F, vec3 material_color){

      vec3 ks = F;
      vec3 Kd = 1-ks;

      return  Kd * (1-metallic) * material_color * max(dot(N, L), 0);
}

float geometric_attenuation(vec3 N, vec3 V, vec3 L)
{
      float alpha = pow(roughness,2);
      float k = (alpha) / 2;

      // Masking Term
      float Gv = max(dot(N, V),0) / (max(dot(N, V),0) * (1 - k) + k);
      // Shadowing Term
      float Gl = max(dot(N, L),0) / (max(dot(N, L),0) * (1 - k) + k);

      return Gv * Gl;
}

float microfacet_distribution(vec3 N, vec3 H)
{
      float alpha = pow(roughness,2);
      float pi = 3.14;
      return pow(alpha,2)/pow(pi * (pow(max(dot(N, H),0),2) * (pow(alpha,2) - 1) + 1),2);
}

void main(){
      vec3 N = normalize(fragNormal);
      vec3 L;
      if (light_pos.w==0.0)   L = normalize(light_pos.xyz);                   // directional light
      else                    L = normalize(light_pos.xyz-fragPosition);      // point light

      vec3 difuse = computeDiffuse(N, L);

      //vec3 N = normalize(fragNormal);
      //vec3 L = normalize(light_pos.xyz);
      vec3 V = normalize(eye_pos-fragPosition);
      vec3 H = normalize(L + V);


      vec3 F0_metal;
      vec3 F0_dielectric = vec3(.04,.04,.04);

      // Metals
      if(mat_type == 1)       F0_metal = vec3(0.56,0.57,0.58);
      else if (mat_type == 2) F0_metal = vec3(0.95,0.64,0.54);
      else if (mat_type == 3) F0_metal = vec3(1.00,0.71,0.29);
      else if (mat_type == 4) F0_metal = vec3(0.91,0.92,0.92);
      else if (mat_type == 5) F0_metal = vec3(0.95,0.93,0.88);

      vec3 material_color = F0_metal;
      vec3 F0 = mix(F0_dielectric,F0_metal,metallic);

      vec3 F = F0 + (1-F0) * pow((1-max(dot(V,H),0)),5);

      float G = geometric_attenuation(N,V,L);

      float D = microfacet_distribution(N,H);

      vec3 microfacet = F * D * G;

      vec3 diffuseColor = computeDiffuse(N, L, F,material_color);


      vec3 ambientColor = ambient_intensity * material_color;

      vec3 specular_color = microfacet * lightColor;


      //outColor = vec4(ambientColor + diffuseColor + specular_color,1.0);

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