# Import necessary libraries
import pygame as pg
from OpenGL.GL import *
import numpy as np
import time

from guiV3 import SimpleGUI
from objLoaderV4 import ObjLoader
import shaderLoaderV3
import pyrr

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
    pressed_inputs = pg.key.get_pressed()

    cameraSpeed = 2.5 * deltaTime
    if (pressed_inputs[pg.K_w] or pressed_inputs[pg.K_UP]):
        eye += cameraSpeed * camera_forward
    
    if (pressed_inputs[pg.K_s] or pressed_inputs[pg.K_DOWN]):
        eye -= cameraSpeed * camera_forward

    if (pressed_inputs[pg.K_a] or pressed_inputs[pg.K_LEFT]):
        eye -= (np.cross(camera_forward, up)) * cameraSpeed

    if (pressed_inputs[pg.K_d] or pressed_inputs[pg.K_RIGHT]):
        eye += (np.cross(camera_forward, up)) * cameraSpeed


# PROGRAM START
# Initialize pygame
pg.init()

# Set up OpenGL context version
pg.display.gl_set_attribute(pg.GL_CONTEXT_MAJOR_VERSION, 3)
pg.display.gl_set_attribute(pg.GL_CONTEXT_MINOR_VERSION, 3)

# Create a window for graphics using OpenGL
width = 900
height = 500
pg.display.set_mode((width, height), pg.OPENGL | pg.DOUBLEBUF)


glClearColor(0.3, 0.4, 0.5, 1.0)
glEnable(GL_DEPTH_TEST)


# Write our shaders. We will write our vertex shader and fragment shader in a different file
shaderProgram = shaderLoaderV3.ShaderProgram("shaders/vert.glsl", "shaders/frag.glsl")

# Camera parameters
eye = np.array([0,0,6], dtype=np.float32)
camera_forward = np.array([0, 0, -1], dtype=np.float32)
up = np.array([0,1,0], dtype=np.float32)

fov = 45
aspect = width/height
near = 2
far = 20

view_mat  = pyrr.matrix44.create_look_at(eye, camera_forward, up)
projection_mat = pyrr.matrix44.create_perspective_projection_matrix(fov, aspect, near, far)

# light and material properties
material_color = (1.0, 0.1, 0.1)
light_pos = np.array([2, 2, 2, None], dtype=np.float32)
# last component is for light type (0: directional, 1: point) which is changed by radio button
# *************************************************************************


# Lets load our objects
obj = ObjLoader("objects/sphere.obj")
obj_plane = ObjLoader("objects/square.obj")


# *********** Lets define model matrix ***********
translation_mat = pyrr.matrix44.create_from_translation(-obj.center)
scaling_mat = pyrr.matrix44.create_from_scale([2 / obj.dia, 2 / obj.dia, 2 / obj.dia])
model_mat = pyrr.matrix44.multiply(translation_mat, scaling_mat)

# *********** Defining quad matrix ***********
rotation_mat = pyrr.matrix44.create_from_x_rotation(np.deg2rad(90))
translation_mat = pyrr.matrix44.create_from_translation([0, -1, 0])
scaling_mat = pyrr.matrix44.create_from_scale([2, 2, 2])
model_mat_plane = pyrr.matrix44.multiply(scaling_mat, rotation_mat)
model_mat_plane = pyrr.matrix44.multiply(model_mat_plane, translation_mat)



# ***** Create VAO, VBO, and configure vertex attributes for object 1 *****
# VAO
vao_obj, vbo_obj, n_vertices_obj = build_buffers(obj)
vao_plane, vbo_plane, n_vertices_plane = build_buffers(obj_plane)
# *************************************************************************



gui = SimpleGUI("Assignment 7")

# Create a slider for the rotation angle around the Z axis
fov_slider = gui.add_slider("fov", 25, 90, 45, resolution=1)


material_color_picker = gui.add_color_picker("material color", initial_color=material_color)
light_type_radio_button = gui.add_radio_buttons("light type", options_dict={"point":1, "directional":0}, initial_option="point")

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

    # Rotates the light over time, uses same sin, cos and ShaderToy example with a smaller coefficient
    #light_pos = np.array([np.sin(timer*0.1), 1, np.cos(timer*0.1), None], dtype=np.float32)
    light_pos[3] = light_type_radio_button.get_value()

    # Set uniforms
    shaderProgram["model_matrix"] = model_mat
    shaderProgram["view_matrix"] = view_mat
    shaderProgram["projection_matrix"] = projection_mat
    shaderProgram["eye_pos"] = eye
    shaderProgram["material_color"] = material_color_picker.get_color()
    shaderProgram["light_pos"] = light_pos

    glUseProgram(shaderProgram.shader)

    glBindVertexArray(vao_obj)
    glDrawArrays(GL_TRIANGLES,0, obj.n_vertices)      # draw the object

    shaderProgram["model_matrix"] = model_mat_plane
    glBindVertexArray(vao_plane)
    glDrawArrays(GL_TRIANGLES, 0, obj.n_vertices)
    # ****************************************************************************************************


    # Refresh the display to show what's been drawn
    pg.display.flip()


# Cleanup
glDeleteVertexArrays(1, [vao_obj, vao_plane])
glDeleteBuffers(1, [vbo_obj, vbo_plane])
glDeleteProgram(shaderProgram.shader)

pg.quit()   # Close the graphics window
quit()      # Exit the program