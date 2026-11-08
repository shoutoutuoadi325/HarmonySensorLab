# 签名与安装操作

当前源码和包结构可以审阅。签名配置为空，所有带 unsigned 的包均未签名；没有伪造个人开发者身份、证书或安装成功记录。

1. 在 DevEco Studio 打开 HarmonySensorLab 工程，等待同步完成。工程入口为 build-profile.json5，默认目标为 entry/default。
2. 在 IDE 登录已认证的华为个人开发者账号。密码、短信验证码与设备上的调试授权由用户自行输入，不需要发送到聊天。
3. 连接具备公开本机 API 的目标设备并启用其官方调试通道。手机/平板常用 USB；PC、TV、Wearable 采用各自型号的官方连接说明。普通 Wearable 的 WLAN 流程不能直接套用到 Lite Wearable。
4. 在工程的 Signing Configs 中选取合适产品，使用官方自动签名或合法手动签名；将实际设备加入调试 Profile。若 AGC 要求创建应用/绑定包名，使用 com.personal.harmonysensorlab 或确定后的真实唯一包名并同步修改工程。
5. 生成带实际签名的 Debug HAP，安装后运行。不能使用 unsigned 包代替签名结果。用 hdc list targets 确认设备在线；安装命令应显式选定目标，避免多设备混淆。

~~~sh
# 将 CONNECT_KEY 与 SIGNED_HAP 换成实际设备和合法签名文件。
hdc -t CONNECT_KEY install SIGNED_HAP
hdc -t CONNECT_KEY shell aa start -a EntryAbility -b com.personal.harmonysensorlab
~~~

6. 按 device-verification-plan.md 记录型号、API、枚举、授权、数值、曲线、暂停、前后台与频率。真实数据/健康或设备标识无需上传到外部服务。截图用于发布时应由用户认可并仅包含必要 UI。
7. 生成合法发布签名的 Release APP/HAP，在 AGC 核对个人类目、设备范围、备案和政策 URL 后才进入发布审核。当前任务只准备发布材料，尚未提交审核。

IDE 自动签名可能把凭据相关字段写入本地 build-profile.json5。后续源码归档前必须清理敏感字段，证书/Profile/私钥不得随源码公开。当前源代码归档时 signingConfigs 为空。

本次环境事实：官方 Device Manager 显示无本地模拟器，Install 报无法找到 emulator 组件。hdc 自动启动服务时连接失败；改用官方 -m 前台服务后已能正常查询，当前返回 [Empty]，表示没有在线调试目标。

可运行 python3 scripts/device-status.py 复核连接。脚本复用现有本地服务；没有服务时创建受控前台进程，查询后只清理自己创建的进程，不停止 IDE 的服务。脚本不执行签名、安装或设备授权。接入用户设备并合法签名后可以继续验证。
