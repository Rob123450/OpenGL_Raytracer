# Import necessary libraries
import pygame as pg
from OpenGL.GL import *
import numpy as np
import time

from guiV3 import SimpleGUI
from objLoaderV4 import ObjLoader
import shaderLoaderV3
import pyrr
from utils import load_image

# Loads textures
def load_cubemap_texture(filenames):
    # Generate a texture ID
    texture_id = glGenTextures(1)

    # Bind the texture as a cubemap
    glBindTexture(GL_TEXTURE_CUBE_MAP, texture_id)

    # Define texture parameters
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE)
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_NEAREST)
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR)

    # Define the faces of the cubemap
    faces = [GL_TEXTURE_CUBE_MAP_POSITIVE_X, GL_TEXTURE_CUBE_MAP_NEGATIVE_X,
             GL_TEXTURE_CUBE_MAP_POSITIVE_Y, GL_TEXTURE_CUBE_MAP_NEGATIVE_Y,
             GL_TEXTURE_CUBE_MAP_POSITIVE_Z, GL_TEXTURE_CUBE_MAP_NEGATIVE_Z]

    # Load and bind images to the corresponding faces
    for i in range(6):
        img_data, img_w, img_h = load_image(filenames[i], format="RGB", flip=False)
        glTexImage2D(faces[i], 0, GL_RGB, img_w, img_h, 0, GL_RGB, GL_UNSIGNED_BYTE, img_data)

    # Generate mipmaps
    glGenerateMipmap(GL_TEXTURE_CUBE_MAP)

    # Unbind the texture
    glBindTexture(GL_TEXTURE_CUBE_MAP, 0)

    return texture_id

# Does all the vao/vbo related stuff in a function
# Can use this to bind all the buffers for any object drawn in the scene
# Call this one time for each object i.e. a single sphere
def build_buffers(object):
    vao = glGenVertexArrays(1)
    glBindVertexArray(vao)
    vbo = glGenBuffers(1)
    glBindBuffer(GL_ARRAY_BUFFER, vbo)
    glBufferData(GL_ARRAY_BUFFER, object.vertices.nbytes, object.vertices, GL_STATIC_DRAW)

    position_loc = 0
    tex_loc = 1
    normal_loc = 2

    glVertexAttribPointer(position_loc, object.size_position, GL_FLOAT, GL_FALSE, object.stride, ctypes.c_void_p(object.offset_position))
    glVertexAttribPointer(tex_loc, object.size_position, GL_FLOAT, GL_FALSE, object.stride, ctypes.c_void_p(object.offset_texture))
    glVertexAttribPointer(normal_loc, object.size_position, GL_FLOAT, GL_FALSE, object.stride, ctypes.c_void_p(object.offset_normal))

    glEnableVertexAttribArray(position_loc)
    glEnableVertexAttribArray(tex_loc)
    glEnableVertexAttribArray(normal_loc)

    return vao, vbo, object.n_vertices

# Handles keyboard inputs
# Increments or decrements camera rotation inputs
def input_handler():
    global eye
    global camera_forward
    global deltaTime
    global yaw
    global pitch
    pressed_inputs = pg.key.get_pressed()

    cameraSpeed = 2.5 * deltaTime
    mouseSens = 0.5
    if (pressed_inputs[pg.K_w] or pressed_inputs[pg.K_UP]):
        eye += cameraSpeed * camera_forward
    
    if (pressed_inputs[pg.K_s] or pressed_inputs[pg.K_DOWN]):
        eye -= cameraSpeed * camera_forward

    if (pressed_inputs[pg.K_a] or pressed_inputs[pg.K_LEFT]):
        eye -= (np.cross(camera_forward, up)) * cameraSpeed

    if (pressed_inputs[pg.K_d] or pressed_inputs[pg.K_RIGHT]):
        eye += (np.cross(camera_forward, up)) * cameraSpeed

    dx, dy = pg.mouse.get_rel()
    yaw += mouseSens * dx
    pitch -= mouseSens * dy

    if (pitch > 89):
        pitch = 89

    if (pitch < -89):
        pitch = -89

    forward = np.array([0, 0, 0,], dtype=np.float32)
    forward[0] = np.cos(np.radians(yaw)) * np.cos(np.radians(pitch))
    forward[1] = np.sin(np.radians(pitch))
    forward[2] = np.sin(np.radians(yaw)) * np.cos(np.radians(pitch))
    camera_forward = forward
    


# PROGRAM START
# Initialize pygame
pg.init()

# Set up OpenGL context version
pg.display.gl_set_attribute(pg.GL_CONTEXT_MAJOR_VERSION, 3)
pg.display.gl_set_attribute(pg.GL_CONTEXT_MINOR_VERSION, 3)

