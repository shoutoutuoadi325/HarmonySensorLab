# 签名与安装操作

用户已登录 DevEco Studio，并通过官方流程在本地生成调试签名材料。四产品 Debug 签名 HAP 已构建，官方验签结果见 reports/package-verification.json。全部 Release HAP/APP 仍未签名；调试签名不等于发布签名或上架许可。

1. 在 DevEco Studio 打开 HarmonySensorLab 工程，等待同步完成。工程入口为 build-profile.json5，默认目标为 entry/default。
2. 本次 IDE 登录已完成。后续需要刷新登录或真机授权时，密码、短信验证码和设备确认由用户在官方界面输入，不需要发送到聊天。
3. 连接具备公开本机 API 的目标设备并启用其官方调试通道。手机/平板常用 USB；PC、TV、Wearable 采用各自型号的官方连接说明。普通 Wearable 的 WLAN 流程不能直接套用到 Lite Wearable。
4. 真机使用官方自动签名或合法手动签名，将实际设备加入调试 Profile。若 AGC 要求创建应用/绑定包名，使用 com.personal.harmonysensorlab 或确定后的真实唯一包名并同步修改工程。已生成的调试 Profile 不自动覆盖所有真机。
5. 本机可运行 python3 scripts/build-debug-signed.py 重建四产品 Debug 签名 HAP；脚本读取忽略的 .signing/deveco-signing.json，临时注入签名配置，结束后恢复原配置。期间不要同时运行其他构建。用 python3 scripts/verify-packages.py 验证最终包；安装时显式选定实际在线目标。

~~~sh
# 将 CONNECT_KEY 与 SIGNED_HAP 换成实际设备和合法签名文件。
hdc -t CONNECT_KEY install SIGNED_HAP
hdc -t CONNECT_KEY shell aa start -a EntryAbility -b com.personal.harmonysensorlab
~~~

6. 按 device-verification-plan.md 记录型号、API、枚举、授权、数值、曲线、暂停、前后台与频率。reports/emulator-runtime/ 已保存官方模拟器运行证据；模拟器回调和注入值不证明真机传感器能力。部分模拟器允许安装 unsigned Debug HAP，这也不构成真机签名验证。
7. 真机验收后生成合法发布签名的 Release APP/HAP，在 AGC 核对个人类目、设备范围、备案和政策 URL，再进入发布审核。目前未提交审核。

私钥、密码及独立证书/Profile 文件留在本机，不入库、不随源码公开。源码导出脚本在内存中清空 signingConfigs 并移除产品 signingConfig 引用，不修改本地工作工程；.signing/ 不在导出范围内。交付的签名 HAP 含正常签名信息，不包含签名私钥或密码。

本次已解决早期模拟器组件不可用与 hdc 自动服务启动失败，安装官方镜像并开展多端模拟器验证。各端实际安装、布局、回调和输入覆盖以 reports/validation-report.md 为准，不能统称所有测试通过。TV 遥控与手表旋钮真机测试仍需设备。

可运行 python3 scripts/device-status.py 复核当前连接。脚本复用现有服务；没有服务时创建受控前台进程，查询后只清理自己创建的进程，不停止 IDE 的服务。脚本不执行签名、安装或设备授权。
