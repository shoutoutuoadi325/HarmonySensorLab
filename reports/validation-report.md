# 验证报告

日期：2026-11-08（Asia/Shanghai）。应用：传感器观测 1.0.0，包名 com.personal.harmonysensorlab。

交付包含 ArkTS/ArkUI 源码、四产品 Debug 签名 HAP、未签名 Release HAP/APP、隐私政策草稿、发布材料和官方模拟器证据。用户已登录 DevEco，并指定本轮使用模拟器测试。模拟器记录虚拟驱动通过本机公开 API 的回调，不代表物理硬件、功耗或上架审核结果。

## 构建、签名与包核验

环境：macOS Apple Silicon；DevEco Studio 26.0.0 Release，HarmonyOS SDK 26.0.0.105，Hvigor 6.26.9，IDE 内置 Node 24.14.1。Stage 工程没有第三方运行依赖。

| 产品 | Debug HAP | Release HAP / APP | 最低 / 目标 API | 包内设备类型 |
| --- | --- | --- | --- | --- |
| default | 成功，官方调试签名 | 成功，未签名 | 12 / 26 | phone、tablet |
| pc | 成功，官方调试签名 | 成功，未签名 | 13 / 26 | 2in1 |
| wearable | 成功，官方调试签名 | 成功，未签名 | 18 / 26 | wearable |
| tv | 成功，官方调试签名 | 成功，未签名 | 19 / 26 | tv |

dist/packages/ 共 16 个文件：4 个 Debug 签名 HAP、8 个未签名 HAP、4 个未签名 APP。逐文件大小、SHA-256 和结果见 [package-verification.json](package-verification.json)。官方 hap-sign-tool verify-app 校验 Debug 的代码签名、权限签名、摘要及 debug Profile，证书链来自 Huawei CBG。未签名包亦用官方工具确认不存在 Signing Block。APP 内 HAP 的代码、资源和 manifest 与对应 Release HAP 相同，容器装配会改写 pack.info。

首次在手机模拟器安装签名包时，已有未签名测试包造成 install sign info inconsistent。移除本应用的旧测试安装后签名 HAP 安装成功。该操作仅影响本任务创建的模拟器测试应用。Debug Profile 不等于发布签名，也不保证未登记真机能够安装。

凭据保留在本机忽略目录及 DevEco 管理目录。build-debug-signed.py 只在构建期间注入配置，结束后恢复便携 profile。源码 ZIP 去除签名配置并排除凭据，导出时扫描本机签名密码误入文件的情况。

日志见 build-debug-产品.log、build-release-产品.log、build-app-产品.log、build-debug-产品-signed.log。编译无错误。Native on/off 可能抛异常的静态提示由控制器捕获处理，未签名构建会提示没有 signingConfig。

## 自动化验证

- **采集核心 20/20**：[host-tests.log](host-tests.log)。执行转译后的生产控制器，覆盖前后台、暂停恢复、同毫秒新样本边界、开关、授权拒绝/撤销及异步竞争、非法值、可选光照字段、纳秒换算与钳制、抽样、内存上限、超时、事件型传感器、清空与快照隔离、本机索引、远端/mock 排除、API12 路径和服务/退订失败。
- **SDK 生成 UI 函数 9/9**：[ui-compiled-tests.log](ui-compiled-tests.log)。覆盖稳定键更新、单分量曲线、空数据/常值/缺失时段/事件点/可选字段消失，新增频率及分量 Select 避免依赖实时快照的回归验证，以及 TV 确认键只处理 key-down 的规则。
- **兼容编译**：真实 SDK 的 apiAvailable 转换器生成 sdkApiVersion 判断，旧系统无需具备同名原生函数。这证明编译行为；最低 API12/13/18/19 系统运行未实测。TV API24 镜像提供了低于编译 API26 的实际运行证据。
- **权限与包内容**：仅 ACCELEROMETER、GYROSCOPE、ACTIVITY_MOTION。没有 INTERNET、READ_HEALTH_DATA、后台任务或分布式传感器路径。

宿主测试使用平台替身，不替代以下 HarmonyOS 运行时证据。

## 官方模拟器运行

使用 DevEco 官方 Emulator CLI 创建、启动镜像，SDK hdc 和 uitest 安装、读取原生 UI 树、截图和注入测试输入。没有修改系统以绕过签名验证。旧包在这些镜像上曾可未签名安装，该现象仅适用于已测试镜像。

| 设备镜像 | 系统/API | 实际枚举 | 已观察布局和运行 |
| --- | --- | --- | --- |
| Phone，1280×2832 | HarmonyOS 7.0.0 / 26 | 9 项虚拟传感器 | 单列；数值/曲线、权限、暂停恢复、频率、清空、隐私 |
| Foldable，Mate X7 | HarmonyOS 7.0.0 / 26 | 11 项虚拟传感器 | 展开 2210×2416 双列；折叠 1080×2444 单列；持续回调 |
| Tablet，2880×1920 | HarmonyOS 7.0.0 / 26 | 9 项虚拟传感器 | 横屏三列，关闭镜像旋转锁后竖屏 1920×2880 两列 |
| 2in1，3120×2080 | HarmonyOS 7.0.0 / 26 | 7 项虚拟传感器 | 浮动窗口两列，最大化三列；暂停保留数值 |
| Wearable，466×466 圆屏 | HarmonyOS 7.0.0 / 26 | 9 项虚拟传感器 | 单列可滚动；开始按钮可滚动到达；数值/曲线 |
| TV | HarmonyOS 6.1.1 / 24 | 1 项光照传感器 | 启动与光照回调；方向键和确认键选择频率、曲线分量及采集开关 |

