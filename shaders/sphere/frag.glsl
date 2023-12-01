#version 420 core
#define NUMBOUNCES 1000
#define PI 3.14159
#define EPSILON 1e-5
#define INFINITY 1e5

out vec4 outColor;

in vec3 fragNormal;
in vec3 fragPosition;

//PBR Uniforms
uniform vec4 light_pos;
uniform vec3 eye_pos;
uniform vec3 lightColor;
// Raytracing Uniforms

uniform vec2 resolution;
uniform vec3 cameraU;
uniform vec3 cameraV;
uniform vec3 cameraW;
//uniform vec3 cameraEye;
uniform float fov;

uniform samplerCube cubeMapTex;

//uniform vec3 minBound;
//uniform vec3 maxBound;

uniform float ambient_intensity;

struct Material{
      vec3 color;
      float k_d;
      float k_s;
      float k_r;
};

struct Sphere{
      float radius;
      vec3 center;
      Material mat;
};

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
      ray.origin = eye_pos;
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

Hit sphereIntersectPoint(Sphere sphere, Ray ray)
{
      Hit hit = Hit(-1.0, vec3(0.0), vec3(0));
      vec3 magnitude = ray.origin - sphere.center;
      float a = dot(ray.direction, ray.direction);
      float b = 2 * dot(ray.direction, ray.origin - sphere.center);
      float c = dot(magnitude, magnitude) - pow(sphere.radius, 2);
      float delta = pow(b, 2) - (4.0 * a * c);
      if (delta > 0)
      {
            float t1 = (-b + sqrt(delta)) / (2.0 * a);
            float t2 = (-b - sqrt(delta)) / (2.0 * a);
            ray.tMin = t1;
            ray.tMax = t2;
            hit.d = min(t1, t2);
            hit.point = ray.origin + hit.d * ray.direction;
            hit.normal = normalize(hit.point - sphere.center);
      }

      return hit;
}

Sphere nearest_intersected_object(Sphere[2] spheres, Ray ray)
{
      Hit[spheres.length] distances;
      for (int i = 0; i < spheres.length; i++)
      {
            distances[i] = sphereIntersectPoint(spheres[i], ray);
      }
      float min_distance = INFINITY;
      Sphere nearest_object;
      for (int i = 0; i < distances.length; i++)
      {
            if (distances[i].d > 0 && distances[i].d < min_distance)
            {
                  min_distance = distances[i].d;
                  nearest_object = spheres[i];
            }
      }

      if (min_distance == INFINITY)
            nearest_object.mat.color = vec3(0.0);

      return nearest_object;
}

vec3 compute_reflection_vector(vec3 vector, vec3 axis)
{
      return vector - 2.0 * dot(axis,vector) * axis;
}

// RaycastFrag()


// This could potentially come later
// Denoiser()

//The following 3 Funcitons are necessary for PBR feature
// vec3 computeDiffuse(vec3 N, vec3 L, vec3 F, vec3 material_color){

//       vec3 ks = F;
//       vec3 Kd = 1-ks;

//       return  Kd * (1-metallic) * material_color * max(dot(N, L), 0);
// }

// float geometric_attenuation(vec3 N, vec3 V, vec3 L)
// {
//       float alpha = pow(roughness,2);
//       float k = (alpha) / 2;

//       // Masking Term
//       float Gv = clamp(dot(V, N), 0., 1.) / (clamp(dot(N, V), 0., 1.) * (1-k) + k);
//       // Shadowing Term
//       float Gl = clamp(dot(L, N), 0., 1.) / (clamp(dot(L, N), 0., 1.) * (1-k) + k);

//       return Gv * Gl;
// }

// float microfacet_distribution(vec3 N, vec3 H)
// {
//       float alpha = pow(roughness,2);
//       return pow(alpha, 2) / (PI * pow((pow(max(dot(H, N),0),2) * (pow(alpha,2) - 1) + 1),2));
// }


