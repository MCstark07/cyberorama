#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <iostream>

using namespace std;

const char* vertexShaderSource = R"(
#version 330 core
layout (location = 0) in vec2 aPos;
void main()
{
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
    if (pattern == 0.0)
    {
        FragColor = vec4(0.06, 0.02, 0.12, 1.0);
    }
    else
    {
        FragColor = vec4(0.0, 0.85, 0.95, 1.0);
    }
}
)";

int main()
{
    glfwInit();
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    GLFWwindow* window = glfwCreateWindow(1200, 800, "cyberorama", nullptr, nullptr);
    if (window == nullptr) {
        cout << "Failed to create GLFW window\n";
        glfwTerminate();
        return -1;
    }

    glfwMakeContextCurrent(window);
    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) {
        std::cout << "Failed to initialize GLAD\n";
        return -1;
    }

    unsigned int vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexShaderSource, nullptr);
    glCompileShader(vertexShader);

    unsigned int fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentShaderSource, nullptr);
    glCompileShader(fragmentShader);

    unsigned int shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);

    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    float quadVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        1.0f,  1.0f,

        -1.0f, -1.0f,
        1.0f,  1.0f,
        -1.0f,  1.0f
    };

    unsigned int VAO, VBO;
    glGenVertexArrays(1, &VAO);
    glGenBuffers(1, &VBO);

    glBindVertexArray(VAO);
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quadVertices), quadVertices, GL_STATIC_DRAW);

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);

    float camX = 0.0f;
    float camY = 0.0f;
    int camUniformLoc = glGetUniformLocation(shaderProgram, "u_camera");

    while (!glfwWindowShouldClose(window)) {
        glClearColor(0.06f, 0.02f, 0.12f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        if (glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS) camX += 5.0f;
        if (glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS) camX -= 5.0f;
        if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS) camY += 5.0f;
        if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS) camY -= 5.0f;

        glUseProgram(shaderProgram);
        glUniform2f(camUniformLoc, camX, camY);
        glBindVertexArray(VAO);
        glDrawArrays(GL_TRIANGLES, 0, 6);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    glfwTerminate();
    return 0;
}