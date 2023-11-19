#version 420 core
#define NUMBOUNCES 1000
#define PI 3.14159
#define EPSILON 1e-5
#define INFINITY 1e5

out vec4 outColor;

in vec3 fragNormal;
in vec3 fragPosition;

uniform vec3 center;
uniform float radius;

//PBR Uniforms
uniform vec4 light_pos;
uniform vec3 eye_pos;
uniform float ambient_intensity;
uniform float roughness;
uniform float metallic;
uniform int mat_type;
uniform vec3 lightColor;
uniform vec3 material_color;
// Raytracing Uniforms

uniform vec3 Background;
uniform vec2 resolution;
uniform vec3 cameraU;
uniform vec3 cameraV;
uniform vec3 cameraW;
uniform vec3 cameraEye;
uniform float fov;

uniform vec3 minBound;
uniform vec3 maxBound;



struct Hit{
    float d;
    vec3 point;
    vec3 normal;
};

struct Ray{
    vec3 direction;
    vec3 origin;
    float tMin, tMax;
};

struct AABB {
      vec3 minP;
      vec3 maxP;
};

vec3 pointOnRay(in Ray ray, float t){
      return (ray.origin + t*ray.direction);
}


Ray getRay(vec2 pixel)
{
      Ray ray;
      ray.origin = cameraEye;
      float height = 2.*tan(fov/2.);
      float aspect = resolution.x/resolution.y;
      float width = height * aspect;
      vec2 windowDim = vec2(width, height);
      vec2 pixelSize = windowDim / resolution;
      vec2 delta = -0.5 * windowDim + pixel * pixelSize;
      ray.direction = -cameraW + cameraV * delta.y + cameraU * delta.x;
      ray.tMin = 0.;
      ray.tMax = INFINITY;
      return ray;
}

float sphereIntersectPoint(Ray ray)
{
      float b = 2 * dot(ray.direction, ray.origin - center);
      float magnitude = length(ray.origin - center);
      float c = pow(magnitude, 2) - pow(radius, 2);
      float delta = pow(b, 2) - (4 * c);
      if (delta > 0)
      {
            float t1 = (-b + sqrt(delta)) / 2;
            float t2 = (-b - sqrt(delta)) / 2;

            if (t1 > 0 && t2 > 0)
            {
                  return min(t1, t2);
            }
      }

      return INFINITY;
}


// RaycastFrag()


// This could potentially come later
// Denoiser()

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
      float Gv = clamp(dot(V, N), 0., 1.) / (clamp(dot(N, V), 0., 1.) * (1-k) + k);
      // Shadowing Term
      float Gl = clamp(dot(L, N), 0., 1.) / (clamp(dot(L, N), 0., 1.) * (1-k) + k);

      return Gv * Gl;
}

float microfacet_distribution(vec3 N, vec3 H)
{
      float alpha = pow(roughness,2);
      return pow(alpha, 2) / (PI * pow((pow(max(dot(H, N),0),2) * (pow(alpha,2) - 1) + 1),2));
}


vec3 computePBR()
{
      vec3 N = normalize(fragNormal);
      vec3 L = normalize(light_pos.xyz - fragPosition);

      //if (light_pos.w==0.0)   L = normalize(light_pos.xyz);                   // directional light
      //else                    L = normalize(light_pos.xyz-fragPosition);      // point light

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

      vec3 F = F0 + (1 - F0) * pow( (1-clamp(dot(H,V), 0, 1)), 5 );

      float G = geometric_attenuation(N,V,L);

      float D = microfacet_distribution(N,H);

      vec3 microfacet = F * D * G;

      vec3 diffuseColor = computeDiffuse(N, L, F, material_color);

      vec3 ambientColor = ambient_intensity * material_color;

      vec3 specularColor = microfacet * lightColor;

      return vec3(ambientColor + specularColor + diffuseColor);
}


void main()
{
      vec3 pbrColor = computePBR();

      //outColor = vec4(ambientColor + diffuseColor + specular_color,1.0);

      /*
            Implement
            for(int i; i < NUMBOUNCES;i++)
                  Call raycast frag to get nearest intersected object
                  Calculate shadows
                  Change ray
            Potentially multiply by diffuse color
      */
      Ray ray;
      ray.origin = eye_pos;
      ray.direction = normalize(fragPosition - eye_pos);
      float min_distance = sphereIntersectPoint(ray);

      vec3 intersection = ray.origin + min_distance * ray.direction;
      vec3 normal_to_surface = normalize(center - intersection);
      vec3 shifted_point = intersection + 0.0001 * normal_to_surface;

      vec3 intersection_to_light = normalize(light_pos.xyz - shifted_point);
      float intersection_to_light_distance = length(light_pos.xyz - intersection);
      Ray light_check;
      light_check.origin = shifted_point;
      light_check.direction = intersection_to_light;
      min_distance = sphereIntersectPoint(light_check);
      
      
      bool is_shadowed = min_distance < intersection_to_light_distance;
      vec3 raycastColor;
      if (is_shadowed)
            raycastColor = vec3(0.0);
      else
            raycastColor = vec3(1.0);
      // if (min_distance == INFINITY)
      //       raycastColor = vec3(0.0);
      // else
      //       raycastColor = intersection;

      outColor = vec4(raycastColor, 1.0);
}