// vec3 computePBR()
// {
//       vec3 Background = vec3(0.0);
//       vec3 N = normalize(fragNormal);
//       vec3 L = normalize(light_pos.xyz - fragPosition);

//       //if (light_pos.w==0.0)   L = normalize(light_pos.xyz);                   // directional light
//       //else                    L = normalize(light_pos.xyz-fragPosition);      // point light

//       vec3 V = normalize(eye_pos-fragPosition);
//       vec3 H = normalize(L + V);

//       vec3 F0_metal;
//       vec3 F0_dielectric = vec3(.04,.04,.04);

//       // Metals
//       if(mat_type == 1)       F0_metal = vec3(0.56,0.57,0.58);
//       else if (mat_type == 2) F0_metal = vec3(0.95,0.64,0.54);
//       else if (mat_type == 3) F0_metal = vec3(1.00,0.71,0.29);
//       else if (mat_type == 4) F0_metal = vec3(0.91,0.92,0.92);
//       else if (mat_type == 5) F0_metal = vec3(0.95,0.93,0.88);

//       vec3 material_color = F0_metal;
//       vec3 F0 = mix(F0_dielectric,F0_metal,metallic);

//       vec3 F = F0 + (1 - F0) * pow( (1-clamp(dot(H,V), 0, 1)), 5 );

//       float G = geometric_attenuation(N,V,L);

//       float D = microfacet_distribution(N,H);

//       vec3 microfacet = F * D * G;

//       vec3 diffuseColor = computeDiffuse(N, L, F, material_color);

//       vec3 ambientColor = ambient_intensity * material_color;

//       vec3 specularColor = microfacet * lightColor;

//       return vec3(ambientColor + specularColor + diffuseColor);
// }

vec3 GetLighting(Material mat, Hit hit, Ray ray, vec3 intersection_to_light)
{
      float diff = max(dot(-intersection_to_light, hit.normal), 0.0);

      vec3 reflect_dir = -intersection_to_light - 2.0 * hit.normal * dot(-intersection_to_light, hit.normal);

      float spec = pow(max(dot(hit.normal, reflect_dir), 0.0), mat.k_s);
      
      vec3 col = mat.color * lightColor * (diff * mat.k_d + spec * mat.k_r);

      return col;
}

// Accidentally made black hole effect, need to find a way to make the reflections be less warped.
// Try messing with the function logic
vec3 pixelColor(Sphere[2] spheres, vec2 pixel)
{
      float reflection = 1.0;
      vec3 background = normalize(vec3(127.0, 255.0, 212.0));
      Ray ray = getRay(pixel);
      Sphere closest_sphere = nearest_intersected_object(spheres, ray);
      Hit hit = sphereIntersectPoint(closest_sphere, ray);
      vec3 color = vec3(0.0);
      vec3 final_color = vec3(0.0);
      if (hit.d < 0.0)
      {
            return texture(cubeMapTex, compute_reflection_vector(ray.direction, hit.normal)).rgb;
      }

      for (int i = 0; i < 10; i++)
      {
            closest_sphere = nearest_intersected_object(spheres, ray);
            hit = sphereIntersectPoint(closest_sphere, ray);
            if (hit.d > 0)
            {
                  vec3 shifted_point = hit.point + hit.normal * 0.0001;
                  vec3 intersection_to_light = normalize(light_pos.xyz - shifted_point);
                  float intersection_to_light_distance = length(light_pos.xyz - hit.point);
                  float shadow_factor = 0.2;
                  Ray light_check;
                  light_check.origin = shifted_point;
                  light_check.direction = intersection_to_light;
                  Hit min_distance = sphereIntersectPoint(closest_sphere, light_check);
                  // return normalize(min_distance.point);
                  
                  bool is_shadowed = min_distance.d > 0;
                  
                  // if (is_shadowed)
                  // {
                  //       break;
                  // }
                  
                  vec3 intersection_to_camera = normalize(eye_pos - hit.point);
                  vec3 H = normalize(intersection_to_light + intersection_to_camera);

                  color += GetLighting(closest_sphere.mat, min_distance, ray, intersection_to_light);

                  final_color += color * reflection;
                  reflection *= closest_sphere.mat.k_r;

                  ray.origin = shifted_point;
                  ray.direction = compute_reflection_vector(ray.direction, hit.normal);
            }
            else
            {
                  color = texture(cubeMapTex, compute_reflection_vector(-ray.direction, hit.normal)).rgb;
                  final_color += color * reflection;
                  break;
            }
      }

      return final_color;
}

