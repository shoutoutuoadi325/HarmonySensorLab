import { SensorDefinition } from './SensorModels';
import { tr } from './Locale';

// Public local SensorServiceKit readings; missing types are never synthesized.
export const SENSOR_DEFINITIONS: SensorDefinition[] = [
  {"id": 1, "title": tr("加速度", "Acceleration"), "unit": "m/s²", "labels": ["X", "Y", "Z"], "permission": "ohos.permission.ACCELEROMETER", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 2, "title": tr("角速度", "Gyroscope"), "unit": "rad/s", "labels": ["X", "Y", "Z"], "permission": "ohos.permission.GYROSCOPE", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 5, "title": tr("环境光", "Ambient light"), "unit": "lx", "labels": [tr("照度", "Illuminance")], "permission": "", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 6, "title": tr("磁场", "Magnetic field"), "unit": "μT", "labels": ["X", "Y", "Z"], "permission": "", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 8, "title": tr("气压", "Air pressure"), "unit": "hPa", "labels": [tr("气压", "Air pressure")], "permission": "", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 10, "title": tr("霍尔状态", "Hall sensor"), "unit": tr("状态码", "State code"), "labels": [tr("状态", "State")], "permission": "", "eventDriven": true, "minApi": 9, "qualification": false},
  {"id": 12, "title": tr("接近状态", "Proximity"), "unit": tr("0 近 / >0 远", "0 near / >0 far"), "labels": [tr("距离状态", "Proximity state")], "permission": "", "eventDriven": true, "minApi": 9, "qualification": false},
  {"id": 13, "title": tr("环境湿度", "Ambient humidity"), "unit": "%", "labels": [tr("湿度", "Humidity")], "permission": "", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 256, "title": tr("方向", "Orientation"), "unit": "°", "labels": [tr("方位角 α", "Azimuth α"), tr("俯仰角 β", "Pitch β"), tr("翻滚角 γ", "Roll γ")], "permission": "", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 257, "title": tr("重力", "Gravity"), "unit": "m/s²", "labels": ["X", "Y", "Z"], "permission": "", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 258, "title": tr("线性加速度", "Linear acceleration"), "unit": "m/s²", "labels": ["X", "Y", "Z"], "permission": "ohos.permission.ACCELEROMETER", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 259, "title": tr("旋转矢量", "Rotation vector"), "unit": tr("见分量", "See components"), "labels": [tr("X (无量纲)", "X (unitless)"), tr("Y (无量纲)", "Y (unitless)"), tr("Z (无量纲)", "Z (unitless)"), "W (rad)"], "permission": "", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 260, "title": tr("环境温度", "Ambient temperature"), "unit": "°C", "labels": [tr("温度", "Temperature")], "permission": "", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 261, "title": tr("未校准磁场", "Uncalibrated magnetic field"), "unit": "μT", "labels": ["X", "Y", "Z", tr("偏差 X", "X bias"), tr("偏差 Y", "Y bias"), tr("偏差 Z", "Z bias")], "permission": "", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 263, "title": tr("未校准角速度", "Uncalibrated gyroscope"), "unit": "rad/s", "labels": ["X", "Y", "Z", tr("偏差 X", "X bias"), tr("偏差 Y", "Y bias"), tr("偏差 Z", "Z bias")], "permission": "ohos.permission.GYROSCOPE", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 264, "title": tr("显著运动", "Significant motion"), "unit": tr("事件值", "Event value"), "labels": [tr("运动事件", "Motion event")], "permission": "", "eventDriven": true, "minApi": 9, "qualification": false},
  {"id": 265, "title": tr("步行检测", "Step detection"), "unit": tr("事件值", "Event value"), "labels": [tr("步行事件", "Step event")], "permission": "ohos.permission.ACTIVITY_MOTION", "eventDriven": true, "minApi": 9, "qualification": false},
  {"id": 266, "title": tr("累计步数", "Cumulative steps"), "unit": tr("步", "steps"), "labels": [tr("累计步数", "Cumulative steps")], "permission": "ohos.permission.ACTIVITY_MOTION", "eventDriven": true, "minApi": 9, "qualification": false},
  {"id": 278, "title": tr("本机心率", "Local heart rate"), "unit": "bpm", "labels": [tr("心率", "Heart rate")], "permission": "ohos.permission.READ_HEALTH_DATA", "eventDriven": false, "minApi": 9, "qualification": true},
  {"id": 280, "title": tr("佩戴检测", "Wear detection"), "unit": tr("0 未佩戴 / 1 佩戴", "0 not worn / 1 worn"), "labels": [tr("佩戴状态", "Wear state")], "permission": "", "eventDriven": true, "minApi": 9, "qualification": false},
  {"id": 281, "title": tr("未校准加速度", "Uncalibrated acceleration"), "unit": "m/s²", "labels": ["X", "Y", "Z", tr("偏差 X", "X bias"), tr("偏差 Y", "Y bias"), tr("偏差 Z", "Z bias")], "permission": "ohos.permission.ACCELEROMETER", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 283, "title": tr("融合压力", "Fusion pressure"), "unit": "%", "labels": [tr("压力比例", "Pressure ratio")], "permission": "", "eventDriven": false, "minApi": 22, "qualification": false},
];

export function definitionFor(id: number): SensorDefinition | undefined {
  return SENSOR_DEFINITIONS.find((item: SensorDefinition) => item.id === id);
}
