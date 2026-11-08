# 传感器观测 / Harmony Sensor Lab

使用 ArkTS、ArkUI Stage 模型与 DevEco Studio 开发的本机传感器观测应用。五类设备的构建配置已建立；真机安装、硬件读数和发布资格按验证报告单独验收。

## 使用

启动后点击“开始观测”。应用枚举本机公开传感器，显示必要权限已授予的实际回调、分量数值和单分量曲线。可暂停/继续、刷新设备、选择 1/5/10/20 Hz 请求频率、清空曲线、查看硬件信息和关闭某项。计步/步行检测需主动点击“授权运动”并在系统弹窗中允许。

曲线按本机回调接收时间绘制，最多保存最近 60 秒和 240 个真实样本，实际覆盖时长也受频率与点数限制。事件传感器绘制事件点，不生成连续值。高频回调按选定显示频率抽取真实样本；硬件间隔按 SDK 纳秒范围钳制。后台取消订阅，回来后保持手动暂停选择。进程结束后丢弃内存数据，不持久化、不上传。

已适配公开类型：加速度/未校准加速度、陀螺仪/未校准陀螺仪、光照及公开可选字段、磁场/未校准磁场、气压、霍尔、接近、湿度、方向、重力、线性加速度、旋转矢量、环境温度、显著运动、步行检测、累计步数、佩戴检测；API22+ 融合压力单独守卫。实际列表由设备枚举决定。缺失值、NaN/Infinity、异常与过期状态均有处理，不把未获取的数据显示为零。

本机心率可枚举但当前版不订阅、不申请健康权限；健康发布审核待个人账号核验。轻量穿戴和车机未加入安装范围。详见 [资格复核](docs/qualification-review.md)。

## 工程与构建

本机已用 DevEco Studio 26.0.0 Release、HarmonyOS SDK 26.0.0.105、Hvigor 6.26.9、随 IDE 提供的 Node 24.14.1 构建。运行应用无第三方依赖。

在 DevEco Studio 打开本目录；CLI 可执行：

~~~sh
./scripts/build.sh default debug
./scripts/build.sh pc release
./scripts/build.sh wearable release
./scripts/build.sh tv release
./scripts/build.sh default release app
./scripts/build-all.sh
~~~

非默认安装目录可设置 DEVECO_STUDIO_HOME 指向 IDE 的 Contents 目录。local.properties 是本机路径，不纳入版本控制。

| 产品 | 安装设备类型 | 最低 API | 编译与目标 SDK |
| --- | --- | --- | --- |
| default | phone、tablet，包括折叠手机 | 12 / 5.0.0(12) | 26.0.0 |
| pc | 2in1，含 HarmonyOS PC | 13 / 5.0.1(13) | 26.0.0 |
| wearable | wearable 智能手表 | 18 / 5.1.0(18) | 26.0.0 |
| tv | tv 智慧屏 | 19 / 5.1.1(19) | 26.0.0 |

最低 API 不是系统市场版本号。新 API 通过 apiAvailable 守卫，SDK 编译器生成兼容判断。模块实际打包的 deviceTypes 按产品过滤。

手机单列，宽窗口 2/3 列，窗口大小改变会重排，折叠屏按当前窗口宽度响应。PC 支持键盘焦点，TV 放大文字及按钮，手表单列且留圆屏上下/侧边距。上述是实现范围，最终横竖屏、折叠、遥控、旋钮和真实设备显示仍须实测。

## 验证和交付

~~~sh
node tests/host/run.cjs
node tests/host/ui-compiled.cjs
python3 scripts/verify-packages.py
~~~

采集测试转译真实生产控制器并注入平台替身；UI 测试执行 SDK 实际生成的响应式更新与 Canvas 绘图函数。均不代替鸿蒙运行时或真机验收。UI 测试需先构建 default debug。构建和包结构记录见 reports/。

- [验证报告](reports/validation-report.md)
- [隐私政策草稿](docs/privacy-policy-draft.md)
- [发布材料](docs/release-materials.md)
- [设备验收计划](docs/device-verification-plan.md)
- [签名与安装](docs/signing-and-installation.md)
- dist/packages/：各产品 Debug、Release 未签名 HAP 与未签名 APP 容器。

未签名包不能宣称已可安装到华为真机，也不能宣称已通过上架审核。正式安装包需要用户登录个人账号、合法签名及设备授权；证书、私钥和密码不应放入源码交付。

核心：services/SensorController.ets 管理生命周期和权限；NativeSensorAdapter.ets 仅封装公开回调；model/ 存放类型、能力与历史规则；components/ 独立更新数值卡片与曲线；EntryAbility 绑定前后台。
