library shapes;

import 'dart:html';
import 'dart:math' as math;
import 'package:vector_math/vector_math.dart' as v;
import 'dart:web_gl' as webgl;
import 'dart:typed_data';
import 'dart:collection' show Queue, HashSet;


class TexturePair {
  ImageElement image;
  webgl.Texture texture;

  TexturePair(webgl.RenderingContext context, this.image) {
    this.texture = context.createTexture();
  }
}


class Shapes {
  CanvasElement _canvas;
  webgl.RenderingContext _gl;
  webgl.Program _shaderProgram;

  webgl.Buffer _pyramidVertexPositionBuffer;
  webgl.Buffer _pyramidVertexColorBuffer;

  webgl.Buffer _cubeVertexPositionBuffer;
  webgl.Buffer _cubeVertexTextureCoordBuffer;
  webgl.Buffer _cubeVertexIndexBuffer;

  List<TexturePair> _texturePairs = [];
  Set<int> _keysPressed = new HashSet<int>();

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
  double _rzCubePos = -5.0;
  double _xSpeed = 0.0;
  double _ySpeed = 0.0;

  int _texture = 0;

  Shapes(CanvasElement canvas) {
    _viewportWidth = canvas.width;
    _viewportHeight = canvas.height;

    _gl = canvas.getContext('webgl');

    _initShaders();
    _initBuffers();
    _initTextures();

    _gl.clearColor(0.6, 0.4, 0.6, 1.0);
    _gl.enable(webgl.RenderingContext.DEPTH_TEST);
  }

  void cycleTexture() {
    _texture = (_texture + 1) % _texturePairs.length;
  }

  void keyPressed(final int code) {
    this._keysPressed.add(code);
  }

  void keyReleased(final int code) {
    this._keysPressed.remove(code);
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

  void _initTextures() {
    final List<String> textures = ['yeoman', 'grunt', 'bower'];
    int countdown = textures.length;

    var onLoadHandler = ((e) {
      if (--countdown == 0) {
        _handleLoadedTexture();
        start();
      }
    });

    for (String name in textures) {
      ImageElement image = new Element.img();
      image.setAttribute('src', '$name.png');
      image.onLoad.listen(onLoadHandler);

      _texturePairs.add(new TexturePair(_gl, image));
    }
  }

  void _handleLoadedTexture() {
    for (final TexturePair pair in _texturePairs) {
      _gl.bindTexture(webgl.RenderingContext.TEXTURE_2D, pair.texture);
      _gl.pixelStorei(webgl.RenderingContext.UNPACK_FLIP_Y_WEBGL, 1);

      _gl.texImage2DImage(
          webgl.RenderingContext.TEXTURE_2D,
          0,
          webgl.RenderingContext.RGBA,
          webgl.RenderingContext.RGBA,
          webgl.RenderingContext.UNSIGNED_BYTE,
          pair.image);
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
    handleKeys();
    window.animationFrame.then(tick);
  }

  void render() {
    _gl.viewport(0, 0, _viewportWidth, _viewportHeight);
    _gl.clear(webgl.RenderingContext.COLOR_BUFFER_BIT | webgl.RenderingContext.DEPTH_BUFFER_BIT);

    _mvMatrix = new v.Matrix4.identity();
    _mvMatrix.translate(new v.Vector3(0.0, 0.0, _rzCubePos));
    _pMatrix = v.makePerspectiveMatrix(v.radians(45.0), _viewportWidth / _viewportHeight, 0.1, 100.0);

    // Spin it like a panda bear
    _mvPushMatrix();
    _mvMatrix.rotateX(v.degrees2radians * _rxCubeRot);
    _mvMatrix.rotateY(v.degrees2radians * _ryCubeRot);

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
    _gl.bindTexture(webgl.RenderingContext.TEXTURE_2D, _texturePairs[_texture].texture);
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
    _rxCubeRot = ((_xSpeed * delta) / 1000) % 360;
    _ryCubeRot = ((_ySpeed * delta) / 1000) % 360;
  }

  void handleKeys() {
    if (_keysPressed.contains(KeyCode.UP)) {
      _xSpeed += 0.3;
    }
    if (_keysPressed.contains(KeyCode.DOWN)) {
      _xSpeed = math.max(0, _xSpeed - 0.1);
    }
    if (_keysPressed.contains(KeyCode.RIGHT)) {
      _ySpeed += 0.3;
    }
    if (_keysPressed.contains(KeyCode.LEFT)) {
      _ySpeed = math.max(0, _ySpeed - 0.1);
    }
    if (_keysPressed.contains(KeyCode.Q)) {
      _rzCubePos += 0.1;
    }
    if (_keysPressed.contains(KeyCode.A)) {
      _rzCubePos -= 0.1;
    }
  }

  void start() {
    tick();
  }
}

void main() {
  final Shapes shapes = new Shapes(document.querySelector('#very-gl'));

  document.onKeyDown.listen((e) {
    if (e.keyCode == KeyCode.F) {
      shapes.cycleTexture();
    } else {
      shapes.keyPressed(e.keyCode);
    }
  });

  document.onKeyUp.listen((e) {
    if (e.keyCode != KeyCode.F) {
      shapes.keyReleased(e.keyCode);
    }
  });
}