# Create a window for graphics using OpenGL
# width = 900
# height = 500
width = 1920
height = 1080
pg.display.set_mode((width, height), pg.OPENGL | pg.DOUBLEBUF)


glClearColor(0.3, 0.4, 0.5, 1.0)
glEnable(GL_DEPTH_TEST)


# Write our shaders. We will write our vertex shader and fragment shader in a different file
shaderProgram = shaderLoaderV3.ShaderProgram("shaders/obj/vert.glsl", "shaders/obj/frag.glsl")
shaderProgram_skybox = shaderLoaderV3.ShaderProgram("shaders/skybox/vert.glsl", "shaders/skybox/frag.glsl")
shaderProgram_sphere = shaderLoaderV3.ShaderProgram("shaders/sphere/vert.glsl", "shaders/sphere/frag.glsl")

# Camera parameters
eye = np.array([0,0,6], dtype=np.float32)
camera_forward = np.array([0, 0, -1], dtype=np.float32)
up = np.array([0,1,0], dtype=np.float32)

yaw = -90.0
pitch = 0

fov = 45
aspect = width/height
near = 0.1
far = 100

view_mat  = pyrr.matrix44.create_look_at(eye, camera_forward, up)
projection_mat = pyrr.matrix44.create_perspective_projection_matrix(fov, aspect, near, far)

# light and material properties
material_color = (1.0, 0.1, 0.1)
light_pos = np.array([2, 1, 2, None], dtype=np.float32)
# last component is for light type (0: directional, 1: point) which is changed by radio button
# *************************************************************************


# Lets load our objects
obj = ObjLoader("objects/sphere.obj")
obj_plane = ObjLoader("objects/square.obj")
obj_cube = ObjLoader("objects/cube.obj")

obj_cube_scale = 0.5 / obj_cube.dia

# *********** Lets define model matrix ***********
translation_mat = pyrr.matrix44.create_from_translation(-obj.center)
scaling_mat = pyrr.matrix44.create_from_scale([2 / obj.dia, 2 / obj.dia, 2 / obj.dia])
model_mat = pyrr.matrix44.multiply(scaling_mat, translation_mat)


# *********** Defining light sphere ***********
translation_mat = pyrr.matrix44.create_from_translation(light_pos)
scaling_mat = pyrr.matrix44.create_from_scale([2 / obj.dia, 2 / obj.dia, 2 / obj.dia])
model_mat_light_sphere = pyrr.matrix44.multiply(scaling_mat, translation_mat)

# *********** Defining ground plane ***********
rotation_mat = pyrr.matrix44.create_from_x_rotation(np.deg2rad(90))
translation_mat = pyrr.matrix44.create_from_translation([0, -1, 0])
scaling_mat = pyrr.matrix44.create_from_scale([100, 100, 100])
model_mat_plane = pyrr.matrix44.multiply(scaling_mat, rotation_mat)
model_mat_plane = pyrr.matrix44.multiply(model_mat_plane, translation_mat)

# *********** Defining top wall cube ***********
rotation_mat = pyrr.matrix44.create_from_x_rotation(np.deg2rad(-90))
translation_mat = pyrr.matrix44.create_from_translation([0, 2 + obj_cube_scale, 0])
scaling_mat = pyrr.matrix44.create_from_scale([2, 2, obj_cube_scale])
model_mat_top_plane = pyrr.matrix44.multiply(scaling_mat, rotation_mat)
model_mat_top_plane = pyrr.matrix44.multiply(model_mat_top_plane, translation_mat)

# *********** Defining left wall cube ***********
rotation_mat = pyrr.matrix44.create_from_y_rotation(np.deg2rad(90))
translation_mat = pyrr.matrix44.create_from_translation([-2 + obj_cube_scale, 0, 0])
scaling_mat = pyrr.matrix44.create_from_scale([2, 2, obj_cube_scale])
model_mat_left_plane = pyrr.matrix44.multiply(scaling_mat, rotation_mat)
model_mat_left_plane = pyrr.matrix44.multiply(model_mat_left_plane, translation_mat)

# *********** Defining right wall cube ***********
rotation_mat = pyrr.matrix44.create_from_y_rotation(np.deg2rad(90))
translation_mat = pyrr.matrix44.create_from_translation([2 - obj_cube_scale, 0, 0])
scaling_mat = pyrr.matrix44.create_from_scale([2, 2, obj_cube_scale])
model_mat_right_cube = pyrr.matrix44.multiply(scaling_mat, rotation_mat)
model_mat_right_cube = pyrr.matrix44.multiply(model_mat_right_cube, translation_mat)

