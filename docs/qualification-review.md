# 健康与后续设备资格核验

核验日期：2026-11-08（Asia/Shanghai）。本文以用户指定的资格审计为基线，补充读取本机 DevEco Studio 官方 SDK 与华为官方公开页面。没有连接目标真机，没有登录 AppGallery Connect 查看个人账号可选发布类目；“公开接口”“账号审核资格”“设备数据存在”分别判断。

## 首版实施决定

普通本机传感器按实际枚举结果展示，计步在用户主动开启并获运动权限后采集。首版不声明 READ_HEALTH_DATA，不调用 HEART_RATE，不集成 Health Service Kit 或 Wear Engine，不宣称健康测量、医疗诊断或远程获取手表健康数据。智能手表普通传感器仍属于本版开发范围。轻量穿戴、车机不加入本版安装包支持设备列表。

## 健康功能

| 路径 | 已核验事实 | 实施边界 |
| --- | --- | --- |
| 本机 SensorServiceKit HEART_RATE | SDK 公开声明 on(HEART_RATE, Callback<HeartRateResponse>, Options)，权限 READ_HEALTH_DATA；返回 heartRate，单位 bpm。官方开放用户权限页面明确该权限为 normal/user_grant，面向所有应用开放，支持设备列为 Phone、PC/2in1、Tablet、TV、Wearable。 | 个人身份本身不能判为禁用；需要实际硬件、系统权限以及数据回调。接口仅说明心率值，不代表原始 PPG、ECG、血氧、皮温、HRV 或运动健康数据库开放。 |
| Health Service Kit / 健康云数据 | 原资格审计核验高阶数据暂不向个人开放，包含专门健康心率、秒级心率、HRV、血氧、血压、皮温、ECG。 | 不将基础锻炼详情里的运动心率与专门高阶心率混同；本 App 不接入该服务。 |
| 手机 Wear Engine | 本次实际读取官方申请页面，明确“个人开发者当前只可申请设备基础信息、消息通知两个基本的权限”；人体传感器权限仅限专业研究机构。 | 不从手机调用 MOTION_SENSOR / HEALTH_SENSOR / USER_STATUS / DEVICE_IDENTIFIER。该服务限制不自动否定手表本机 SensorServiceKit。 |
| 健康类发布审核 | 本机 READ_HEALTH_DATA 开放不是上架健康测量类目的许可。未取得本个人账号的 AGC 类目要求及功能审核结论。 | 待确定具体功能、文案、发布地区并核对类目材料后，才能开启心率版。不得根据编译通过宣称审核获准。 |

本次实际页面读取：开放权限（用户授权），页面更新时间 2026-09-09 14:54；Wear Engine 申请页面同日更新时间。Health Service Kit 与应用审核资格的内容来自指定基线审计，本次未取得个人账号审核证据。SDK 摘录与设备元数据存于 ../reports/eligibility-evidence/。华为网站通过 curl 返回 SPA 框架而非正文，正文事实以浏览器实际显示的官方页面为准。

未来本机心率版本的准入条件：确认 AGC 个人账号的功能与类目要求；仅在本机枚举包含 HEART_RATE 时显示明确入口；在入口动作后说明用途并请求 READ_HEALTH_DATA；授权拒绝保持停止状态；真机验证佩戴、无数据、撤销权限、前后台切换；隐私政策同步更新。不能将未授权卡片的零值或模拟曲线呈现为读数。

## 轻量穿戴

官方 SDK 含 @system.sensor，标注 SystemCapability.Sensors.Sensor.Lite、@famodelonly、保留 liteWearable；心率回调文档明确每五秒一次，选项未提供可配置 interval。DevEco Studio 内置 [Lite]Empty Ability 模板明确是 FA 模式、JS UI 语法、liteWearable 类型，源码为 app.js 与 HML/CSS/JS；这与本项目 Stage ArkTS/ArkUI 工程不同。模板存在不能证明任意机型允许个人调试或安装。

状态：存在公开本机 API 和独立官方开发模板，但具体个人账号发布资格、目标型号、系统版本、安装与调试通道尚未核验。普通 Wearable WLAN 调试流程不得直接套用。加入前必须选定型号，核对该型号应用开发文档与个人账号 AGC 设备类目，证明可实际签名安装与调试，随后创建独立 Lite 工程。当前不承诺支持。

## 车机与审计差异

**补充发现：本机安装的 API 26 SDK 与原审计的车机支持列表存在差异。** HMS SDK 的 SensorServiceKit.json 将公开 @ohos.sensor.d.ts 的 car 起始版本列为 API 23，且 isSystemApi 为 false；文件级元数据已保存。原审计“当前支持设备不含 Car”不能继续作为所有新 SDK 的普遍事实。

然而 SDK 文件级 car 标注不能证明个人开发者可签名部署、车厂允许安装、具体机型可返回读数，或车辆总线/CAN/ADAS/车速等数据开放。当前官方开放用户权限页面列出的健康/运动设备也不能据此任意扩展到车机。本机 CarKit 导出 navigationInfoMgr、smartMobilityCommon，不是车辆传感器开放的证据。

状态：已发现车机本机 API 的 SDK 支持线索；个人账号资格、目标车机开发与安装通道、权限授权路径、应用审核仍未确认，因此本版仍排除 car。加入前应以目标 OEM/系统文档与个人账号 AGC 可用入口核验，不能凭 module.json5 可填 car 或代码能编译宣称完整支持。

## 官方来源

- [本机传感器 API](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/js-apis-sensor)
- [开放权限（系统授权）](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/permissions-for-all)
- [开放权限（用户授权）](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/permissions-for-all-user)
- [轻量穿戴传感器 API](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/js-apis-system-sensor)
- [本地真机调试](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-run-device)
- [Wear Engine 申请条件](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/wearengine_apply)
- [Health Service Kit 申请资格](https://developer.huawei.com/consumer/cn/doc/HMSCore-Guides/apply-kitservice-0000001050071707)
- [健康数据开放等级](https://developer.huawei.com/consumer/cn/doc/HMSCore-Guides/data_description-0000001467889369)
- [Car Kit 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/car-introduction)
- [应用审核指南](https://developer.huawei.com/consumer/cn/doc/app/50104)

SDK 证据来源：/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/ets/api/@ohos.sensor.d.ts、@system.sensor.d.ts；/Applications/DevEco-Studio.app/Contents/sdk/default/hms/ets/api/device-define/api-version/SensorServiceKit.json；DevEco Studio Lite Empty Ability/template.json。
