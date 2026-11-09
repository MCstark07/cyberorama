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

vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

void main() {
    vec2 p = (gl_FragCoord.xy + u_camera) / 80.0;
    vec2 baseCell = floor(p);
    vec2 localPos = fract(p);

    float minDist = 10.0;
    vec2 closestCell = vec2(0.0);

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 seedOffset = hash2(baseCell + neighbor);
            vec2 diff = neighbor + seedOffset - localPos;

            float d = max(abs(diff.x), abs(diff.y));

            if (d < minDist) {
                minDist = d;
                closestCell = baseCell + neighbor;
            }
        }
    }

    vec3 darkBg = vec3(0.05, 0.01, 0.10);
    vec3 neonCyan = vec3(0.0, 0.88, 0.98);
    vec3 col = mix(neonCyan, darkBg, minDist);

    FragColor = vec4(col, 1.0);
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