逐端安装日志、截图、JSON/Markdown UI 树、镜像信息和观察记录在 [emulator-runtime](emulator-runtime/)。本轮修复：高密度屏 Canvas 刻度过小（font 改用 vp）、手表 Select 对比度不足、实时快照使 Select 菜单消失、折叠展开窗口未达到双列阈值。分量菜单使用稳定标签及描述状态。TV 增加 Enter/Space/DPAD_CENTER key-down 处理，实机遥控与旋钮仍须验收。

最后一轮另修复 TV 深色按钮的默认黑字，并在 API20+ 使用公开 SymbolGlyphModifier 设置深色下拉箭头。较低 API 走守卫内的旧 Select 分支。TV 使用显式频率及分量按钮，开始后转移焦点；最终包的 DPAD_CENTER 可启动，方向键及确认键可将 5 Hz 改为 10 Hz、选择红外分量、关闭并重新开启单项采集。证据见 tv/observations.md、final-choices-layout.json、final-frequency-button-layout.json、final-axis-selected-layout.json 和 final-toggle-layout.json。早期 native Select 确认键问题不代表最终按钮实现。

最新签名包在 Phone 的 61-final-delivery-start 与 Foldable 的 21-final-delivery-start 中安装、启动并持续显示实时回调，哈希记录已刷新。逐端测试文件哈希与交付包的对应关系见 [final-tested-package-manifest.json](emulator-runtime/final-tested-package-manifest.json)。

Phone 具体证据：

- 30-final-start、31-live-frequency-menu、32-live-frequency-20：实时数值和曲线，采集中菜单保持打开，20 Hz 生效。34-20hz-native-channels.txt 中加速度/陀螺仪等请求间隔 50,000,000 ns；融合传感器受镜像周期限制为 20 ms。请求值不等于每项实际回调频率。
- 33-motion-dialog、35-motion-allow 及早期拒绝记录：未授权时不显示步数；允许后 43-step-23000 显示官方镜像注入的 23000。
- 37-bottom-sensors、40-light-injection-observed：光照注入后读取到 100 lx；色温等附加字段提示驱动支持未核实。20.3 注入的即时断言未通过，不把那次尝试记为成功。
- 16-foreground-channels.txt 对比 17-paused-channels.txt、15-background-channels.txt：暂停及 Home 后 SensorService 没有本应用订阅，返回前台恢复。
- 45-privacy：原生隐私弹窗正常显示。
- 最终签名包复测 50-final-launch、51-final-axis-menu、52-final-axis-y：启动、实时分量菜单与 Y 曲线选择正常；54-final-paused、55-final-clear、56-final-paused-return、59-final-live-return：暂停、清空及前后台恢复正常。最终 SensorService 的 53-final-foreground-channels.txt 有本应用订阅，54-final-paused-channels.txt 与 58-final-background-channels.txt 均无本应用订阅。最终测试包 SHA-256 见 final-tested-package.json。

镜像的 isMockSensor=false 不代表物理硬件。镜像厂商名称、零值、静止重力、色温和步数均作为虚拟 API 行为记录。早期并行重启使部分树和截图不一致；01–29 保留探索记录，以本报告明确引用场景和逐端最终记录为准。

## 资格与数据边界

已先读取指定基线审计 harmony-sensor-api-audit-2026-11-08.md，再复核本机 SDK 与官方权限正文。普通公开权限按已核验个人开发者范围实现。心率运行权限公开，但个人账号健康类发布资格仍未确认：当前可列出心率能力，**不订阅心率、不申请健康权限**。Health Service Kit / Wear Engine 受限功能未接入。

轻量穿戴 FA/JS 模板与当前 Stage/ArkTS 路径不同，机型安装及个人发布路径未确认。API26 SDK 有 car API23 元数据线索，补充了原审计边界；个人车机部署和 OEM 路径仍未确认。两者未加入包内 deviceTypes。详见 [qualification-review.md](../docs/qualification-review.md)。

样本仅保留当前进程内存，最近 60 秒且最多 240 点；高频时覆盖时长可能更短。曲线使用回调接收时间，不宣称硬件时钟已校准。无回调、非法值、权限不足、暂停、超时和服务错误分别显示，不合成替代读数。后台退订，恢复保持手动暂停选择。退订异常由屏蔽晚到回调和重试处理，罕见真机故障效果仍须验证。

## 发布前验收事项

本轮按用户指定使用模拟器测试并交付。正式上架前仍须真实硬件、权限撤销、功耗、遥控器/旋钮、最低 API 系统验收；个人账号 AGC 类目及 TV 备案条件；真实展示名称、邮箱、地区、隐私政策 URL；合法发布 Profile 和 Release 签名。见 [device-verification-plan.md](../docs/device-verification-plan.md) 和 [release-materials.md](../docs/release-materials.md)。

没有提交商店审核，也未声称健康、轻量穿戴或车机资格获准。
