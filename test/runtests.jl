import GLFW
using ModernGL, Compat
function glGenOne(glGenFn)
	id = GLuint[0]
	glGenFn(1, id)
	glCheckError("generating a buffer, array, or texture")
	id[]
end

glGenBuffer() 		= glGenOne(glGenBuffers)
glGenVertexArray() 	= glGenOne(glGenVertexArrays)
glGenTexture() 		= glGenOne(glGenTextures)


function getInfoLog(obj::GLuint)
	# Return the info log for obj, whether it be a shader or a program.
	isShader = glIsShader(obj)
	getiv = isShader == GL_TRUE ? glGetShaderiv : glGetProgramiv
	getInfo = isShader == GL_TRUE ? glGetShaderInfoLog : glGetProgramInfoLog
	# Get the maximum possible length for the descriptive error message
	int::Ptr{GLint} = GLint[0]
	getiv(obj, GL_INFO_LOG_LENGTH, int)
	maxlength = unsafe_load(int)
	# TODO: Create a macro that turns the following into the above:
	# maxlength = @glPointer getiv(obj, GL_INFO_LOG_LENGTH, GLint)
	# Return the text of the message if there is any
	if maxlength > 0
	buffer = zeros(GLchar, maxlength)
	sizei::Ptr{GLsizei} = GLsizei[0]
	getInfo(obj, maxlength, sizei, buffer)
	length = unsafe_load(sizei)
	bytestring(pointer(buffer), length)
	else
	""
	end
end

function validateShader(shader)
	success = GLint[0]
	glGetShaderiv(shader, GL_COMPILE_STATUS, success)
	success[] == GL_TRUE
end

function glErrorMessage()
# Return a string representing the current OpenGL error flag, or the empty string if there's no error.
	err = glGetError()
	err == GL_NO_ERROR ? "" :
	err == GL_INVALID_ENUM ? 					"GL_INVALID_ENUM: An unacceptable value is specified for an enumerated argument. The offending command is ignored and has no other side effect than to set the error flag." :
	err == GL_INVALID_VALUE ? 					"GL_INVALID_VALUE: A numeric argument is out of range. The offending command is ignored and has no other side effect than to set the error flag." :
	err == GL_INVALID_OPERATION ? 				"GL_INVALID_OPERATION: The specified operation is not allowed in the current state. The offending command is ignored and has no other side effect than to set the error flag." :
	err == GL_INVALID_FRAMEBUFFER_OPERATION ? 	"GL_INVALID_FRAMEBUFFER_OPERATION: The framebuffer object is not complete. The offending command is ignored and has no other side effect than to set the error flag." :
	err == GL_OUT_OF_MEMORY ? 					"GL_OUT_OF_MEMORY: There is not enough memory left to execute the command. The state of the GL is undefined, except for the state of the error flags, after this error is recorded." : "Unknown OpenGL error with error code $err."
end

function glCheckError(actionName="")
	message = glErrorMessage()
	if length(message) > 0
		if length(actionName) > 0
		error("Error ", actionName, ": ", message)
		else
		error("Error: ", message)
		end
	end
end

function createShader(source, typ)
	
	# Create the shader
	shader = glCreateShader(typ)::GLuint
	if shader == 0
		error("Error creating shader: ", glErrorMessage())
	end

	# Compile the shader
	glShaderSource(shader, 1, convert(Ptr{Uint8}, pointer([convert(Ptr{GLchar}, pointer(source))])), C_NULL)
	glCompileShader(shader)
	
	# Check for errors
	!validateShader(shader) && error("Shader creation error: ", getInfoLog(shader))
	shader
end
function createShaderProgram(f, vertexShader, fragmentShader)
	# Create, link then return a shader program for the given shaders.
	# Create the shader program
	prog = glCreateProgram()
	if prog == 0
		error("Error creating shader program: ", glErrorMessage())
	end
	# Attach the vertex shader
	glAttachShader(prog, vertexShader)
	glCheckError("attaching vertex shader")
	# Attach the fragment shader
	glAttachShader(prog, fragmentShader)
	glCheckError("attaching fragment shader")
	f(prog)
	# Finally, link the program and check for errors.
	glLinkProgram(prog)
	status = GLint[0]
	glGetProgramiv(prog, GL_LINK_STATUS, status)
	if status[] == GL_FALSE then
		glDeleteProgram(prog)
		error("Error linking shader: ", glGetInfoLog(prog))
	end
	prog
