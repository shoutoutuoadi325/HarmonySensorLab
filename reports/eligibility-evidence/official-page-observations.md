# 官方页面可见正文观察

观察日期：2026-11-08。来源为 CUA 浏览器实际页面可见正文；下列为关键摘录，不是账号审核结果。

## 开放权限（用户授权）

URL：https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/permissions-for-all-user
页面更新时间：2026-09-09 14:54。

- “此列表内所有权限均为用户授权（user_grant）的开放权限，面向所有应用开放。”
- “在用户手动允许授权后，应用才会真正获取相应权限”。
- ACTIVITY_MOTION：“允许应用读取用户的运动状态”，例如记录步数；normal/user_grant；支持 Phone | PC/2in1 | Tablet | TV | Wearable。
- READ_HEALTH_DATA：“允许应用读取用户的健康数据，如心率数据等”；normal/user_grant；同样支持五类设备。

## 申请接入 Wear Engine 服务

URL：https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/wearengine_apply
页面更新时间：2026-09-09 14:54。

- “个人开发者当前只可申请设备基础信息、消息通知两个基本的权限”。
- “人体传感器相关权限受限开放，仅限专业研究机构使用。如未提前与华为确认，请勿申请该权限。”
- 设备标识符仅限专业合作企业；需事前确认。
- HEALTH_SENSOR 项列出读取穿戴设备 ECG、PPG、HR；MOTION_SENSOR 列出 ACC、GYRO、MAG。这些条目存在不代表个人账号可申请。

## 限制

Health Service Kit 申请页面曾打开但未完成本次正文复核；相关结论沿用用户指定的已有核验文档。没有登录 AGC，没有申请数据权限，没有提交健康审核。
