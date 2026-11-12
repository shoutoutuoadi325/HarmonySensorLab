# 当前 Release 模拟器实测与原始截图

2026-11-10。四端已安装本次经过官方签名/Profile 独立验证的 Release HAP。全部候选 PNG 保留原始像素；12 张图片哈希与对应安装包哈希已核验。材料准备不代表 AppGallery 保存、上传、提交审核或批准。

| 设备 | 官方模拟器目标/API | 公开虚拟实例 | 应用原始截图 |
| --- | --- | --- | --- |
| 手机 | 127.0.0.1:5555 / 26 | 9 | phone/live.png、phone/paused.png、phone/privacy.png |
| PC | 127.0.0.1:12002 / 26 | 7 | pc/live.png、pc/paused.png、pc/privacy.png |
| 平板 | 127.0.0.1:12003 / 26 | 9 | tablet/live.png、tablet/paused.png、tablet/privacy.png |
| 手表 | 127.0.0.1:12004 / 26 | 9 | watch/live.png、watch/paused.png、watch/privacy.png |

每张候选配有同名 *-evidence.json，记录原始 PNG SHA-256、安装 HAP SHA-256、目标身份、实际 UI 文本和未编辑像素声明。完整路径、原始尺寸、包版本及通过/未测项见 runtime-candidate-manifest.json。手机、PC 当前已离线，既有证据仍保留。

手机：实时普通传感器、暂停保留数值、明确恢复、Home 后返回保持暂停、完整本机政策、知道了关闭、系统浏览器实际政策页面及返回保持暂停均已完成。

PC：实时普通传感器、暂停保留数值、硬件详情、完整本机政策和系统浏览器实际政策页面已完成。PC 恢复、前后台及浏览器返回状态未测。

平板：实时普通传感器、暂停保留数值、明确恢复、Home 后返回保持暂停、完整本机政策、系统浏览器实际政策页面及返回保持暂停均已完成。

手表：普通加速度回调、明确暂停/恢复、完整本机政策和在线尝试后重新打开本机政策已完成。运动权限系统请求实际显示并点击 Deny；bm 记录 ACTIVITY_MOTION=-1，普通加速度仍显示实时值。Allow 路径未测；拒绝后再次授权未出现新提示。

手表 Home 命令返回 No Error，但应用仍在前台，不能记为后台或表冠测试通过。在线政策按钮关闭本机弹窗后，稳定截图仍为应用，aa 无浏览器任务，也未观察到错误提示；该在线页面/错误兜底结果未验证。原始证据保留在 watch/online-policy-result-evidence.json、online-policy-settled-evidence.json、online-policy-ability-dump.json。手表暂停候选展示“继续采集”控件；此状态下的保留数值未单独复查。

本次使用相同 bundle com.personal.harmonysensorlab、模块 entry、版本 1.0.0 / 1000000、目标 API 原值 260000026。default 支持 phone/tablet，最低 API 原值 50000012；pc 支持 2in1，最低 50001013；wearable 支持 wearable，最低 50100018。

Release HAP SHA-256：default 5b51c3e763d9dabb52f7defa5564061e6a5916b6f18c764d07b523319f07a2ee；pc 27711ea7c708579278f5f83d815ec7b8ab101e9e4b675327074d271aa91ff562；wearable 522b75ca70d6946c7b8ea39e244e96a5d1a066320d92dc3fd62e84d68448bf4f。

平板/手表旧 Debug 包签名不一致，先记录 bm debug=true 和旧包身份后，仅移除该本地测试包，再安装当前 Release。当前 bm debug=false；模拟器 bm 的 appProvisionType=debug、fingerprint 为空，与独立官方签名/Profile 报告的 release 字段分别保留，不用模拟器这个字段代替包签名验证。

这些是官方虚拟模拟器回调，不验证实体传感器精度、真实运动、表冠或真实设备权限。启动页、桌面、系统运动授权和系统浏览器截图仅为自测证据，不作为应用商店截图。商店所需缩放/留边由主任务单独处理；本目录无裁剪、补绘或伪造读数。

补充：手表政策正文已实际滑动到后续开发者/联系信息段落，“知道了”关闭验证通过。当前手表回到未开始采集页面；运动权限仍拒绝。HDC 8710 服务/PID 11387 保留，平板 12003 和手表 12004 连接，无待完成抓图会话。
