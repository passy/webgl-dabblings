(function () {
    'use strict';

    var buffers = {},
        matrices = {},
        shaderProgram;

    (function () {
        var canvas = document.getElementById('very-gl');
        var ctx = canvas.getContext('webgl');

        matrices.p = mat4.create();
        matrices.mv = mat4.create();
        start(canvas, ctx);
    }());

    function getShader(ctx, id) {
        var el = document.getElementById(id),
            src = el.textContent.trim(),
            type = el.type.split('x-shader/')[1],
            shader;


        if (type === 'x-fragment') {
            shader = ctx.createShader(ctx.FRAGMENT_SHADER);
        } else if (type === 'x-vertex') {
            shader = ctx.createShader(ctx.VERTEX_SHADER);
        } else {
            throw new Error('Unknown shader type ' + type);
        }

        ctx.shaderSource(shader, src);
        ctx.compileShader(shader);

        if (!ctx.getShaderParameter(shader, ctx.COMPILE_STATUS)) {
            throw new Error('Compiling shader failed: ' +
                ctx.getShaderInfoLog(shader));
        }

        return shader;
    }

    function initShaders(ctx) {
        var fragmentShader = getShader(ctx, 'shader-fs'),
            vertexShader = getShader(ctx, 'shader-vs');

        shaderProgram = ctx.createProgram();
        ctx.attachShader(shaderProgram, vertexShader);
        ctx.attachShader(shaderProgram, fragmentShader);
        ctx.linkProgram(shaderProgram);

        if (!ctx.getProgramParameter(shaderProgram, ctx.LINK_STATUS)) {
            throw new Error('Initializing shader program failed.');
        }

        ctx.useProgram(shaderProgram);

        shaderProgram.vertexPositionAttribute = ctx.getAttribLocation(
            shaderProgram,
            'aVertexPosition'
        );
        ctx.enableVertexAttribArray(shaderProgram.vertexPositionAttribute);

        shaderProgram.pMatrixUniform = ctx.getUniformLocation(
            shaderProgram, 'uPMatrix');
        shaderProgram.mvMatrixUniform = ctx.getUniformLocation(
            shaderProgram, 'uMVMatrix');
    }

    function initBuffers(ctx) {
        var squareVertexPositionBuffer,
            triangleVertexPositionBuffer,
            passyVertexPositionBuffer,
            vertices;

        triangleVertexPositionBuffer = ctx.createBuffer();
        ctx.bindBuffer(ctx.ARRAY_BUFFER, triangleVertexPositionBuffer);
        vertices = [
             0.0,  1.0,  0.0,
            -1.0, -1.0,  0.0,
             1.0, -1.0,  0.0
        ];
        ctx.bufferData(ctx.ARRAY_BUFFER, new Float32Array(vertices), ctx.STATIC_DRAW);
        triangleVertexPositionBuffer.itemSize = 3;
        triangleVertexPositionBuffer.numItems = 3;

        squareVertexPositionBuffer = ctx.createBuffer();
        ctx.bindBuffer(ctx.ARRAY_BUFFER, squareVertexPositionBuffer);
        vertices = [
             1.0,  1.0,  0.0,
            -1.0,  1.0,  0.0,
             1.0, -1.0,  0.0,
            -1.0, -1.0,  0.0
        ];

        ctx.bufferData(ctx.ARRAY_BUFFER, new Float32Array(vertices), ctx.STATIC_DRAW);
        squareVertexPositionBuffer.itemSize = 3;
        squareVertexPositionBuffer.numItems = 4;

        passyVertexPositionBuffer = ctx.createBuffer();
        ctx.bindBuffer(ctx.ARRAY_BUFFER, passyVertexPositionBuffer);
        vertices = [
             0.0,  1.0,  0.0,
            -1.0, -1.0,  0.0,
             1.0,  1.0,  1.0,
             0.0,  1.0,  0.0
        ];
        ctx.bufferData(ctx.ARRAY_BUFFER, new Float32Array(vertices), ctx.STATIC_DRAW);
        passyVertexPositionBuffer.itemSize = 3;
        passyVertexPositionBuffer.numItems = 4;

        buffers.triangle = triangleVertexPositionBuffer;
        buffers.square = squareVertexPositionBuffer;
        buffers.passy = passyVertexPositionBuffer;
    }

    function setMatrixUniforms(ctx) {
        ctx.uniformMatrix4fv(shaderProgram.pMatrixUniform, false, matrices.p);
        ctx.uniformMatrix4fv(shaderProgram.mvMatrixUniform, false, matrices.mv);
    }

    function draw(ctx) {
        ctx.viewport(0, 0, ctx.viewportWidth, ctx.viewportHeight);
        ctx.clear(ctx.COLOR_BUFFER_BIT | ctx.DEPTH_BUFFER_BIT);

        console.log('Drawing triangle ...');
        mat4.perspective(matrices.p, 45, ctx.viewportWidth / ctx.viewportHeight, 0.1, 100.0);
        mat4.identity(matrices.mv);
        mat4.translate(matrices.mv, matrices.mv, [-1.5, 1.0, -7.0]);

        ctx.bindBuffer(ctx.ARRAY_BUFFER, buffers.triangle);
        ctx.vertexAttribPointer(
            shaderProgram.vertexPositionAttribute,
            buffers.triangle.itemSize,
            ctx.FLOAT,
            false,
            0,
            0
        );
        setMatrixUniforms(ctx);
        ctx.drawArrays(ctx.TRIANGLES, 0, buffers.triangle.numItems);

        console.log('Drawing square ...');
        mat4.translate(matrices.mv, matrices.mv, [3.0, 0.0, 0.0]);
        ctx.bindBuffer(ctx.ARRAY_BUFFER, buffers.square);
        ctx.vertexAttribPointer(
            shaderProgram.vertexPositionAttribute,
            buffers.square.itemSize,
            ctx.FLOAT,
            false,
            0,
            0
        );
        setMatrixUniforms(ctx);
        ctx.drawArrays(ctx.TRIANGLE_STRIP, 0, buffers.square.numItems);

        console.log('Drawing my stuff ...');
        mat4.translate(matrices.mv, matrices.mv, [-1.5, -2.5, 0.0]);
        ctx.bindBuffer(ctx.ARRAY_BUFFER, buffers.passy);
        ctx.vertexAttribPointer(
            shaderProgram.vertexPositionAttribute,
            buffers.passy.itemSize,
            ctx.FLOAT,
            false,
            0,
            0
        );
        setMatrixUniforms(ctx);
        ctx.drawArrays(ctx.TRIANGLE_STRIP, 0, buffers.passy.numItems);

        console.log('Done drawing');
    }

    function start(canvas, ctx) {
        ctx.viewportWidth = canvas.width;
        ctx.viewportHeight = canvas.height;

        console.log(ctx.viewportWidth, ctx.viewportHeight);

        initShaders(ctx);
        initBuffers(ctx);

        ctx.clearColor(0.3, 0.0, 0.5, 1.0);
        // Not quite sure what this does. I think it basically means that the
        // depth buffer is used at all.
        ctx.enable(ctx.DEPTH_TEST);

        draw(ctx);
    }
}());
