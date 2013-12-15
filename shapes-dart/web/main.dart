library shapes;

import 'dart:html';
import 'package:vector_math/vector_math.dart' as v;
import 'dart:web_gl' as webgl;
import 'dart:typed_data';


class Shapes {
  CanvasElement _canvas;
  webgl.RenderingContext _gl;
  webgl.Program _shaderProgram;

  webgl.Buffer _pyramidVertexPositionBuffer;
  webgl.Buffer _pyramidVertexColorBuffer;

  webgl.Buffer _cubeVertexPositionBuffer;
  webgl.Buffer _cubeVertexColorBuffer;
  webgl.Buffer _cubeVertexIndexBuffer;

  int _viewportWidth;
  int _viewportHeight;

  v.Matrix4 _pMatrix;
  v.Matrix4 _mvMatrix;
  Queue<v.Matrix4> _mvMatrixStack = [];

  int _aVertexPosition;
  int _aVertexColor;
  webgl.UniformLocation _uPMatrix;
  webgl.UniformLocation _uMVMatrix;

  double _rPyramid = 0.0;
  double _rCube = 0.0;

  Shapes(CanvasElement canvas) {
    _viewportWidth = canvas.width;
    _viewportHeight = canvas.height;

    _gl = canvas.getContext('webgl');

    _initShaders();
    _initBuffers();

    _gl.clearColor(0.6, 0.4, 0.6, 1.0);
    _gl.enable(webgl.RenderingContext.DEPTH_TEST);
  }

  webgl.Shader getShader(id) {
    Element el = document.querySelector('#$id');
    String src = el.text;
    String type = el.attributes['type'].split('x-shader/')[1];
    webgl.Shader shader;

    if (type == 'x-fragment') {
      shader = _gl.createShader(webgl.RenderingContext.FRAGMENT_SHADER);
    } else if (type == 'x-vertex') {
      shader = _gl.createShader(webgl.RenderingContext.VERTEX_SHADER);
    } else {
        throw new StateError('Invalid type $type');
    }

    _gl.shaderSource(shader, src);
    _gl.compileShader(shader);

    return shader;
  }

  void _initShaders() {
    final webgl.Shader fragmentShader = getShader('shader-fs');
    final webgl.Shader vertexShader = getShader('shader-vs');

    _shaderProgram = _gl.createProgram();
    _gl.attachShader(_shaderProgram, fragmentShader);
    _gl.attachShader(_shaderProgram, vertexShader);
    _gl.linkProgram(_shaderProgram);
    _gl.useProgram(_shaderProgram);

    if (!_gl.getShaderParameter(vertexShader,
          webgl.RenderingContext.COMPILE_STATUS)) {
      throw new StateError(_gl.getShaderInfoLog(vertexShader));
    }

    if (!_gl.getShaderParameter(fragmentShader,
          webgl.RenderingContext.COMPILE_STATUS)) {
      throw new StateError(_gl.getShaderInfoLog(fragmentShader));
    }

    if (!_gl.getProgramParameter(_shaderProgram,
          webgl.RenderingContext.LINK_STATUS)) {
      throw new StateError(_gl.getProgramInfoLog(_shaderProgram));
    }

    _aVertexPosition = _gl.getAttribLocation(_shaderProgram, 'aVertexPosition');
    _gl.enableVertexAttribArray(_aVertexPosition);

    _aVertexColor = _gl.getAttribLocation(_shaderProgram, 'aVertexColor');
    _gl.enableVertexAttribArray(_aVertexColor);

    _uPMatrix = _gl.getUniformLocation(_shaderProgram, 'uPMatrix');
    _uMVMatrix = _gl.getUniformLocation(_shaderProgram, 'uMVMatrix');
  }