# *********** Defining back wall cube ***********
rotation_mat = pyrr.matrix44.create_from_y_rotation(np.deg2rad(0))
translation_mat = pyrr.matrix44.create_from_translation([0, 0, -2 + obj_cube_scale])
scaling_mat = pyrr.matrix44.create_from_scale([2, 2, obj_cube_scale])
model_mat_back_cube = pyrr.matrix44.multiply(scaling_mat, rotation_mat)
model_mat_back_cube = pyrr.matrix44.multiply(model_mat_back_cube, translation_mat)

# ***** Create VAO, VBO, and configure vertex attributes for object 1 *****
# VAO
vao_obj, vbo_obj, n_vertices_obj = build_buffers(obj)
vao_groundPlane, vbo_groundPlane, n_vertices_plane = build_buffers(obj_plane)
vao_topPlane, vbo_topPlane, n_vertices_topPlane = build_buffers(obj_cube)
vao_leftPlane, vbo_leftPlane, n_vertices_leftPlane = build_buffers(obj_cube)
vao_rightCube, vbo_rightCube, n_vertices_rightCube = build_buffers(obj_cube)
vao_backCube, vbo_backCube, n_vertices_backCube = build_buffers(obj_cube)
vao_lightSphere, vbo_lightSphere, n_vertices_lightSphere = build_buffers(obj)
# *************************************************************************
# Loading cubemap
cubemap_images = ["images/skybox1/right.png", "images/skybox1/left.png",
                  "images/skybox1/top.png", "images/skybox1/bottom.png",
                  "images/skybox1/front.png", "images/skybox1/back.png"]
cubemap_id = load_cubemap_texture(cubemap_images)

shaderProgram_skybox["cubeMapTex"] = 0


gui = SimpleGUI("Raytracing")

# Create a slider for the rotation angle around the Z axis
fov_slider = gui.add_slider("fov", 25, 90, 45, resolution=1)


lightY_slider = gui.add_slider("light Y angle", -180, 180, 0, resolution=1)
lightX_slider = gui.add_slider("light X angle", -180, 180, 0, resolution=1)
camY_slider = gui.add_slider("camera Y angle", -180, 180, -32, resolution=1)
camX_slider = gui.add_slider("camera X angle", -90, 90, 13, resolution=1)
camFov_slider = gui.add_slider("field of view", 25, 90, 35, resolution=1)
light_color_slider = gui.add_color_picker(label_text="Light Color", initial_color=(1.0, 1.0, 1.0))
ambient_intensity_slider = gui.add_slider("Ambient Intensity", 0, 1, 0.1, resolution=0.1)
roughness_slider = gui.add_slider("Roughness", 0, 1, 0.5, resolution=0.01)
metallic_slider = gui.add_slider("Metallic", 0, 1, 0.5, resolution=0.01)
material_picker = gui.add_radio_buttons("Material", options_dict={"Iron":1, "Copper":2, "Gold":3, "Aluminum":4, "Silver":5}, initial_option="Gold")

# timing
deltaTime = 0.0
lastFrame = 0.0