void main()
{
      Sphere[2] spheres;

      spheres[0].radius = 1.0;
      spheres[0].center = vec3(0.0);
      // vec3 pbrColor = computePBR();

      spheres[0].mat.color = vec3(0.0, 0.0, 1.0);
      spheres[0].mat.k_d = 0.5;
      spheres[0].mat.k_s = 0.5;
      spheres[0].mat.k_r = 1.0;

      spheres[1].radius = 0.25;
      spheres[1].center = vec3(-2.0, 1.0, 0.0);

      spheres[1].mat.color = vec3(0.8, 0.8, 0.1);
      spheres[1].mat.k_d = 1.0;
      spheres[1].mat.k_s = 16.0;
      spheres[1].mat.k_r = 1.0;

      //outColor = vec4(ambientColor + diffuseColor + specular_color,1.0);

      /*
            Implement
            for(int i; i < NUMBOUNCES;i++)
                  Call raycast frag to get nearest intersected object
                  Calculate shadows
                  Change ray
            Potentially multiply by diffuse color
      */

      // vec3 raycastColor = vec3(0.0);
      // Ray ray;
      // ray.origin = eye_pos;
      // ray.direction = normalize(fragPosition - eye_pos);
      // vec3 illumination = vec3(0.0);
      // float reflection = 1;
      // for (int i = 0; i < NUMBOUNCES; i++)
      // {
      //       Sphere nearest_object = nearest_intersected_object(spheres, ray);
      //       float min_distance = sphereIntersectPoint(spheres[i], ray);

      //       if (min_distance == INFINITY)
      //       {
      //             raycastColor = vec3(1.0);
      //             break;
      //       }

      //       // Implement ray hitting light source
      //       //illumination = vec3(0.0);
      //       //illumination += pbrColor;
      //       //raycastColor += reflection * illumination;
      //       raycastColor = vec3(1.0);

      //       vec3 intersection = ray.origin + min_distance * ray.direction;
      //       vec3 normal_to_surface = normalize(intersection - center);
      //       vec3 shifted_point = intersection + 0.0001 * normal_to_surface;

      //       vec3 intersection_to_light = normalize(light_pos.xyz - shifted_point);
      //       float intersection_to_light_distance = length(light_pos.xyz - intersection);
      //       float shadow_factor = 0.5;
      //       Ray light_check;
      //       light_check.origin = shifted_point;
      //       light_check.direction = intersection_to_light;
      //       min_distance = sphereIntersectPoint(spheres[i], light_check);
            
            
      //       bool is_shadowed = min_distance < intersection_to_light_distance;
            
      //       if (is_shadowed)
      //       {
      //             raycastColor = vec3(1.0);
      //             break;
      //       }

      //       ray.origin = shifted_point;
      //       ray.direction = compute_reflection_vector(ray.direction, normal_to_surface);
      // }

      // if (is_shadowed)
      // else
      //       raycastColor = pbrColor;
      // if (min_distance == INFINITY)
      //       raycastColor = vec3(0.0, 0.0, 1.0);
      // else
      //       raycastColor = vec3(1.0);
      Ray ray = getRay(gl_FragCoord.xy);
      outColor = vec4(pixelColor(spheres, gl_FragCoord.xy), 1.0);
      //outColor = vec4(pixelColor(spheres, gl_FragCoord.xy), 1.0);
}