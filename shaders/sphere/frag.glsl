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
      float metallic;
      float roughness;
      int mat_type;
};

struct Sphere{
      float radius;
      vec3 center;
      Material mat;
};

struct Plane{
      vec3 center;
      vec3 size;
      vec3 normal;
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

float rand(vec2 seed) {
    // Simple pseudo-random number generator
    return fract(sin(dot(seed, vec2(12.9898, 78.233))) * 43758.5453);
}

// Taken from Raytracing AABB implementation from the professor's GitHub
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

// Determines the hit point of a raycast-sphere intersection
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

// Determines the hit point of a raycast-plane intersection
Hit planeIntersectPoint(Plane plane, Ray ray)
{
      Hit hit = Hit(-1.0, vec3(0.0), vec3(0));

      if (ray.direction.y != 0.0)
      {
            hit.d = (plane.center.y - ray.origin.y) / ray.direction.y;
            hit.point = ray.origin + hit.d * ray.direction;
            hit.normal = plane.normal;

            vec3 relative_point = abs(hit.point - plane.center);
            if (relative_point.x > plane.size.x || relative_point.z > plane.size.z)
                  hit.d = -1.0;
      }

      return hit;
}

// Finds the nearest intersected sphere in the scene
Sphere nearest_intersected_object(Sphere[16] spheres, Ray ray)
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
      {
            nearest_object.radius = 0.0;
            nearest_object.mat.color = vec3(0.0);
      }

      return nearest_object;
}

//The following 3 Funcitons are necessary for PBR feature
vec3 computeDiffuse(Sphere sphere, vec3 N, vec3 L, vec3 F){

      vec3 ks = F;
      vec3 Kd = 1-ks;

      return  Kd * (1-sphere.mat.metallic) * sphere.mat.color * max(dot(N, L), 0);
}

float geometric_attenuation(Sphere sphere, vec3 N, vec3 V, vec3 L)
{
      float alpha = pow(sphere.mat.roughness,2);
      float k = (alpha) / 2;

      // Masking Term
      float Gv = clamp(dot(V, N), 0., 1.) / (clamp(dot(N, V), 0., 1.) * (1-k) + k);
      // Shadowing Term
      float Gl = clamp(dot(L, N), 0., 1.) / (clamp(dot(L, N), 0., 1.) * (1-k) + k);
      
      return Gv * Gl;
}

float microfacet_distribution(Sphere sphere, vec3 N, vec3 H)
{
      float alpha = pow(sphere.mat.roughness,2);
      return pow(alpha, 2) / (PI * pow((pow(max(dot(H, N),0),2) * (pow(alpha,2) - 1) + 1),2));
}


vec3 computePBR(Sphere sphere, Ray ray, Hit hit)
{
      vec3 N = normalize(hit.normal);
      vec3 L = normalize(light_pos.xyz - hit.point);
      vec3 V = normalize(eye_pos-hit.point);
      vec3 H = normalize(L + V);

      vec3 F0_metal;
      vec3 F0_dielectric = vec3(.04,.04,.04);

      // Metals
      if(sphere.mat.mat_type == 1)       F0_metal = vec3(0.56,0.57,0.58);
      else if (sphere.mat.mat_type == 2) F0_metal = vec3(0.95,0.64,0.54);
      else if (sphere.mat.mat_type == 3) F0_metal = vec3(1.00,0.71,0.29);
      else if (sphere.mat.mat_type == 4) F0_metal = vec3(0.91,0.92,0.92);
      else if (sphere.mat.mat_type == 5) F0_metal = vec3(0.95,0.93,0.88);

      vec3 material_color = F0_metal;
      vec3 F0 = mix(F0_dielectric,F0_metal,sphere.mat.metallic);

      vec3 F = F0 + (1 - F0) * pow( (1-clamp(dot(H,V), 0, 1)), 5 );

      float G = geometric_attenuation(sphere, N,V,L);

      float D = microfacet_distribution(sphere, N,H);

      vec3 microfacet = F * D * G;

      vec3 diffuseColor = computeDiffuse(sphere, N, L, F);

      vec3 ambientColor = ambient_intensity * sphere.mat.color;

      vec3 specularColor = microfacet * lightColor;

      return vec3(ambientColor + specularColor + diffuseColor);
}


