#define PI 3.1415926535

float FLOAT_MAX = 10e+10;
float FLOAT_MIN = -10e+10;

struct Material{
    vec3 color;
    float kd;   // Diffuse factor
    float ks;   // Diffuse factor
    float kr;   // Reflectivity
};

// Common structures definition
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

struct Light{
    vec3 dir;
    float mag;
    vec3 color;
    vec3 ray;
};

struct Ray{
    vec3 dir;
    vec3 origin;
};

struct Hit{
    float d;
    vec3 point;
    vec3 normal;
};


// Raycasting Functions definition
Hit RayCastPlane(vec3 rayOrigin, vec3 rayDir, inout Plane plane, float delta){
    Hit hit = Hit(-1.0, vec3(0), vec3(0));
    // Move hitpoint by delta to avoid 'acne'
    rayOrigin += delta * plane.normal;
 
    if (rayDir.y != 0.0){
        hit.d = (plane.center.y - rayOrigin.y)/rayDir.y;
        hit.point = rayOrigin + hit.d * rayDir;
        hit.normal = plane.normal;
        
        // Chceck if hitpoint within plane
        vec3 relPoint = abs(hit.point - plane.center);
        if (relPoint.x > plane.size.x || relPoint.z > plane.size.z){
            hit.d = -1.0;
        }
    }
    return hit;
}

Hit RayCastSphere(vec3 rayOrigin, vec3 rayDir, inout Sphere sphere){
    Hit hit = Hit(-1.0, vec3(0), vec3(0));
    
    float a = dot(rayDir, rayDir);
    float b = 2.0 * dot(rayDir, rayOrigin-sphere.center);
    float c = dot(rayOrigin-sphere.center, rayOrigin-sphere.center) - 
                sphere.radius * sphere.radius;
    
    float det = b*b - 4.0*a*c;
    if (det >= 0.0){
        float d1 = (-b-sqrt(det))/2.0*a;
        float d2 = (-b+sqrt(det))/2.0*a;
        hit.d = min(d1,d2);
        hit.point = rayOrigin + hit.d * rayDir;
        hit.normal = normalize(hit.point - sphere.center);
    }
    return hit;
}

float RandFloat(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

vec3 GetLighting(in Material mat, in vec3 normal, in vec3 rayDir, in Light light){
    // Diffuse
    float diff = max(dot(normal, -light.dir), 0.0);
    // Specular
    vec3 reflectDir = -light.dir - 2.0 * normal * dot(-light.dir, normal);
    float spec = pow(max(dot(rayDir, reflectDir), 0.0), mat.ks); 
    // Total
    vec3 col = mat.color * light.color * (diff * mat.kd + spec * mat.kr);
    return col;
}


//--------- Main Function ---------
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    
    // CALCULATIONS BEGIN
    light.dir = normalize(light.dir);
    light.ray = light.dir * light.mag;
    
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = (fragCoord-0.5*iResolution.xy)/iResolution.y;
    
    // View ray
    ray.dir = normalize(vec3(cameraPos.x+uv.x, cameraPos.y+uv.y, 0) - cameraPos);
    
     
    
    vec3 finalCol = vec3(0);
    float reflectivity = 1.0;
    Material hitMat;
    // Iterative Raycast Calculations
    for (int iter=0; iter<R; iter++){

        // Plane distance calculations
        Hit hitGround = RayCastPlane(ray.origin, ray.dir, ground, 0.0);
        // Sphere distance calculations
        Hit[N] hitSphere;
        for (int i=0; i<N; i++){
            hitSphere[i] = RayCastSphere(ray.origin, ray.dir, spheres[i]);
        }

        // Finding closest object to camera
        vec3 col = vec3(0,0,0);
        int hitObj = -1;
        Hit hit = Hit(FLOAT_MAX, vec3(0), vec3(0));
        
        // Minimum distance for ground plane
        if (hitGround.d > 0.0){
            hitObj = 0;
            hit = hitGround;
            // sample ground texture
            vec2 groundTexScale = vec2(0.5);
            ground.mat.color = texture(iChannel1, hitGround.point.xz*groundTexScale).xyz;
            hitMat = ground.mat;
            col = GetLighting(ground.mat, hitGround.normal, ray.dir, light);
        }

        // Minimum distances for all spheres
        for (int i=0; i<N; i++){
            if (hitSphere[i].d < 0.0) hitSphere[i].d = FLOAT_MAX;
            if (hitSphere[i].d < hit.d){
                hitObj = i+1;
                hit = hitSphere[i];
                hitMat = spheres[i].mat;
                col = GetLighting(spheres[i].mat, hitSphere[i].normal, ray.dir, light);
            }
        }
        
        // If no object hit then exit
        if (hit.d == FLOAT_MAX){
            col = texture(iChannel0, ray.dir - 2.0 * hit.normal * dot(ray.dir, hit.normal)).xyz;
            finalCol += col * reflectivity;
            //if (RandFloat(uv) < 0.001)
            //    finalCol = vec3(1,1,1);       
            break;
        }

        // Shadow of ground plane calculation
        Hit hitShadow;
        float minShadowDist = FLOAT_MAX;
        hitShadow = RayCastPlane(hit.point, -light.dir, ground, delta);
        if (hitShadow.d >= 0.0 && hitShadow.d < minShadowDist){
            col = vec3(0) * shadowFactor * exp(-1.0/hitShadow.d);
            minShadowDist = hitShadow.d;
            break;
        }
        // Shadows of all objects calculation
        for (int i=0; i<N; i++){
            hitShadow = RayCastSphere(hit.point + delta*hit.normal, -light.dir, spheres[i]);
            if (hitShadow.d >= 0.0 && hitShadow.d < minShadowDist){
                minShadowDist = hitShadow.d;
                col = hitMat.color * shadowFactor * exp(-1.0/hitShadow.d);
                //col = vec3(1) * 0.1 * exp(-1./hitShadow.d);
                //break;
            }
        }   

        // Final color assignment
        //if (iter == 0)
          //  reflectivity = 1.0;
        //else
          //  reflectivity *= hitMat.kr;

        finalCol += col * reflectivity;
        if (iter == 0)
             finalCol += ambientStrength * ambientLight * hitMat.color;
        reflectivity *= hitMat.kr;
        
        // Change ray
        ray.origin = hit.point + delta*hit.normal;
        ray.dir = ray.dir - 2.0 * hit.normal * dot(ray.dir, hit.normal);
    }

    // d = min(hitGround.d, hitSphere.d);
    // finalCol = vec3(1.0/d);
    
    // Output to screen
    fragColor = vec4(finalCol,1.0);
}