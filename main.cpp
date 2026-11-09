#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <iostream>
#include <fstream>
#include <sstream>
#include <string>

using namespace std;

const char* vertexShaderSource = R"(
#version 330 core
layout (location = 0) in vec2 aPos;
void main() {
    gl_Position = vec4(aPos.x, aPos.y, 0.0, 1.0);
}
)";

string readFile(const string& path) {
    ifstream f(path);
    if (!f) {
        cout << "Cannot open " << path << "\n";
        return "";
    }
    stringstream ss;
    ss << f.rdbuf();
    return ss.str();
}

unsigned int buildProgram() {
    string header =
        "#version 330 core\n"
        "out vec4 FragColor;\n"
        "uniform vec2 u_camera;\n"
        "uniform float u_time;\n";
    string fragSrc = header + readFile("nodes.glsl") + "\n" + readFile("main.frag");
    const char* fsrc = fragSrc.c_str();

    int ok;
    char log[2048];

    unsigned int vert = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vert, 1, &vertexShaderSource, nullptr);
    glCompileShader(vert);
    glGetShaderiv(vert, GL_COMPILE_STATUS, &ok);
    if (!ok) { glGetShaderInfoLog(vert, 2048, nullptr, log); cout << "VERTEX ERROR:\n" << log << "\n"; }

    unsigned int frag = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(frag, 1, &fsrc, nullptr);
    glCompileShader(frag);
    glGetShaderiv(frag, GL_COMPILE_STATUS, &ok);
    if (!ok) { glGetShaderInfoLog(frag, 2048, nullptr, log); cout << "FRAGMENT ERROR:\n" << log << "\n"; }

    unsigned int prog = glCreateProgram();
    glAttachShader(prog, vert);
    glAttachShader(prog, frag);
    glLinkProgram(prog);
    glGetProgramiv(prog, GL_LINK_STATUS, &ok);
    if (!ok) { glGetProgramInfoLog(prog, 2048, nullptr, log); cout << "LINK ERROR:\n" << log << "\n"; }

    glDeleteShader(vert);
    glDeleteShader(frag);
    return prog;
}

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

    unsigned int shader = buildProgram();

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
    int timeLoc = glGetUniformLocation(shader, "u_time");

    double lastTime = glfwGetTime();
    bool dragging = false;
    double lastX = 0.0, lastY = 0.0;
    bool rWasDown = false;

    while (!glfwWindowShouldClose(window)) {
        double now = glfwGetTime();
        float dt = (float)(now - lastTime);
        lastTime = now;

        bool rDown = glfwGetKey(window, GLFW_KEY_R) == GLFW_PRESS;
        if (rDown && !rWasDown) {
            glDeleteProgram(shader);
            shader = buildProgram();
            camLoc = glGetUniformLocation(shader, "u_camera");
            timeLoc = glGetUniformLocation(shader, "u_time");
            cout << "Reloaded shader\n";
        }
        rWasDown = rDown;

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
        glUniform1f(timeLoc, (float)now);
        glBindVertexArray(vao);
        glDrawArrays(GL_TRIANGLES, 0, 6);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    glfwTerminate();
    return 0;
}
