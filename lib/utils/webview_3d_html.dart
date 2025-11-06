/// WebView 3D 查看器 HTML 模板
/// 使用 Three.js 渲染 STL 模型，支持自动旋转
class WebView3DHTML {
  /// 生成完整的HTML文档
  ///
  /// 特点：
  /// - 内嵌Three.js和STLLoader（离线可用）
  /// - 透明背景，融入Flutter界面
  /// - 自动Y轴旋转（6秒一圈）
  /// - 自适应模型缩放
  /// - 多CDN备份方案
  static String generate() {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        html, body {
            width: 100%;
            height: 100%;
            overflow: hidden;
            background: transparent;
        }
        #canvas-container {
            width: 100%;
            height: 100%;
            position: relative;
        }
        canvas {
            display: block;
            width: 100% !important;
            height: 100% !important;
        }
        #loading {
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            color: rgba(0, 212, 255, 0.8);
            font-size: 10px;
            font-family: sans-serif;
            text-align: center;
            z-index: 10;
        }
        .spinner {
            width: 20px;
            height: 20px;
            border: 2px solid rgba(0, 212, 255, 0.2);
            border-top-color: rgba(0, 212, 255, 0.8);
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin: 0 auto 8px;
        }
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <div id="canvas-container">
        <div id="loading">
            <div class="spinner"></div>
            <div>Loading...</div>
        </div>
    </div>

    <!-- Three.js 多CDN备份加载 -->
    <script>
        // 全局变量
        let scene, camera, renderer, mesh;
        let isInitialized = false;

        // CDN列表（按优先级排序）
        const CDN_LIST = [
            {
                three: 'https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.min.js',
                loader: 'https://cdn.jsdelivr.net/npm/three@0.160.0/examples/js/loaders/STLLoader.js'
            },
            {
                three: 'https://unpkg.com/three@0.160.0/build/three.min.js',
                loader: 'https://unpkg.com/three@0.160.0/examples/js/loaders/STLLoader.js'
            }
        ];

        // 动态加载脚本
        function loadScript(url) {
            return new Promise((resolve, reject) => {
                const script = document.createElement('script');
                script.src = url;
                script.onload = resolve;
                script.onerror = reject;
                document.head.appendChild(script);
            });
        }

        // 尝试从CDN列表加载
        async function loadThreeJS() {
            for (let i = 0; i < CDN_LIST.length; i++) {
                try {
                    console.log(\`尝试CDN \${i + 1}: \${CDN_LIST[i].three}\`);
                    await loadScript(CDN_LIST[i].three);
                    await loadScript(CDN_LIST[i].loader);
                    console.log(\`CDN \${i + 1} 加载成功\`);
                    return true;
                } catch (error) {
                    console.error(\`CDN \${i + 1} 加载失败:\`, error);
                    if (i === CDN_LIST.length - 1) {
                        throw new Error('所有CDN加载失败');
                    }
                }
            }
        }

        // 初始化3D场景
        function initScene() {
            if (isInitialized) return;
            isInitialized = true;

            // 创建场景
            scene = new THREE.Scene();
            scene.background = null; // 透明背景

            // 创建相机（透视投影）
            camera = new THREE.PerspectiveCamera(
                45,  // 视角
                1,   // 宽高比（正方形）
                0.1, // 近裁剪面
                1000 // 远裁剪面
            );
            camera.position.set(0, 0, 150);
            camera.lookAt(0, 0, 0);

            // 创建渲染器
            const container = document.getElementById('canvas-container');
            renderer = new THREE.WebGLRenderer({
                antialias: true,      // 抗锯齿
                alpha: true,          // 透明背景
                preserveDrawingBuffer: true
            });
            renderer.setSize(160, 160); // 固定尺寸
            renderer.setPixelRatio(window.devicePixelRatio || 1);
            renderer.shadowMap.enabled = false; // 禁用阴影以提升性能
            container.appendChild(renderer.domElement);

            // 三点照明系统
            // 主光源（Key Light）- 从右上方照射
            const keyLight = new THREE.DirectionalLight(0xffffff, 1.2);
            keyLight.position.set(100, 100, 100);
            scene.add(keyLight);

            // 补光（Fill Light）- 从左侧柔和照射
            const fillLight = new THREE.DirectionalLight(0xffffff, 0.6);
            fillLight.position.set(-100, 50, 50);
            scene.add(fillLight);

            // 背光（Back Light）- 从后方照射，增加轮廓
            const backLight = new THREE.DirectionalLight(0xffffff, 0.4);
            backLight.position.set(0, -50, -100);
            scene.add(backLight);

            // 环境光 - 提供整体亮度
            const ambient = new THREE.AmbientLight(0x404040, 0.8);
            scene.add(ambient);

            console.log('3D场景初始化完成');
        }

        // 加载STL模型（接收Base64编码的数据）
        function loadSTLFromBase64(base64Data) {
            try {
                // 隐藏加载提示
                document.getElementById('loading').style.display = 'none';

                // Base64解码为二进制
                const binaryString = atob(base64Data);
                const bytes = new Uint8Array(binaryString.length);
                for (let i = 0; i < binaryString.length; i++) {
                    bytes[i] = binaryString.charCodeAt(i);
                }

                // 创建Blob URL
                const blob = new Blob([bytes], { type: 'application/octet-stream' });
                const url = URL.createObjectURL(blob);

                // 使用STLLoader加载
                const loader = new THREE.STLLoader();
                loader.load(
                    url,
                    function(geometry) {
                        console.log('STL模型加载成功');

                        // 清理旧模型
                        if (mesh) {
                            scene.remove(mesh);
                            mesh.geometry.dispose();
                            mesh.material.dispose();
                        }

                        // 创建材质（青色发光效果，符合看板风格）
                        const material = new THREE.MeshPhongMaterial({
                            color: 0x00d4ff,        // 青色
                            specular: 0x444444,     // 高光
                            shininess: 120,         // 光泽度
                            flatShading: false,     // 平滑着色
                            side: THREE.DoubleSide  // 双面渲染
                        });

                        // 创建网格
                        mesh = new THREE.Mesh(geometry, material);

                        // 几何体居中
                        geometry.center();
                        geometry.computeVertexNormals(); // 计算法线，改善光照

                        // 计算包围盒，自动缩放到合适大小
                        const box = new THREE.Box3().setFromObject(mesh);
                        const size = box.getSize(new THREE.Vector3());
                        const maxDim = Math.max(size.x, size.y, size.z);

                        // 缩放到80单位（适配160px容器，留有边距）
                        if (maxDim > 0) {
                            const scale = 80 / maxDim;
                            mesh.scale.multiplyScalar(scale);
                        }

                        // 添加到场景
                        scene.add(mesh);

                        // 启动渲染循环
                        animate();

                        // 清理Blob URL
                        URL.revokeObjectURL(url);
                    },
                    function(xhr) {
                        // 加载进度（可选）
                        if (xhr.lengthComputable) {
                            const percentComplete = xhr.loaded / xhr.total * 100;
                            console.log(\`加载进度: \${percentComplete.toFixed(0)}%\`);
                        }
                    },
                    function(error) {
                        console.error('STL加载失败:', error);
                        document.getElementById('loading').innerHTML =
                            '<div style="color: #ff4444;">加载失败</div>';

                        // 通知Flutter加载失败（如果需要）
                        if (window.chrome && window.chrome.webview) {
                            window.chrome.webview.postMessage({
                                type: 'error',
                                message: error.message || '模型加载失败'
                            });
                        }
                    }
                );

            } catch (error) {
                console.error('Base64解码失败:', error);
                document.getElementById('loading').innerHTML =
                    '<div style="color: #ff4444;">数据错误</div>';
            }
        }

        // 渲染循环
        function animate() {
            requestAnimationFrame(animate);

            if (mesh && scene && camera && renderer) {
                // Y轴自动旋转
                // 0.01弧度/帧 ≈ 0.57度/帧
                // 60fps: 34度/秒 ≈ 10.6秒/圈
                // 调整为 0.0174 弧度/帧 = 1度/帧 = 60度/秒 = 6秒/圈
                mesh.rotation.y += 0.0174;

                // 渲染场景
                renderer.render(scene, camera);
            }
        }

        // 初始化流程
        (async function() {
            try {
                // 显示加载提示
                document.getElementById('loading').style.display = 'block';

                // 加载Three.js库
                await loadThreeJS();

                // 初始化3D场景
                initScene();

                console.log('等待Flutter传递STL数据...');

            } catch (error) {
                console.error('初始化失败:', error);
                document.getElementById('loading').innerHTML =
                    '<div style="color: #ff4444;">初始化失败</div>';
            }
        })();

        // 监听来自Flutter的消息
        window.addEventListener('message', function(event) {
            if (event.data && event.data.type === 'loadSTL') {
                console.log('接收到STL数据，开始加载...');
                loadSTLFromBase64(event.data.base64);
            }
        });
    </script>
</body>
</html>
    ''';
  }
}