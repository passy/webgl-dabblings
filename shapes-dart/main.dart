library shapes;

import 'dart:html';
import 'package:vector_math/vector_math.dart' as v;
import 'dart:web_gl' as webgl;
import 'dart:typed_data';


class Shapes {
  CanvasElement _canvas;

  webgl.RenderingContext _gl;
  webgl.Buffer _triangleVertexPositionBuffer;
  webgl.Buffer _squareVertexPositionBuffer;
  webgl.Program _shaderProgram;

  int _viewportWidth;
  int _viewportHeight;
  int _dimensions = 3;

  v.Matrix4 _pMatrix;
  v.Matrix4 _mvMatrix;

  int _aVertexPosition;
  webgl.UniformLocation _uPMatrix;
  webgl.UniformLocation _uMVMatrix;

  Shapes(CanvasElement canvas) {
    _viewportWidth = canvas.width;
    _viewportHeight = canvas.height;

    _gl = canvas.getContext('webgl');

    _initShaders();
    _initBuffers();

    _gl.clearColor(0.0, 0.0, 0.0, 1.0);
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
      print(_gl.getShaderInfoLog(vertexShader));
    }

    if (!_gl.getShaderParameter(fragmentShader,
          webgl.RenderingContext.COMPILE_STATUS)) {
      print(_gl.getShaderInfoLog(fragmentShader));
    }

    if (!_gl.getProgramParameter(_shaderProgram,
          webgl.RenderingContext.LINK_STATUS)) {
      print(_gl.getProgramInfoLog(_shaderProgram));
    }

    _aVertexPosition = _gl.getAttribLocation(_shaderProgram, 'aVertexPosition');
    _gl.enableVertexAttribArray(_aVertexPosition);

    _uPMatrix = _gl.getUniformLocation(_shaderProgram, 'uPMatrix');
    _uMVMatrix = _gl.getUniformLocation(_shaderProgram, 'uMVMatrix');
  }

  void _initBuffers() {
    // variable to store verticies
    List<double> vertices;

    // create triangle
    _triangleVertexPositionBuffer = _gl.createBuffer();
    _gl.bindBuffer(
        webgl.RenderingContext.ARRAY_BUFFER,
        _triangleVertexPositionBuffer);

    // fill 'current buffer' with triangle verticies
    vertices = [
       0.0,  1.0,  0.0,
      -1.0, -1.0,  0.0,
       1.0, -1.0,  0.0
    ];
    _gl.bufferDataTyped(webgl.RenderingContext.ARRAY_BUFFER,
        new Float32List.fromList(vertices),
        webgl.RenderingContext.STATIC_DRAW);

    // create square
    _squareVertexPositionBuffer = _gl.createBuffer();
    _gl.bindBuffer(webgl.RenderingContext.ARRAY_BUFFER, _squareVertexPositionBuffer);

    // fill 'current buffer' with triangle verticies
    vertices = [
         1.0,  1.0,  0.0,
        -1.0,  1.0,  0.0,
         1.0, -1.0,  0.0,
        -1.0, -1.0,  0.0
    ];
    _gl.bufferDataTyped(
        webgl.RenderingContext.ARRAY_BUFFER,
        new Float32List.fromList(vertices),
        webgl.RenderingContext.STATIC_DRAW);
  }

  void _setMatrixUniforms() {
    Float32List tmpList = new Float32List(16);

    _pMatrix.copyIntoArray(tmpList);
    _gl.uniformMatrix4fv(_uPMatrix, false, tmpList);

    _mvMatrix.copyIntoArray(tmpList);
    _gl.uniformMatrix4fv(_uMVMatrix, false, tmpList);
  }

  void render() {
    _gl.viewport(0, 0, _viewportWidth, _viewportHeight);
    _gl.clear(webgl.RenderingContext.COLOR_BUFFER_BIT | webgl.RenderingContext.DEPTH_BUFFER_BIT);

    _pMatrix = v.makePerspectiveMatrix(v.radians(45.0), _viewportWidth / _viewportHeight, 0.1, 100.0);

    _mvMatrix = new v.Matrix4.identity();
    _mvMatrix.translate(new v.Vector3(-1.5, 0.0, -7.0));

    // draw triangle
    _gl.bindBuffer(
        webgl.RenderingContext.ARRAY_BUFFER,
        _triangleVertexPositionBuffer);
    _gl.vertexAttribPointer(
        _aVertexPosition,
        _dimensions,
        webgl.RenderingContext.FLOAT,
        false,
        0,
        0);
    _setMatrixUniforms();
    // triangles, start at 0, total 3
    _gl.drawArrays(webgl.RenderingContext.TRIANGLES, 0, 3);

    // draw square
    _mvMatrix.translate(new v.Vector3(3.0, 0.0, 0.0));

    _gl.bindBuffer(
        webgl.RenderingContext.ARRAY_BUFFER,
        _squareVertexPositionBuffer);
    _gl.vertexAttribPointer(
        _aVertexPosition,
        _dimensions,
        webgl.RenderingContext.FLOAT,
        false,
        0,
        0);
    _setMatrixUniforms();
    // square, start at 0, total 4
    _gl.drawArrays(webgl.RenderingContext.TRIANGLE_STRIP, 0, 4);
  }
}

void main() {
  Shapes shapes = new Shapes(document.querySelector('#very-gl'));
  shapes.render();
}
