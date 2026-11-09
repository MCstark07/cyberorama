#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <iostream>

using namespace std;

const char* vertexShaderSource = R"(
#version 330 core
layout (location = 0) in vec2 aPos;
void main() {
    gl_Position = vec4(aPos.x, aPos.y, 0.0, 1.0);
}
)";

const char* fragmentShaderSource = R"(
#version 330 core
out vec4 FragColor;
uniform vec2 u_camera;

void main() {
    vec2 worldPos = gl_FragCoord.xy + u_camera;
    vec2 cell = floor(worldPos / 40.0);
    float pattern = mod(cell.x + cell.y, 2.0);
    if (pattern == 0.0) {
        FragColor = vec4(0.06, 0.02, 0.12, 1.0);
    } else {
        FragColor = vec4(0.0, 0.85, 0.95, 1.0);
    }
}
)";

int main() {
    glfwInit();
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    GLFWwindow* window = glfwCreateWindow(1200, 800, "cyberorama", nullptr, nullptr);
    if (!window) {
        cout << "Failed to create GLFW window\n";
        glfwTerminate();
        return -1;
    }

    glfwMakeContextCurrent(window);
    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) {
        cout << "Failed to initialize GLAD\n";
        return -1;
    }

    unsigned int vert = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vert, 1, &vertexShaderSource, nullptr);
    glCompileShader(vert);

    unsigned int frag = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(frag, 1, &fragmentShaderSource, nullptr);
    glCompileShader(frag);

    unsigned int shader = glCreateProgram();
    glAttachShader(shader, vert);
    glAttachShader(shader, frag);
    glLinkProgram(shader);

    glDeleteShader(vert);
    glDeleteShader(frag);

    float quad[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        1.0f,  1.0f,
        -1.0f, -1.0f,
        1.0f,  1.0f,
        -1.0f,  1.0f
    };

    unsigned int vao, vbo;
    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);

    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quad), quad, GL_STATIC_DRAW);

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);

    float camX = 0.0f;
    float camY = 0.0f;
    int camLoc = glGetUniformLocation(shader, "u_camera");

    double lastTime = glfwGetTime();
    bool dragging = false;
    double lastX = 0.0, lastY = 0.0;

    while (!glfwWindowShouldClose(window)) {
        double now = glfwGetTime();
        float dt = (float)(now - lastTime);
        lastTime = now;

        glClearColor(0.06f, 0.02f, 0.12f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        float speed = 150.0f * dt;
        if (glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS) camX += speed;
        if (glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS) camX -= speed;
        if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS) camY += speed;
        if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS) camY -= speed;

        if (glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_LEFT) == GLFW_PRESS) {
            double mx, my;
            glfwGetCursorPos(window, &mx, &my);
            if (!dragging) {
                dragging = true;
                lastX = mx;
                lastY = my;
            } else {
                camX -= (float)(mx - lastX);
                camY += (float)(my - lastY);
                lastX = mx;
                lastY = my;
            }
        } else {
            dragging = false;
        }

        glUseProgram(shader);
        glUniform2f(camLoc, camX, camY);
        glBindVertexArray(vao);
        glDrawArrays(GL_TRIANGLES, 0, 6);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    glfwTerminate();
    return 0;
}