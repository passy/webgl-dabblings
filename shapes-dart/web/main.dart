library shapes;

import 'dart:html';
import 'package:vector_math/vector_math.dart' as v;
import 'dart:web_gl' as webgl;
import 'dart:typed_data';
import 'dart:collection' show Queue;


class Shapes {
  CanvasElement _canvas;
  webgl.RenderingContext _gl;
  webgl.Program _shaderProgram;

  webgl.Buffer _pyramidVertexPositionBuffer;
  webgl.Buffer _pyramidVertexColorBuffer;

  webgl.Buffer _cubeVertexPositionBuffer;
  webgl.Buffer _cubeVertexTextureCoordBuffer;
  webgl.Buffer _cubeVertexIndexBuffer;

  webgl.Texture _yoTexture;

  int _viewportWidth;
  int _viewportHeight;

  v.Matrix4 _pMatrix;
  v.Matrix4 _mvMatrix;
  Queue<v.Matrix4> _mvMatrixStack = new Queue();

  int _aVertexPosition;
  int _aTextureCoord;
  webgl.UniformLocation _uPMatrix;
  webgl.UniformLocation _uMVMatrix;
  webgl.UniformLocation _samplerUniform;

  double _rxCubeRot = 0.0;
  double _ryCubeRot = 0.0;
  double _rzCubeRot = 0.0;

  Shapes(CanvasElement canvas) {
    _viewportWidth = canvas.width;
    _viewportHeight = canvas.height;

    _gl = canvas.getContext('webgl');

    _initShaders();
    _initBuffers();
    _initTexture();

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

    _aTextureCoord = _gl.getAttribLocation(_shaderProgram, 'aTextureCoord');
    _gl.enableVertexAttribArray(_aTextureCoord);

    _uPMatrix = _gl.getUniformLocation(_shaderProgram, 'uPMatrix');
    _uMVMatrix = _gl.getUniformLocation(_shaderProgram, 'uMVMatrix');
    _samplerUniform = _gl.getUniformLocation(_shaderProgram, 'uSampler');
  }

  void _initTexture() {
    _yoTexture = _gl.createTexture();
    var image = new Element.img();
    image.onLoad.listen((e) {
      _handleLoadedTexture(image);
      start();
    });
    image.setAttribute('src', 'yeoman.png');
  }

  void _handleLoadedTexture(ImageElement image) {
    _gl.bindTexture(webgl.RenderingContext.TEXTURE_2D, _yoTexture);
    _gl.texImage2DImage(
        webgl.RenderingContext.TEXTURE_2D,
        0,
        webgl.RenderingContext.RGBA,
        webgl.RenderingContext.RGBA,
        webgl.RenderingContext.UNSIGNED_BYTE,
        image);
    _gl.texParameteri(
        webgl.RenderingContext.TEXTURE_2D,
        webgl.RenderingContext.TEXTURE_MAG_FILTER,
        webgl.RenderingContext.LINEAR);
    _gl.texParameteri(
        webgl.RenderingContext.TEXTURE_2D,
        webgl.RenderingContext.TEXTURE_MIN_FILTER,
        webgl.RenderingContext.LINEAR_MIPMAP_NEAREST);
    _gl.generateMipmap(webgl.RenderingContext.TEXTURE_2D);
    _gl.bindTexture(webgl.RenderingContext.TEXTURE_2D, null);
  }

  void _initBuffers() {
    List<double> vertices;

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

    _cubeVertexTextureCoordBuffer = _gl.createBuffer();
    _gl.bindBuffer(webgl.RenderingContext.ARRAY_BUFFER, _cubeVertexTextureCoordBuffer);
    vertices = [
        // Front face
        0.0, 0.0,
        1.0, 0.0,
        1.0, 1.0,
        0.0, 1.0,

        // Back face
        1.0, 0.0,
        1.0, 1.0,
        0.0, 1.0,
        0.0, 0.0,

        // Top face
        0.0, 1.0,
        0.0, 0.0,
        1.0, 0.0,
        1.0, 1.0,

        // Bottom face
        1.0, 1.0,
        0.0, 1.0,
        0.0, 0.0,
        1.0, 0.0,

        // Right face
        1.0, 0.0,
        1.0, 1.0,
        0.0, 1.0,
        0.0, 0.0,

        // Left face
        0.0, 0.0,
        1.0, 0.0,
        1.0, 1.0,
        0.0, 1.0,
    ];
    _gl.bufferDataTyped(
        webgl.RenderingContext.ARRAY_BUFFER,
        new Float32List.fromList(vertices),
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

    _mvMatrix = new v.Matrix4.identity();
    _mvMatrix.translate(new v.Vector3(0.0, 0.0, -8.0));
    _pMatrix = v.makePerspectiveMatrix(v.radians(45.0), _viewportWidth / _viewportHeight, 0.1, 100.0);

    // Spin it like a panda bear
    _mvPushMatrix();
    _mvMatrix.rotateX(v.degrees2radians * _rxCubeRot);
    _mvMatrix.rotateY(v.degrees2radians * _ryCubeRot);
    _mvMatrix.rotateZ(v.degrees2radians * _rzCubeRot);

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

    // texture
    _gl.bindBuffer(webgl.RenderingContext.ARRAY_BUFFER, _cubeVertexTextureCoordBuffer);
    _gl.vertexAttribPointer(
        _aTextureCoord,
        2,
        webgl.RenderingContext.FLOAT,
        false,
        0,
        0);

    _gl.activeTexture(webgl.RenderingContext.TEXTURE0);
    _gl.bindTexture(webgl.RenderingContext.TEXTURE_2D, _yoTexture);
    _gl.uniform1i(_samplerUniform, 0);

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
    _rxCubeRot = ((80 * delta) / 1000) % 360;
    _ryCubeRot = ((70 * delta) / 1000) % 360;
    _rzCubeRot = ((60 * delta) / 1000) % 360;
  }

  void start() {
    tick();
  }
}

void main() {
  Shapes shapes = new Shapes(document.querySelector('#very-gl'));
}
