import { SensorDefinition } from './SensorModels';

// Public local SensorServiceKit readings; missing types are never synthesized.
export const SENSOR_DEFINITIONS: SensorDefinition[] = [
  {"id": 1, "title": "加速度", "unit": "m/s²", "labels": ["X", "Y", "Z"], "permission": "ohos.permission.ACCELEROMETER", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 2, "title": "角速度", "unit": "rad/s", "labels": ["X", "Y", "Z"], "permission": "ohos.permission.GYROSCOPE", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 5, "title": "环境光", "unit": "lx", "labels": ["照度"], "permission": "", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 6, "title": "磁场", "unit": "μT", "labels": ["X", "Y", "Z"], "permission": "", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 8, "title": "气压", "unit": "hPa", "labels": ["气压"], "permission": "", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 10, "title": "霍尔状态", "unit": "状态码", "labels": ["状态"], "permission": "", "eventDriven": true, "minApi": 9, "qualification": false},
  {"id": 12, "title": "接近状态", "unit": "0 近 / >0 远", "labels": ["距离状态"], "permission": "", "eventDriven": true, "minApi": 9, "qualification": false},
  {"id": 13, "title": "环境湿度", "unit": "%", "labels": ["湿度"], "permission": "", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 256, "title": "方向", "unit": "°", "labels": ["方位角 α", "俯仰角 β", "翻滚角 γ"], "permission": "", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 257, "title": "重力", "unit": "m/s²", "labels": ["X", "Y", "Z"], "permission": "", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 258, "title": "线性加速度", "unit": "m/s²", "labels": ["X", "Y", "Z"], "permission": "ohos.permission.ACCELEROMETER", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 259, "title": "旋转矢量", "unit": "见分量", "labels": ["X (无量纲)", "Y (无量纲)", "Z (无量纲)", "W (rad)"], "permission": "", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 260, "title": "环境温度", "unit": "°C", "labels": ["温度"], "permission": "", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 261, "title": "未校准磁场", "unit": "μT", "labels": ["X", "Y", "Z", "偏差 X", "偏差 Y", "偏差 Z"], "permission": "", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 263, "title": "未校准角速度", "unit": "rad/s", "labels": ["X", "Y", "Z", "偏差 X", "偏差 Y", "偏差 Z"], "permission": "ohos.permission.GYROSCOPE", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 264, "title": "显著运动", "unit": "事件值", "labels": ["运动事件"], "permission": "", "eventDriven": true, "minApi": 9, "qualification": false},
  {"id": 265, "title": "步行检测", "unit": "事件值", "labels": ["步行事件"], "permission": "ohos.permission.ACTIVITY_MOTION", "eventDriven": true, "minApi": 9, "qualification": false},
  {"id": 266, "title": "累计步数", "unit": "步", "labels": ["累计步数"], "permission": "ohos.permission.ACTIVITY_MOTION", "eventDriven": true, "minApi": 9, "qualification": false},
  {"id": 278, "title": "本机心率", "unit": "bpm", "labels": ["心率"], "permission": "ohos.permission.READ_HEALTH_DATA", "eventDriven": false, "minApi": 9, "qualification": true},
  {"id": 280, "title": "佩戴检测", "unit": "0 未佩戴 / 1 佩戴", "labels": ["佩戴状态"], "permission": "", "eventDriven": true, "minApi": 9, "qualification": false},
  {"id": 281, "title": "未校准加速度", "unit": "m/s²", "labels": ["X", "Y", "Z", "偏差 X", "偏差 Y", "偏差 Z"], "permission": "ohos.permission.ACCELEROMETER", "eventDriven": false, "minApi": 9, "qualification": false},
  {"id": 283, "title": "融合压力", "unit": "%", "labels": ["压力比例"], "permission": "", "eventDriven": false, "minApi": 22, "qualification": false},
];

export function definitionFor(id: number): SensorDefinition | undefined {
  return SENSOR_DEFINITIONS.find((item: SensorDefinition) => item.id === id);
}
