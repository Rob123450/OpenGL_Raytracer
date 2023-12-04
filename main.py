# Import necessary libraries
import pygame as pg
import pygame.mouse
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
    global focus

    pressed_inputs = pg.key.get_pressed()
    # If the escape button is pressed or mouse is not focused keep camera where it is

    if(pg.mouse.get_focused() and pg.mouse.get_pressed(3)):
        focus = True


    if (pressed_inputs[pg.K_ESCAPE] or focus == False):
        focus = False

    if(focus):
        pygame.mouse.set_pos(screen_center)
        pygame.mouse.set_visible(False)

        cameraSpeed = 2.5 * deltaTime
        mouseSens = 0.2
        if (pressed_inputs[pg.K_w] or pressed_inputs[pg.K_UP]):
            eye += cameraSpeed * camera_forward

        if (pressed_inputs[pg.K_s] or pressed_inputs[pg.K_DOWN]):
            eye -= cameraSpeed * camera_forward

        if (pressed_inputs[pg.K_a] or pressed_inputs[pg.K_LEFT]):
            eye -= (np.cross(camera_forward, up)) * cameraSpeed

        if (pressed_inputs[pg.K_d] or pressed_inputs[pg.K_RIGHT]):
            eye += (np.cross(camera_forward, up)) * cameraSpeed

        dx, dy = pg.mouse.get_rel()
        # reset mouse position to center
        #pygame.mouse.set_pos(screen_center)
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

    else:
        pygame.mouse.set_visible(True)
        eye = eye
        camera_forward = camera_forward
        return


# PROGRAM START
# Initialize pygame
pg.init()

# Set up OpenGL context version
pg.display.gl_set_attribute(pg.GL_CONTEXT_MAJOR_VERSION, 3)
pg.display.gl_set_attribute(pg.GL_CONTEXT_MINOR_VERSION, 3)
pg.display.gl_set_attribute(pg.GL_STENCIL_SIZE, 8)

# Create a window for graphics using OpenGL
# width = 900
# height = 500
width = 1920
height = 1080

screen_center = [width / 2, height / 2]
focus = True

pg.display.set_mode((width, height), pg.OPENGL | pg.DOUBLEBUF)


glClearColor(0.3, 0.4, 0.5, 1.0)
glEnable(GL_DEPTH_TEST)


# Write our shaders. We will write our vertex shader and fragment shader in a different file
shaderProgram = shaderLoaderV3.ShaderProgram("shaders/obj/vert.glsl", "shaders/obj/frag.glsl")
shaderProgram_skybox = shaderLoaderV3.ShaderProgram("shaders/skybox/vert.glsl", "shaders/skybox/frag.glsl")
shaderProgram_sphere = shaderLoaderV3.ShaderProgram("shaders/sphere/vert.glsl", "shaders/sphere/frag.glsl")

# Camera parameters
eye = np.array([0,0,3], dtype=np.float32)
target = (0, 0, 0)
camera_forward = np.array([0, 0, -1], dtype=np.float32)
up = np.array([0,1,0], dtype=np.float32)

yaw = -90.0
pitch = 0

fov = 45
aspect = width/height
near = 0.1
far = 100

quad_vertices = (
            # Position
            -1, -1,
             1, -1,
             1,  1,
             1,  1,
            -1,  1,
            -1, -1
)
vertices = np.array(quad_vertices, dtype=np.float32)

quad_n_vertices = len(vertices) // 2

vao_quad = glGenVertexArrays(1)
glBindVertexArray(vao_quad)
vbo_quad = glGenBuffers(1)
glBindBuffer(GL_ARRAY_BUFFER, vbo_quad)
glBufferData(GL_ARRAY_BUFFER, vertices.nbytes, vertices, GL_STATIC_DRAW)

position_loc = 0
glBindAttribLocation(shaderProgram_skybox.shader, position_loc, "position")
glVertexAttribPointer(position_loc, 2, GL_FLOAT, GL_FALSE, 8, ctypes.c_void_p(0))
glEnableVertexAttribArray(position_loc)

cube_map_images = ['images/skybox1/right.png', 'images/skybox1/left.png',
                   'images/skybox1/top.png', 'images/skybox1/bottom.png',
                   'images/skybox1/front.png', 'images/skybox1/back.png']

skybox_id = load_cubemap_texture(cube_map_images)

shaderProgram_skybox['cubeMapTex'] = 0



# light and material properties
material_color = (1.0, 0.1, 0.1)
light_pos = np.array([-10, 10, -10, None], dtype=np.float32)
# last component is for light type (0: directional, 1: point) which is changed by radio button
# *************************************************************************
# Obj and attributes
obj = ObjLoader("objects/square.obj")
vao_obj, vbo_obj, n_vertices_obj = build_buffers(obj)

# matrices
#model_mat = pyrr.matrix44.create_from_translation(-obj.center)
scaling_mat = pyrr.matrix44.create_from_scale(pyrr.Vector3([0.5, 0.5, 0.5]))
#model_mat = pyrr.matrix44.multiply(model_mat, scaling_mat)
model_mat = scaling_mat


# *************************************************************************

gui = SimpleGUI("Raytracing")