  void _initBuffers() {
    List<double> vertices;

    // create triangle
    _pyramidVertexPositionBuffer = _gl.createBuffer();
    _gl.bindBuffer(webgl.RenderingContext.ARRAY_BUFFER, _pyramidVertexPositionBuffer);

    vertices = [
        // Front face
        0.0,  1.0,  0.0,
        -1.0, -1.0,  1.0,
        1.0, -1.0,  1.0,
        // Right face
        0.0,  1.0,  0.0,
        1.0, -1.0,  1.0,
        1.0, -1.0, -1.0,
        // Back face
        0.0,  1.0,  0.0,
        1.0, -1.0, -1.0,
        -1.0, -1.0, -1.0,
        // Left face
        0.0,  1.0,  0.0,
        -1.0, -1.0, -1.0,
        -1.0, -1.0,  1.0
    ];
    _gl.bufferDataTyped(
        webgl.RenderingContext.ARRAY_BUFFER,
        new Float32List.fromList(vertices),
        webgl.RenderingContext.STATIC_DRAW);

    _pyramidVertexColorBuffer = _gl.createBuffer();
    _gl.bindBuffer(webgl.RenderingContext.ARRAY_BUFFER, _pyramidVertexColorBuffer);
    List<double> colors1 = [
        // Front face
        1.0, 0.0, 0.0, 1.0,
        0.0, 1.0, 0.0, 1.0,
        0.0, 0.0, 1.0, 1.0,
        // Right face
        1.0, 0.0, 0.0, 1.0,
        0.0, 0.0, 1.0, 1.0,
        0.0, 1.0, 0.0, 1.0,
        // Back face
        1.0, 0.0, 0.0, 1.0,
        0.0, 1.0, 0.0, 1.0,
        0.0, 0.0, 1.0, 1.0,
        // Left face
        1.0, 0.0, 0.0, 1.0,
        0.0, 0.0, 1.0, 1.0,
        0.0, 1.0, 0.0, 1.0
    ];
    _gl.bufferDataTyped(
        webgl.RenderingContext.ARRAY_BUFFER,
        new Float32List.fromList(colors1),
        webgl.RenderingContext.STATIC_DRAW
    );

    // create square
    _cubeVertexPositionBuffer = _gl.createBuffer();
    _gl.bindBuffer(webgl.RenderingContext.ARRAY_BUFFER, _cubeVertexPositionBuffer);

    vertices = [
        // Front face
        -1.0, -1.0,  1.0,
        1.0, -1.0,  1.0,
        1.0,  1.0,  1.0,
        -1.0,  1.0,  1.0,

        // Back face
        -1.0, -1.0, -1.0,
        -1.0,  1.0, -1.0,
        1.0,  1.0, -1.0,
        1.0, -1.0, -1.0,

        // Top face
        -1.0,  1.0, -1.0,
        -1.0,  1.0,  1.0,
        1.0,  1.0,  1.0,
        1.0,  1.0, -1.0,

        // Bottom face
        -1.0, -1.0, -1.0,
        1.0, -1.0, -1.0,
        1.0, -1.0,  1.0,
        -1.0, -1.0,  1.0,

        // Right face
        1.0, -1.0, -1.0,
        1.0,  1.0, -1.0,
        1.0,  1.0,  1.0,
        1.0, -1.0,  1.0,

        // Left face
        -1.0, -1.0, -1.0,
        -1.0, -1.0,  1.0,
        -1.0,  1.0,  1.0,
        -1.0,  1.0, -1.0,
    ];
    _gl.bufferDataTyped(
        webgl.RenderingContext.ARRAY_BUFFER,
        new Float32List.fromList(vertices),
        webgl.RenderingContext.STATIC_DRAW);

    _cubeVertexColorBuffer = _gl.createBuffer();
    _gl.bindBuffer(webgl.RenderingContext.ARRAY_BUFFER, _cubeVertexColorBuffer);
    List<List<double>> colors2 = [
        [1.0, 0.0, 0.0, 1.0],  // Front face
        [1.0, 1.0, 0.0, 1.0],  // Back face
        [0.0, 1.0, 0.0, 1.0],  // Top face
        [1.0, 0.5, 0.5, 1.0],  // Bottom face
        [1.0, 0.0, 1.0, 1.0],  // Right face
        [0.0, 0.0, 1.0, 1.0],  // Left face
    ];

    // each cube face (6 faces for one cube) consists of 4 points of the same color
    // where each color has 4 components RGBA therefore I need 4 * 4 * 6 long list of doubles
    List<double> unpackedColors = new List.generate(4 * 4 * colors2.length, (int index) {
      // index ~/ 16 returns 0-5
      // index % 4 returns 0-3 that's color component for each color
      return colors2[index ~/ 16][index % 4];
    }, growable: false);
    _gl.bufferDataTyped(
        webgl.RenderingContext.ARRAY_BUFFER,
        new Float32List.fromList(unpackedColors),
        webgl.RenderingContext.STATIC_DRAW);

    _cubeVertexIndexBuffer = _gl.createBuffer();
    _gl.bindBuffer(webgl.RenderingContext.ELEMENT_ARRAY_BUFFER, _cubeVertexIndexBuffer);
    List<int> _cubeVertexIndices = [
        0,  1,  2,    0,  2,  3, // Front face
        4,  5,  6,    4,  6,  7, // Back face
        8,  9, 10,    8, 10, 11, // Top face
        12, 13, 14,   12, 14, 15, // Bottom face
        16, 17, 18,   16, 18, 19, // Right face
        20, 21, 22,   20, 22, 23  // Left face
    ];
    _gl.bufferDataTyped(
        webgl.RenderingContext.ELEMENT_ARRAY_BUFFER,
        new Uint16List.fromList(_cubeVertexIndices),
        webgl.RenderingContext.STATIC_DRAW);
  }