end
createShaderProgram(vertexShader, fragmentShader) = createShaderProgram(prog->0, vertexShader, fragmentShader)
global GLSL_VERSION = ""
function createcontextinfo()
	global GLSL_VERSION
	glsl = split(bytestring(glGetString(GL_SHADING_LANGUAGE_VERSION)), ['.', ' '])
	if length(glsl) >= 2
		glsl = VersionNumber(parse(Int, glsl[1]), parse(Int, glsl[2]))
		GLSL_VERSION = string(glsl.major) * rpad(string(glsl.minor),2,"0")
	else
		error("Unexpected version number string. Please report this bug! GLSL version string: $(glsl)")
	end

	glv = split(bytestring(glGetString(GL_VERSION)), ['.', ' '])
	if length(glv) >= 2
		glv = VersionNumber(parse(Int, glv[1]), parse(Int, glv[2]))
	else
		error("Unexpected version number string. Please report this bug! OpenGL version string: $(glv)")
	end
	dict = @compat(Dict{Symbol,Any}(
	    :glsl_version   => glsl,
	    :gl_version     => glv,
	    :gl_vendor	    => bytestring(glGetString(GL_VENDOR)),
	    :gl_renderer	=> bytestring(glGetString(GL_RENDERER)),
	    #:gl_extensions => split(bytestring(glGetString(GL_EXTENSIONS))),
	))
end
function get_glsl_version_string()
	if isempty(GLSL_VERSION)
	error("couldn't get GLSL version, GLUTils not initialized, or context not created?")
	end
	return "#version $(GLSL_VERSION)\n"
end
GLFW.Init()
#
GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 2)
GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE)
GLFW.WindowHint(GLFW.OPENGL_FORWARD_COMPAT, GL_TRUE)
wh = 600
# Create a windowed mode window and its OpenGL context
window = GLFW.CreateWindow(wh, wh, "OpenGL Example")
# Make the window's context current
GLFW.MakeContextCurrent(window)
GLFW.ShowWindow(window)
GLFW.SetWindowSize(window, wh, wh) # Seems to be necessary to guarantee that window > 0

glViewport(0, 0, wh, wh)
versioninfo()
createcontextinfo()
const vsh = """
$(get_glsl_version_string())
in vec2 position;
void main() {
gl_Position = vec4(position, 0.0, 1.0);
}
"""
const fsh = """
$(get_glsl_version_string())
out vec4 outColor;
void main() {
outColor = vec4(1.0, 1.0, 1.0, 1.0);
}
	"""
function create_data(t)
	# The data for our triangle

	# Create and initialize shaders

	vertexShader 	= createShader(vsh, GL_VERTEX_SHADER)
	fragmentShader 	= createShader(fsh, GL_FRAGMENT_SHADER)
	program 		= createShaderProgram(vertexShader, fragmentShader)
	glUseProgram(0)
	
	data = GLfloat[
	0.0+t, 0.5+t,
	0.5, -0.5,
	-0.5+t,-0.5
	]
	indexes = GLuint[0, 1, 2]
	# Generate a vertex array and array buffer for our data
	vao = glGenVertexArray()
	glBindVertexArray(vao)

	vbo = glGenBuffer()
	glBindBuffer(GL_ARRAY_BUFFER, vbo)
	glBufferData(GL_ARRAY_BUFFER, sizeof(data), data, GL_STATIC_DRAW)

	ibo = glGenBuffer()
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo)
	glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indexes), indexes, GL_STATIC_DRAW)


	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo)
	glBindBuffer(GL_ARRAY_BUFFER, vbo)
	positionAttribute = glGetAttribLocation(program, "position");
	glVertexAttribPointer(positionAttribute, 2, GL_FLOAT, GL_FALSE, 0, C_NULL)
	glEnableVertexAttribArray(positionAttribute)
	glBindVertexArray(0)
	glCheckError("lol ey")
	return vao, program
end


const vertex_arrays = Any[]
t = 0.0f0
# Loop until the user closes the window
while !GLFW.WindowShouldClose(window)
	push!(vertex_arrays, create_data(t))
	t += 0.001f0
	# Pulse the background blue
	glClearColor(0.0, 0.0, 0.5 , 1.0)
	glClear(GL_COLOR_BUFFER_BIT)

	# Draw our triangle
	for (vao, program) in vertex_arrays
		glUseProgram(program)
		glBindVertexArray(vao)
		glDrawElements(GL_TRIANGLES, 3, GL_UNSIGNED_INT, C_NULL)
	end
	# Swap front and back buffers
	GLFW.SwapBuffers(window)
	# Poll for and process events
	GLFW.PollEvents()
end
GLFW.Terminate()
