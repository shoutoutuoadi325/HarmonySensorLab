# 传感器观测 / Harmony Sensor Lab

一款使用 ArkTS 和 ArkUI 开发的鸿蒙本机传感器观测工具。查看当前设备实际提供的传感器、实时数值和近期曲线，了解不同设备的传感器能力。

已上架华为应用市场，当前版本为 **1.0.1**。本仓库提供应用源码、构建脚本和测试。

**[在华为应用市场下载](https://appgallery.huawei.com/app/detail?id=com.personal.harmonysensorlab)** · [隐私政策](https://harmonysensorlab-privacy.netlify.app/) · [反馈问题](https://github.com/shoutoutuoadi325/HarmonySensorLab/issues)

## 支持设备

应用市场当前列出的设备为 **手机、平板、电脑和智能手表**。应用在各端观测所在设备的传感器，数据不在设备间同步，也不通过手机读取外部手表数据。能否安装以对应设备上的应用市场为准。

源码还包含智慧屏适配和独立的 `tv` 构建产品；智慧屏目前未列入上述商店页面的设备范围。轻量穿戴设备和车机不在当前支持范围内。

## 功能

- **传感器列表与硬件信息**：枚举本机公开传感器，查看名称、能力和可用状态。
- **实时数值与曲线**：显示传感器分量，选择需要观察的曲线分量；事件型传感器显示事件点。
- **采集控制**：暂停或继续、刷新传感器列表、清空曲线、关闭单项采集，选择 1 / 5 / 10 / 20 Hz 请求频率。
- **计步与步行检测**：主动授权运动权限后，显示系统提供的累计步数和步行检测事件，累计口径以系统为准。
- **多端界面**：手机、折叠屏和平板按窗口宽度调整布局，PC 支持键盘焦点，智能手表采用适合小屏的单列布局。界面支持中文和英文。

可观测类型包括加速度、陀螺仪、光照、磁场、气压、接近、方向、重力、线性加速度、旋转矢量，以及设备提供的温湿度、霍尔、显著运动、计步和佩戴检测等。实际列表和可用读数取决于设备硬件、系统与权限；未支持、未授权或没有回调的项目会显示相应状态。当前版本不采集心率、血氧等健康测量数据。

曲线按应用接收到回调的时间绘制，每条曲线最多保留 240 个样本，时间跨度不超过 60 秒；频率较高时覆盖时长可能更短。所选频率是请求值，实际回调频率由设备决定。读数用于观察设备接口输出，不用于医疗诊断或安全关键决策。

## 开始使用

1. 从应用市场安装应用，首次启动时阅读并选择是否同意隐私政策。
2. 同意后点击“开始观测”，查看设备提供的传感器和读数。
3. 如需计步，点击“授权运动”，在系统弹窗中允许运动权限。
4. 使用采集控制调整频率、暂停或清空曲线。

退入后台或离开观测页面会停止采集，手动暂停状态会在返回前台后保留。可在“本机数据与隐私”中查看完整政策或撤回同意；撤回后停止采集并清除内存中的观测记录。

应用无账号、广告、第三方统计或云同步。**传感器读数和曲线仅保存在本机进程内存中，不写入文件或数据库，不上传；进程结束后丢弃。** 隐私政策选择会保存在本机，以便下次启动时遵循该选择。完整说明见 [隐私政策](docs/privacy-policy.md)。

## 从源码构建

项目采用 Stage 模型，以 ArkTS 和 ArkUI 实现，无第三方运行依赖。已使用 DevEco Studio 26.0.0 Release、HarmonyOS SDK 26.0.0.105、Hvigor 6.26.9 和 IDE 自带的 Node.js 24.14.1 构建。构建脚本依赖 DevEco Studio 提供的工具链；Python 脚本需 Python 3。

克隆仓库后，在 DevEco Studio 中打开项目，完成工程同步，选择对应产品进行构建和运行。安装到模拟器或真机时，请在 IDE 中配置自己的调试签名。

~~~sh
git clone https://github.com/shoutoutuoadi325/HarmonySensorLab.git
cd HarmonySensorLab

# 手机 / 平板 Debug HAP
./scripts/build.sh default debug

# 多端统一 Release HAP / APP
./scripts/build.sh multidevice release
./scripts/build.sh multidevice release app
~~~

构建产品如下；表中的最低 API 是对应源码构建产品的兼容配置，安装还受设备和应用市场要求影响。所有产品的编译与目标 SDK 均为 26.0.0。

| 产品 | 设备类型 | 最低兼容版本 |
| --- | --- | --- |
| `multidevice` | 手机、平板、PC / 2in1、智能手表 | API 18 / 5.1.0(18) |
| `default` | 手机、平板，包括折叠手机 | API 12 / 5.0.0(12) |
| `pc` | PC / 2in1 | API 13 / 5.0.1(13) |
| `wearable` | 智能手表 | API 18 / 5.1.0(18) |
| `tv` | 智慧屏 | API 19 / 5.1.1(19) |

`build.sh` 的参数为产品、`debug` / `release` 和可选的 `hap` / `app`。默认 IDE 路径为 `/Applications/DevEco-Studio.app/Contents`；其他安装位置可通过 `DEVECO_STUDIO_HOME` 设置。`local.properties` 和签名材料不纳入版本控制。

Release 构建会检查隐私政策链接配置，签名需另行配置。仓库中的 `dist/packages/` 未签名包用于构建参考，安装应用请使用应用市场入口。已有本地正式签名材料时，可使用以下脚本构建并校验统一包：

~~~sh
python3 scripts/build-release-signed.py --products multidevice
python3 scripts/verify-release-packages.py --products multidevice
~~~

## 测试与源码导航

在项目根目录执行宿主机逻辑测试；UI 测试需要先构建 `default debug`：

~~~sh
node tests/host/run.cjs
./scripts/build.sh default debug
node tests/host/ui-compiled.cjs
~~~

测试覆盖采集生命周期、权限、频率与历史样本规则，以及编译后的 UI 更新和曲线绘制。测试使用平台替身；模拟器运行记录中的读数来自虚拟设备，真机硬件、功耗和具体输入设备仍需单独验证。测试说明见 [宿主机逻辑测试](tests/host/README.md)，已有模拟器记录见 [验证报告（历史记录）](reports/validation-report.md) 和 [Release 模拟器运行证据](reports/emulator-runtime/release-final-2026-11-10/)。

| 路径 | 内容 |
| --- | --- |
| [`entry/src/main/ets/pages/`](entry/src/main/ets/pages/) | 应用入口界面、观测控制与隐私页面 |
| [`entry/src/main/ets/services/`](entry/src/main/ets/services/) | 传感器适配、采集生命周期与权限处理 |
| [`entry/src/main/ets/model/`](entry/src/main/ets/model/) | 传感器类型、历史样本规则、隐私选择与政策文本 |
| [`entry/src/main/ets/components/`](entry/src/main/ets/components/) | 传感器卡片与曲线组件 |
| [`scripts/`](scripts/) | 构建、签名与包校验脚本 |
| [`tests/host/`](tests/host/) | 宿主机逻辑与 UI 测试 |

## 问题反馈

欢迎通过 [GitHub Issues](https://github.com/shoutoutuoadi325/HarmonySensorLab/issues) 反馈问题或建议。报告问题时请附设备型号、系统版本、应用版本、复现步骤，以及相关传感器的状态或截图，便于区分应用行为与设备能力差异。
