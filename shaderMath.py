import numpy as np
import random

def uniform_random(a, b):
    return a + random.random() * (b - a)

def vector_length(vec):
    return np.sqrt(np.dot(vec, vec))

def normalize(vec):
    vec_as_array = np.array(vec)
    return (1.0 / vector_length(vec_as_array)) * vec_as_array

def get_vector_in_hemisphere(normal):
    b3 = normalize(normal)
    different = [1.0, 0.0, 0.0] if np.abs(b3[2]) < 0.5 else [0.0, 1.0, 0.0]
    b1 = normalize(np.cross(b3, different))
    b2 = np.cross(b1, b3)
    
    z = uniform_random(np.cos(0.5 * np.pi), 1)
    theta = uniform_random(-np.pi, np.pi)
    x = np.sqrt(1 - z * z) * np.cos(theta)
    y = np.sqrt(1 - z * z) * np.sin(theta)
    return x * b1 + y * b2 + z * b3

class ShaderMath:
    None