# Create a slider for the rotation angle around the Z axis
fov_slider = gui.add_slider("fov", 25, 90, 90, resolution=1)
light_rot_check = gui.add_checkbox("Light Movement", initial_state=True)

lightY_slider = gui.add_slider("light Y angle", -180, 180, 0, resolution=1)
lightX_slider = gui.add_slider("light X angle", -180, 180, 0, resolution=1)
camY_slider = gui.add_slider("camera Y angle", -180, 180, 0, resolution=1)
camX_slider = gui.add_slider("camera X angle", -180, 180, 0, resolution=1)
light_color_slider = gui.add_color_picker(label_text="Light Color", initial_color=(1.0, 1.0, 1.0))
ambient_intensity_slider = gui.add_slider("Ambient Intensity", 0, 1, 0.1, resolution=0.1)
roughness_slider = gui.add_slider("Roughness", 0, 1, 0.5, resolution=0.01)
metallic_slider = gui.add_slider("Metallic", 0, 1, 0.5, resolution=0.01)
material_picker = gui.add_radio_buttons("Material", options_dict={"Iron":1, "Copper":2, "Gold":3, "Aluminum":4, "Silver":5}, initial_option="Gold")

# timing
deltaTime = 0.0
lastFrame = 0.0
timer = 0.0

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

    timer += 0.01;

    input_handler()


    #rotateX_mat = pyrr.matrix44.create_from_x_rotation(np.deg2rad(camX_slider.get_value()))
    #rotation_mat = pyrr.matrix44.multiply(rotateX_mat, rotateY_mat)
    #rotated_eye = pyrr.matrix44.apply_to_vector(rotation_mat, eye)



    view_mat = pyrr.matrix44.create_look_at(eye, eye + camera_forward, up)
    projection_mat = pyrr.matrix44.create_perspective_projection_matrix(fov_slider.get_value(), aspect, near,  far)

    view_mat_without_translation = view_mat.copy()
    view_mat_without_translation[3][:3] = [0, 0, 0]

    inverseViewProjection_mat = pyrr.matrix44.inverse(pyrr.matrix44.multiply(view_mat_without_translation, projection_mat))

    #view_mat = pyrr.matrix44.create_look_at(eye, target, up)
    #projection_mat = pyrr.matrix44.create_perspective_projection_matrix(fov_slider.get_value(),
                                                                        #aspect, near,  far)


    lightYRotation = lightY_slider.get_value()
    lightXRotation = lightX_slider.get_value()

    if (light_rot_check.get_value()):
        light_pos[0] = 20 * np.sin(timer * 0.1)
        light_pos[2] = 20 * np.cos(timer * 0.1)

    # Set uniforms
    # Set the uniform variables
    shaderProgram_sphere["model_matrix"] = model_mat
    shaderProgram_sphere["light_pos"] = light_pos
    shaderProgram_sphere["eye_pos"] = eye
    shaderProgram_sphere["fov"] = np.deg2rad(fov_slider.get_value())

    # min and max bounds (coordinates) of Axis Aligned Bounding Box
    shaderProgram_sphere["minBound"] = (-0.5, -0.5, -0.5)
    shaderProgram_sphere["maxBound"] = (0.5, 0.5, 0.5)

    shaderProgram_sphere["cameraU"] = pyrr.Vector3([view_mat[0][0], view_mat[1][0], view_mat[2][0]])
    shaderProgram_sphere["cameraV"] = pyrr.Vector3([view_mat[0][1], view_mat[1][1], view_mat[2][1]])
    shaderProgram_sphere["cameraW"] = pyrr.Vector3([view_mat[0][2], view_mat[1][2], view_mat[2][2]])

    shaderProgram_sphere["resolution"] = np.array([width, height], dtype=np.float32)

    shaderProgram_sphere["ambient_intensity"] = ambient_intensity_slider.get_value()
    shaderProgram_sphere["lightColor"] = [1.0, 1.0, 1.0]

    glActiveTexture(GL_TEXTURE0)
    glBindTexture(GL_TEXTURE_CUBE_MAP, skybox_id)

    glUseProgram(shaderProgram_sphere.shader)
    glBindVertexArray(vao_obj)
    glDrawArrays(GL_TRIANGLES, 0, obj.n_vertices)      # draw the object


    glDepthFunc(GL_LEQUAL)
    glUseProgram(shaderProgram_skybox.shader)
    shaderProgram_skybox["inViewProjectionMatrix"] = inverseViewProjection_mat
    glBindVertexArray(vao_quad)
    glDrawArrays(GL_TRIANGLES, 0, quad_n_vertices)

    glDepthFunc(GL_LESS)


    # ****************************************************************************************************


    # Refresh the display to show what's been drawn
    pg.display.flip()


# Cleanup
glDeleteVertexArrays(1, [vao_obj, vao_quad])
glDeleteBuffers(1, [vbo_obj, vbo_obj])
glDeleteProgram(shaderProgram.shader)
glDeleteProgram(shaderProgram_skybox.shader)
glDeleteProgram(shaderProgram_sphere.shader)

pg.quit()   # Close the graphics window
quit()      # Exit the program