vec3 pixelColor(Sphere[16] spheres, Plane[1] planes, vec2 pixel)
{
      float reflection = 1.0;
      Ray ray = getRay(pixel);

      Sphere closest_sphere = nearest_intersected_object(spheres, ray);

      Hit[spheres.length] hit_sphere;

      Material hit_material;

      vec3 color = vec3(0.0);
      vec3 final_color = vec3(0.0);
      float shadow_factor = 1.0;
      float distance_to_light = -1.0;
      bool is_shadowed;

      // Number of bounces
      for (int i = 0; i < 10; i++)
      {
            closest_sphere = nearest_intersected_object(spheres, ray);
            Hit closest_object = Hit(INFINITY, vec3(0.0), vec3(0.0));
            Hit hit_ground = planeIntersectPoint(planes[0], ray);
            Hit hit_sphere_obj = sphereIntersectPoint(closest_sphere, ray);

            // Finding hit points for all spheres in scene
            for (int j = 0; j < spheres.length; j++)
            {
                  hit_sphere[j] = sphereIntersectPoint(spheres[j], ray);
            }

            // Set the closest object hit to the plane
            if (hit_ground.d > 0.0)
            {
                  closest_object = hit_ground;
                  hit_material = planes[0].mat;
            }

            // Set the closest object hit to the closest sphere
            for (int j = 0; j < spheres.length; j++)
            {
                  if (hit_sphere[j].d < 0.0)
                        hit_sphere[j].d = INFINITY;

                  if (hit_sphere[j].d < closest_object.d)
                  {
                        closest_object = hit_sphere[j];
                        hit_material = spheres[j].mat;
                  }
            }

            // Slight delta added to hit point to avoid the sphere from hitting itself on next raycast
            vec3 shifted_point = closest_object.point + closest_object.normal * 0.0001;
            if (closest_object.d == INFINITY)
            {
                  color = texture(cubeMapTex, reflect(ray.direction, closest_object.normal)).rgb;
                  final_color += color * shadow_factor * reflection;
                  break;
            }

            // If the closest object ended up being the ground
            if (closest_object.d == hit_ground.d)
            {
                  // Checking if the current spot on the plane is a shadowed area
                  Hit hit_shadow;
                  float min_shadow_distance = INFINITY;
                  Ray light_check;
                  light_check.origin = shifted_point;
                  light_check.direction = normalize(light_pos.xyz - shifted_point);
                  hit_shadow = planeIntersectPoint(planes[0], light_check);
                  for (int j = 0; j < spheres.length; j++)
                  {
                        hit_shadow = sphereIntersectPoint(spheres[j], light_check);
                        if (hit_shadow.d >= 0.0 && hit_shadow.d < min_shadow_distance)
                        {
                              min_shadow_distance = hit_shadow.d;
                              shadow_factor = 0.5;
                              color = vec3(0.0) * shadow_factor * exp(-1.0 / hit_shadow.d);
                              break;
                        }
                  }
            }

            // Sphere lighting and color
            if (closest_object.d == hit_sphere_obj.d)
            {
                  vec3 intersection_to_light = normalize(light_pos.xyz - shifted_point);
                  float intersection_to_light_distance = length(light_pos.xyz - closest_object.point);
                  Ray light_check;
                  light_check.origin = shifted_point;
                  light_check.direction = intersection_to_light;
                  Hit min_distance = sphereIntersectPoint(closest_sphere, light_check);
                  // return normalize(min_distance.point);
                  
                  if (min_distance.d > 0)
                  {
                        distance_to_light = min_distance.d;
                        is_shadowed = true;
                  }
                  
                  
                  vec3 intersection_to_camera = normalize(eye_pos - closest_object.point);
                  vec3 H = normalize(intersection_to_light + intersection_to_camera);

                  color = computePBR(closest_sphere, ray, closest_object);

            }

            // Adding the color
            final_color += color * reflection;
            reflection *= (1 - hit_material.roughness);

            // Setting up the next ray
            ray.origin = shifted_point;
            ray.direction = reflect(ray.direction, closest_object.normal);
      }

      return final_color;
}


void main()
{
      Sphere[16] spheres;
      Plane[1] planes;

      planes[0].center = vec3(0.0, -1.0, 0.0);
      planes[0].size = vec3(10.0, 0.0, 10.0);
      planes[0].normal = vec3(0.0, 1.0, 0.0);
      planes[0].mat.color = vec3(1.0);
      planes[0].mat.metallic = 0.0;
      planes[0].mat.roughness = 0.0001;
      planes[0].mat.mat_type = 1;

      // Defining our spheres
      for (int i = 0; i < 4; i++)
      {
            for (int j = 0; j < 4; j++)
            {
                  spheres[i * 4 + j].radius = 0.25;
                  spheres[i * 4 + j].center = vec3(i * 1.0, -0.75, j * 1.0);
                  // (0, 0), (0, 0.5), (0, 1.0,), (0, 1.5)
                  // (0.5, 0), 
                  spheres[i * 4 + j].mat.color = vec3(0.7, 0.7, 0.0);
                  spheres[i * 4 + j].mat.metallic = 1.0 - clamp((i * 4 + j) / 16.0, 0.0, 1.0); // Decreasing metalness
                  spheres[i * 4 + j].mat.roughness = clamp((i * 4 + j) / 16.0, 0.0001, 1.0); // Increasing roughness
                  spheres[i * 4 + j].mat.mat_type = 1;
            }
      }

      Ray ray = getRay(gl_FragCoord.xy);
      Sphere sphere = nearest_intersected_object(spheres, ray);
      Hit hit = sphereIntersectPoint(sphere, ray);
      vec3 intersection_to_light = normalize(light_pos.xyz - hit.point);
      
      // vec3 final_color = vec3(0.0);
      // for (int i = 0; i < 10; i++)
      // {
      //       final_color += pixelColor(spheres, planes, gl_FragCoord.xy);
      // }
      // final_color /= 10;
      // outColor = vec4(final_color, 1.0);

      outColor = vec4(pixelColor(spheres, planes, gl_FragCoord.xy), 1.0);
}