  void _setMatrixUniforms() {
    Float32List tmpList = new Float32List(16);

    _pMatrix.copyIntoArray(tmpList);
    _gl.uniformMatrix4fv(_uPMatrix, false, tmpList);

    _mvMatrix.copyIntoArray(tmpList);
    _gl.uniformMatrix4fv(_uMVMatrix, false, tmpList);
  }

  void _mvPushMatrix() {
    // Object allocation in the render loop. What could possibly go wrong?
    _mvMatrixStack.add(_mvMatrix.clone());
  }

  void _mvPopMatrix() {
    if (_mvMatrixStack.length == 0) {
      throw new StateError('Invalid popMatrix state.');
    }

    _mvMatrix = _mvMatrixStack.removeLast();
  }

  void tick([num delta = 0]) {
    render();
    animate(delta);
    window.animationFrame.then(tick);
  }

  void render() {
    _gl.viewport(0, 0, _viewportWidth, _viewportHeight);
    _gl.clear(webgl.RenderingContext.COLOR_BUFFER_BIT | webgl.RenderingContext.DEPTH_BUFFER_BIT);

    _pMatrix = v.makePerspectiveMatrix(v.radians(45.0), _viewportWidth / _viewportHeight, 0.1, 100.0);

    _mvMatrix = new v.Matrix4.identity();
    _mvMatrix.translate(new v.Vector3(-1.5, 0.0, -8.0));

    _mvPushMatrix();
    _mvMatrix.rotateY(v.degrees2radians * _rPyramid);

    // draw triangle
    _gl.bindBuffer(
        webgl.RenderingContext.ARRAY_BUFFER,
        _pyramidVertexPositionBuffer);
    _gl.vertexAttribPointer(
        _aVertexPosition,
        3,
        webgl.RenderingContext.FLOAT,
        false,
        0,
        0);

    _gl.bindBuffer(
      webgl.RenderingContext.ARRAY_BUFFER,
      _pyramidVertexColorBuffer);
    _gl.vertexAttribPointer(
      _aVertexColor,
      4,
      webgl.RenderingContext.FLOAT,
      false,
      0,
      0);

    _setMatrixUniforms();
    // triangles, start at 0, total 3
    _gl.drawArrays(webgl.RenderingContext.TRIANGLES, 0, 12);
    _mvPopMatrix();

    // draw cube
    _mvMatrix.translate(new v.Vector3(3.0, 0.0, 0.0));

    // Spin it like a panda bear
    _mvPushMatrix();
    _mvMatrix.rotate(new v.Vector3(1.0, 1.0, 1.0), v.degrees2radians * _rCube);

    _gl.bindBuffer(
        webgl.RenderingContext.ARRAY_BUFFER,
        _cubeVertexPositionBuffer);
    _gl.vertexAttribPointer(
        _aVertexPosition,
        3,
        webgl.RenderingContext.FLOAT,
        false,
        0,
        0);

    _gl.bindBuffer(
        webgl.RenderingContext.ARRAY_BUFFER,
        _cubeVertexColorBuffer);
    _gl.vertexAttribPointer(
        _aVertexColor,
        4,
        webgl.RenderingContext.FLOAT,
        false,
        0,
        0);

    _gl.bindBuffer(webgl.RenderingContext.ELEMENT_ARRAY_BUFFER, _cubeVertexIndexBuffer);

    _setMatrixUniforms();
    _gl.drawElements(
       webgl.RenderingContext.TRIANGLES,
      36,
      webgl.RenderingContext.UNSIGNED_SHORT,
      0);

    _mvPopMatrix();
  }

  void animate(num delta) {
    _rPyramid = ((90 * delta) / 1000) % 360;
    _rCube = ((-75 * delta) / 1000) % 360;
  }
}

void main() {
  Shapes shapes = new Shapes(document.querySelector('#very-gl'));
  shapes.tick();
}