# Run a loop to keep the program running
draw = True
while draw:
    for event in pg.event.get():
        if event.type == pg.QUIT:
            draw = False

    # Clear color buffer and depth buffer before drawing each frame
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

    # Rotates light and camera
    currentFrame = time.time()
    deltaTime = currentFrame - lastFrame
    lastFrame = currentFrame

    input_handler()

    view_mat = pyrr.matrix44.create_look_at(eye, eye + camera_forward, up)
    projection_mat = pyrr.matrix44.create_perspective_projection_matrix(fov_slider.get_value(),
                                                                        aspect, near,  far)


    lightYRotation = lightY_slider.get_value()
    lightXRotation = lightX_slider.get_value()
    light_pos[0] = np.cos(np.radians(lightYRotation)) * np.cos(np.radians(lightXRotation))
    light_pos[1] = np.sin(np.radians(lightXRotation))
    light_pos[2] = np.sin(np.radians(lightYRotation)) * np.cos(np.radians(lightXRotation))

    # Set uniforms
    shaderProgram["model_matrix"] = model_mat
    shaderProgram["view_matrix"] = view_mat
    shaderProgram["projection_matrix"] = projection_mat
    shaderProgram["eye_pos"] = eye
    shaderProgram["light_pos"] = light_pos
    shaderProgram["lightColor"] = light_color_slider.get_color()
    shaderProgram["metallic"] = metallic_slider.get_value()
    shaderProgram["roughness"] = roughness_slider.get_value()
    shaderProgram["ambient_intensity"] = ambient_intensity_slider.get_value()
    shaderProgram["mat_type"] = int(material_picker.get_value())
    shaderProgram["center"] = obj.center
    shaderProgram["radius"] = obj.dia / 2

    glUseProgram(shaderProgram_sphere.shader)
    glBindVertexArray(vao_obj)
    shaderProgram_sphere["model_matrix"] = model_mat
    shaderProgram_sphere["view_matrix"] = view_mat
    shaderProgram_sphere["projection_matrix"] = projection_mat
    shaderProgram_sphere["eye_pos"] = eye
    shaderProgram_sphere["light_pos"] = light_pos
    shaderProgram_sphere["lightColor"] = light_color_slider.get_color()
    shaderProgram_sphere["metallic"] = metallic_slider.get_value()
    shaderProgram_sphere["roughness"] = roughness_slider.get_value()
    shaderProgram_sphere["ambient_intensity"] = ambient_intensity_slider.get_value()
    shaderProgram_sphere["mat_type"] = int(material_picker.get_value())
    shaderProgram_sphere["center"] = [0, 0, 0]
    shaderProgram_sphere["radius"] = obj.dia / 2

    glDrawArrays(GL_TRIANGLES, 0, obj.n_vertices)      # draw the object

    glUseProgram(shaderProgram.shader)

    shaderProgram["model_matrix"] = model_mat_plane
    shaderProgram["mat_type"] = 1
    glBindVertexArray(vao_groundPlane)
    glDrawArrays(GL_TRIANGLES, 0, obj_plane.n_vertices)

    # Drawing Top Cube
    shaderProgram["metallic"] = 0.0
    shaderProgram["roughness"] = 1.00
    shaderProgram["mat_type"] = 3
    shaderProgram["model_matrix"] = model_mat_top_plane
    glBindVertexArray(vao_topPlane)
    glDrawArrays(GL_TRIANGLES, 0, obj_cube.n_vertices)

    # Drawing Left Cube
    shaderProgram["metallic"] = 0.0
    shaderProgram["roughness"] = 1.00
    shaderProgram["mat_type"] = 2
    shaderProgram["model_matrix"] = model_mat_left_plane
    glBindVertexArray(vao_leftPlane)
    glDrawArrays(GL_TRIANGLES, 0, obj_cube.n_vertices)

    # Drawing Right Cube
    shaderProgram["metallic"] = 0.0
    shaderProgram["roughness"] = 1.00
    shaderProgram["mat_type"] = 5
    shaderProgram["model_matrix"] = model_mat_right_cube
    glBindVertexArray(vao_rightCube)
    glDrawArrays(GL_TRIANGLES, 0, obj_cube.n_vertices)

    # Drawing Back Cube
    shaderProgram["metallic"] = 0.0
    shaderProgram["roughness"] = 1.00
    shaderProgram["mat_type"] = 4
    shaderProgram["model_matrix"] = model_mat_back_cube
    glBindVertexArray(vao_backCube)
    glDrawArrays(GL_TRIANGLES, 0, obj_cube.n_vertices)

    shaderProgram["metallic"] = 0.0
    shaderProgram["roughness"] = 1.00
    shaderProgram["mat_type"] = 3
    shaderProgram["ambient_intensity"] = 1.0
    translation_mat = pyrr.matrix44.create_from_translation(light_pos)
    scaling_mat = pyrr.matrix44.create_from_scale([0.5 / obj.dia, 0.5 / obj.dia, 0.5 / obj.dia])
    model_mat_light_sphere = pyrr.matrix44.multiply(scaling_mat, translation_mat)
    shaderProgram["model_matrix"] = model_mat_light_sphere
    glBindVertexArray(vao_lightSphere)
    glDrawArrays(GL_TRIANGLES, 0, obj.n_vertices)

    # Drawing the cube map
    # view_mat_without_translation = view_mat.copy()
    # view_mat_without_translation[3][:3] = [0,0,0]

    # # compute the inverse of the view (one without translation)- projection matrix
    # inverseViewProjection_mat = pyrr.matrix44.inverse(pyrr.matrix44.multiply(view_mat_without_translation,projection_mat))
    # glDepthFunc(GL_LEQUAL)
    # glUseProgram(shaderProgram_skybox.shader)
    # shaderProgram_skybox["invViewProjectionMatrix"] = inverseViewProjection_mat
    # glBindVertexArray(vao_quad)
    # glDrawArrays(GL_TRIANGLES, 0, obj_plane.n_vertices)


    # ****************************************************************************************************


    # Refresh the display to show what's been drawn
    pg.display.flip()


# Cleanup
glDeleteVertexArrays(1, [vao_obj, vao_groundPlane])
glDeleteBuffers(1, [vbo_obj, vbo_groundPlane])
glDeleteProgram(shaderProgram.shader)

pg.quit()   # Close the graphics window
quit()      # Exit the program