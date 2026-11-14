import { sensor } from '@kit.SensorServiceKit';
import { tr } from '../model/Locale';
import { deviceInfo } from '@kit.BasicServicesKit';
import { SensorRow } from '../model/SensorModels';

export type StopSubscription = () => void;
export type ReceiveValues = (values: number[], labels?: string[]) => void;

export function subscribeNative(row: SensorRow, options: sensor.Options,
  receive: ReceiveValues): StopSubscription {
  // Numeric catalog ID avoids reading an API22 enum member on older systems.
  if (row.id === 283 && deviceInfo.apiAvailable(22)) {
    const callback = (response: sensor.FusionPressureResponse): void => {
      if (deviceInfo.apiAvailable(22)) {
        receive([response.fusionPressure]);
      }
    };
    sensor.on(sensor.SensorId.FUSION_PRESSURE, callback, options);
    return (): void => {
      if (deviceInfo.apiAvailable(22)) {
        sensor.off(sensor.SensorId.FUSION_PRESSURE, options.sensorInfoParam, callback);
      }
    };
  }
  switch (row.id) {
    case sensor.SensorId.ACCELEROMETER: {
      const callback = (response: sensor.AccelerometerResponse): void => {
        receive([response.x, response.y, response.z]);
      };
      sensor.on(sensor.SensorId.ACCELEROMETER, callback, options);
      return (): void => {
        if (deviceInfo.apiAvailable(19)) {
          sensor.off(sensor.SensorId.ACCELEROMETER, options.sensorInfoParam, callback);
        } else {
          sensor.off(sensor.SensorId.ACCELEROMETER, callback);
        }
      };
    }
    case sensor.SensorId.GYROSCOPE: {
      const callback = (response: sensor.GyroscopeResponse): void => {
        receive([response.x, response.y, response.z]);
      };
      sensor.on(sensor.SensorId.GYROSCOPE, callback, options);
      return (): void => {
        if (deviceInfo.apiAvailable(19)) {
          sensor.off(sensor.SensorId.GYROSCOPE, options.sensorInfoParam, callback);
        } else {
          sensor.off(sensor.SensorId.GYROSCOPE, callback);
        }
      };
    }
    case sensor.SensorId.AMBIENT_LIGHT: {
      const callback = (response: sensor.LightResponse): void => {
        const values: number[] = [response.intensity];
        const labels: string[] = [tr('照度 (lx)', 'Illuminance (lx)')];
        // These optional SDK fields may be driver placeholders; displaying returned values is not support verification.
        if (typeof response.colorTemperature === 'number' && Number.isFinite(response.colorTemperature)) {
          values.push(response.colorTemperature);
          labels.push(tr('色温 (K，支持未核实)', 'Color temp. (K, unverified)'));
        }
        if (typeof response.infraredLuminance === 'number' && Number.isFinite(response.infraredLuminance)) {
          values.push(response.infraredLuminance);
          labels.push(tr('红外 (cd/m²，支持未核实)', 'Infrared (cd/m², unverified)'));
        }
        receive(values, labels);
      };
      sensor.on(sensor.SensorId.AMBIENT_LIGHT, callback, options);
      return (): void => {
        if (deviceInfo.apiAvailable(19)) {
          sensor.off(sensor.SensorId.AMBIENT_LIGHT, options.sensorInfoParam, callback);
        } else {
          sensor.off(sensor.SensorId.AMBIENT_LIGHT, callback);
        }
      };
    }
    case sensor.SensorId.MAGNETIC_FIELD: {
      const callback = (response: sensor.MagneticFieldResponse): void => {
        receive([response.x, response.y, response.z]);
      };
      sensor.on(sensor.SensorId.MAGNETIC_FIELD, callback, options);
      return (): void => {
        if (deviceInfo.apiAvailable(19)) {
          sensor.off(sensor.SensorId.MAGNETIC_FIELD, options.sensorInfoParam, callback);
        } else {
          sensor.off(sensor.SensorId.MAGNETIC_FIELD, callback);
        }
      };
    }
    case sensor.SensorId.BAROMETER: {
      const callback = (response: sensor.BarometerResponse): void => {
        receive([response.pressure]);
      };
      sensor.on(sensor.SensorId.BAROMETER, callback, options);
      return (): void => {
        if (deviceInfo.apiAvailable(19)) {
          sensor.off(sensor.SensorId.BAROMETER, options.sensorInfoParam, callback);
        } else {
          sensor.off(sensor.SensorId.BAROMETER, callback);
        }
      };
    }
    case sensor.SensorId.HALL: {
      const callback = (response: sensor.HallResponse): void => {
        receive([response.status]);
      };
      sensor.on(sensor.SensorId.HALL, callback, options);
      return (): void => {
        if (deviceInfo.apiAvailable(19)) {
          sensor.off(sensor.SensorId.HALL, options.sensorInfoParam, callback);
        } else {
          sensor.off(sensor.SensorId.HALL, callback);
        }
      };
    }
    case sensor.SensorId.PROXIMITY: {
      const callback = (response: sensor.ProximityResponse): void => {
        receive([response.distance]);
      };
      sensor.on(sensor.SensorId.PROXIMITY, callback, options);
      return (): void => {
        if (deviceInfo.apiAvailable(19)) {
          sensor.off(sensor.SensorId.PROXIMITY, options.sensorInfoParam, callback);
        } else {
          sensor.off(sensor.SensorId.PROXIMITY, callback);
        }
      };
    }
    case sensor.SensorId.HUMIDITY: {
      const callback = (response: sensor.HumidityResponse): void => {
        receive([response.humidity]);
      };
      sensor.on(sensor.SensorId.HUMIDITY, callback, options);
      return (): void => {
        if (deviceInfo.apiAvailable(19)) {
          sensor.off(sensor.SensorId.HUMIDITY, options.sensorInfoParam, callback);
        } else {
          sensor.off(sensor.SensorId.HUMIDITY, callback);
        }
      };
    }
    case sensor.SensorId.ORIENTATION: {
      const callback = (response: sensor.OrientationResponse): void => {
        receive([response.alpha, response.beta, response.gamma]);
      };
      sensor.on(sensor.SensorId.ORIENTATION, callback, options);
      return (): void => {
        if (deviceInfo.apiAvailable(19)) {
          sensor.off(sensor.SensorId.ORIENTATION, options.sensorInfoParam, callback);
        } else {
          sensor.off(sensor.SensorId.ORIENTATION, callback);
        }
      };
    }
    case sensor.SensorId.GRAVITY: {
      const callback = (response: sensor.GravityResponse): void => {
        receive([response.x, response.y, response.z]);
      };
      sensor.on(sensor.SensorId.GRAVITY, callback, options);
      return (): void => {
        if (deviceInfo.apiAvailable(19)) {
          sensor.off(sensor.SensorId.GRAVITY, options.sensorInfoParam, callback);
        } else {
          sensor.off(sensor.SensorId.GRAVITY, callback);
        }
      };
    }
    case sensor.SensorId.LINEAR_ACCELEROMETER: {
      const callback = (response: sensor.LinearAccelerometerResponse): void => {
        receive([response.x, response.y, response.z]);
      };
      sensor.on(sensor.SensorId.LINEAR_ACCELEROMETER, callback, options);
      return (): void => {
        if (deviceInfo.apiAvailable(19)) {
          sensor.off(sensor.SensorId.LINEAR_ACCELEROMETER, options.sensorInfoParam, callback);
        } else {
          sensor.off(sensor.SensorId.LINEAR_ACCELEROMETER, callback);
        }
      };
    }
    case sensor.SensorId.ROTATION_VECTOR: {
      const callback = (response: sensor.RotationVectorResponse): void => {
        receive([response.x, response.y, response.z, response.w]);
      };
      sensor.on(sensor.SensorId.ROTATION_VECTOR, callback, options);
      return (): void => {
        if (deviceInfo.apiAvailable(19)) {
          sensor.off(sensor.SensorId.ROTATION_VECTOR, options.sensorInfoParam, callback);
        } else {
          sensor.off(sensor.SensorId.ROTATION_VECTOR, callback);
        }
      };
    }
    case sensor.SensorId.AMBIENT_TEMPERATURE: {
      const callback = (response: sensor.AmbientTemperatureResponse): void => {
        receive([response.temperature]);
      };
      sensor.on(sensor.SensorId.AMBIENT_TEMPERATURE, callback, options);
      return (): void => {
        if (deviceInfo.apiAvailable(19)) {
          sensor.off(sensor.SensorId.AMBIENT_TEMPERATURE, options.sensorInfoParam, callback);
        } else {
          sensor.off(sensor.SensorId.AMBIENT_TEMPERATURE, callback);
        }
      };
    }
    case sensor.SensorId.MAGNETIC_FIELD_UNCALIBRATED: {
      const callback = (response: sensor.MagneticFieldUncalibratedResponse): void => {
        receive([response.x, response.y, response.z, response.biasX, response.biasY, response.biasZ]);
      };
      sensor.on(sensor.SensorId.MAGNETIC_FIELD_UNCALIBRATED, callback, options);
      return (): void => {
        if (deviceInfo.apiAvailable(19)) {
          sensor.off(sensor.SensorId.MAGNETIC_FIELD_UNCALIBRATED, options.sensorInfoParam, callback);
        } else {
          sensor.off(sensor.SensorId.MAGNETIC_FIELD_UNCALIBRATED, callback);
        }
      };
    }
    case sensor.SensorId.GYROSCOPE_UNCALIBRATED: {
      const callback = (response: sensor.GyroscopeUncalibratedResponse): void => {
        receive([response.x, response.y, response.z, response.biasX, response.biasY, response.biasZ]);
      };
      sensor.on(sensor.SensorId.GYROSCOPE_UNCALIBRATED, callback, options);
      return (): void => {
        if (deviceInfo.apiAvailable(19)) {
          sensor.off(sensor.SensorId.GYROSCOPE_UNCALIBRATED, options.sensorInfoParam, callback);
        } else {
          sensor.off(sensor.SensorId.GYROSCOPE_UNCALIBRATED, callback);
        }
      };
    }
    case sensor.SensorId.SIGNIFICANT_MOTION: {
      const callback = (response: sensor.SignificantMotionResponse): void => {
        receive([response.scalar]);
      };
      sensor.on(sensor.SensorId.SIGNIFICANT_MOTION, callback, options);
      return (): void => {
        if (deviceInfo.apiAvailable(19)) {
          sensor.off(sensor.SensorId.SIGNIFICANT_MOTION, options.sensorInfoParam, callback);
        } else {
          sensor.off(sensor.SensorId.SIGNIFICANT_MOTION, callback);
        }
      };
    }
    case sensor.SensorId.PEDOMETER_DETECTION: {
      const callback = (response: sensor.PedometerDetectionResponse): void => {
        receive([response.scalar]);
      };
      sensor.on(sensor.SensorId.PEDOMETER_DETECTION, callback, options);
      return (): void => {
        if (deviceInfo.apiAvailable(19)) {
          sensor.off(sensor.SensorId.PEDOMETER_DETECTION, options.sensorInfoParam, callback);
        } else {
          sensor.off(sensor.SensorId.PEDOMETER_DETECTION, callback);
        }
      };
    }
    case sensor.SensorId.PEDOMETER: {
      const callback = (response: sensor.PedometerResponse): void => {
        receive([response.steps]);
      };
      sensor.on(sensor.SensorId.PEDOMETER, callback, options);
      return (): void => {
        if (deviceInfo.apiAvailable(19)) {
          sensor.off(sensor.SensorId.PEDOMETER, options.sensorInfoParam, callback);
        } else {
          sensor.off(sensor.SensorId.PEDOMETER, callback);
        }
      };
    }
    case sensor.SensorId.WEAR_DETECTION: {
      const callback = (response: sensor.WearDetectionResponse): void => {
        receive([response.value]);
      };
      sensor.on(sensor.SensorId.WEAR_DETECTION, callback, options);
      return (): void => {
        if (deviceInfo.apiAvailable(19)) {
          sensor.off(sensor.SensorId.WEAR_DETECTION, options.sensorInfoParam, callback);
        } else {
          sensor.off(sensor.SensorId.WEAR_DETECTION, callback);
        }
      };
    }
    case sensor.SensorId.ACCELEROMETER_UNCALIBRATED: {
      const callback = (response: sensor.AccelerometerUncalibratedResponse): void => {
        receive([response.x, response.y, response.z, response.biasX, response.biasY, response.biasZ]);
      };
      sensor.on(sensor.SensorId.ACCELEROMETER_UNCALIBRATED, callback, options);
      return (): void => {
        if (deviceInfo.apiAvailable(19)) {
          sensor.off(sensor.SensorId.ACCELEROMETER_UNCALIBRATED, options.sensorInfoParam, callback);
        } else {
          sensor.off(sensor.SensorId.ACCELEROMETER_UNCALIBRATED, callback);
        }
      };
    }
    default:
      throw new Error(tr('此传感器没有已核验的公开订阅适配器', 'This sensor has no verified public adapter.'));
  }
}
