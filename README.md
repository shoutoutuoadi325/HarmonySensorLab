# 传感器观测 / Harmony Sensor Lab

使用 ArkTS、ArkUI Stage 模型与 DevEco Studio 开发的本机传感器观测应用。已建立五类设备的工程适配，构建四产品 Debug 签名 HAP，并开展官方模拟器运行验证。具体测试覆盖见验证报告；真机硬件、功耗和上架资格仍须单独验收。

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
# 本机已生成官方调试签名材料时，构建四产品 Debug 签名 HAP：
python3 scripts/build-debug-signed.py
~~~

非默认安装目录可设置 DEVECO_STUDIO_HOME 指向 IDE 的 Contents 目录。local.properties 是本机路径，不纳入版本控制。调试签名材料仅保存在忽略的 .signing/deveco-signing.json；签名脚本临时注入并在结束时恢复工程配置，签名构建期间不要同时运行其他构建。

| 产品 | 安装设备类型 | 最低 API | 编译与目标 SDK |
| --- | --- | --- | --- |
| default | phone、tablet，包括折叠手机 | 12 / 5.0.0(12) | 26.0.0 |
| pc | 2in1，含 HarmonyOS PC | 13 / 5.0.1(13) | 26.0.0 |
| wearable | wearable 智能手表 | 18 / 5.1.0(18) | 26.0.0 |
| tv | tv 智慧屏 | 19 / 5.1.1(19) | 26.0.0 |

最低 API 不是系统市场版本号。新 API 通过 apiAvailable 守卫，SDK 编译器生成兼容判断。模块实际打包的 deviceTypes 按产品过滤。

手机单列，宽窗口 2/3 列，窗口大小改变会重排，折叠屏展开采用双列。PC 支持键盘焦点，TV 放大文字及按钮并实现按键处理，手表单列且留圆屏边距。模拟器布局与交互证据按端记录；TV 遥控、手表旋钮、功耗和真实硬件仍须按验证报告完成验收。

## 验证和交付

~~~sh
node tests/host/run.cjs
node tests/host/ui-compiled.cjs
python3 scripts/verify-packages.py
python3 scripts/device-status.py
python3 scripts/export-delivery.py
~~~

采集测试转译真实生产控制器并注入平台替身；UI 测试执行 SDK 实际生成的响应式更新与 Canvas 绘图函数。UI 测试需先构建 default debug。另有手机、折叠屏、平板、PC、TV、智能手表官方模拟器运行证据，位于 reports/emulator-runtime/；各测试项通过与未验证状态见验证报告。模拟器传感器回调和注入值不代表真实硬件数据。

device-status.py 可用受控 hdc 前台服务查询在线目标，复用现有服务并只清理自己创建的进程。verify-packages.py 使用官方签名工具校验调试签名及未签名包，并核对权限、设备类型和 APP 内 HAP。export-delivery.py 在内存中移除源码 ZIP 的签名配置和产品引用，保留本地工作配置，同时归档模拟器证据；私钥、密码和 .signing/ 不随源码交付。

- [验证报告](reports/validation-report.md)
- [隐私政策草稿](docs/privacy-policy-draft.md)
- [发布材料](docs/release-materials.md)
- [设备验收计划](docs/device-verification-plan.md)
- [签名与安装](docs/signing-and-installation.md)
- dist/packages/：四个官方 Debug 签名 HAP，以及各产品 Debug/Release 未签名 HAP、Release 未签名 APP 容器。

用户已登录 DevEco Studio，官方调试签名已在本地生成。Debug 签名包仅用于其 Profile 许可的调试设备；模拟器接受 unsigned Debug 包也不证明真机安装资格。全部 Release HAP/APP 仍未签名，尚未提交上架审核。真机调试授权、发布签名、个人账号类目及备案仍需完成。

核心：services/SensorController.ets 管理生命周期和权限；NativeSensorAdapter.ets 仅封装公开回调；model/ 存放类型、能力与历史规则；components/ 独立更新数值卡片与曲线；EntryAbility 绑定前后台。
