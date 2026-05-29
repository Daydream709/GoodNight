/**
 * 加速度传感器监听服务
 * 使用 @kit.SensorServiceKit 监测设备移动
 */
import { sensor } from '@kit.SensorServiceKit';
import { ISensorMonitorService, SensorEventCallback } from '../../interface/ISensorMonitorService';
import { MOVEMENT_THRESHOLD, ACCELEROMETER_INTERVAL } from '../../common/Constants';
import { logInfo, logError } from '../../common/Logger';

export class SensorMonitorService implements ISensorMonitorService {
  private movementEventCount: number = 0;
  private maxAcceleration: number = 0;
  private monitoring: boolean = false;
  private callback: SensorEventCallback | null = null;

  startMonitoring(callback: SensorEventCallback): void {
    this.callback = callback;
    this.movementEventCount = 0;
    this.maxAcceleration = 0;

    try {
      sensor.on(sensor.SensorId.ACCELEROMETER, (data: sensor.AccelerometerResponse) => {
        if (!this.monitoring) {
          return;
        }
        // 计算加速度向量模长：sqrt(x² + y² + z²)
        const magnitude = Math.sqrt(
          data.x * data.x + data.y * data.y + data.z * data.z
        );

        // 记录最大加速度
        if (magnitude > this.maxAcceleration) {
          this.maxAcceleration = magnitude;
        }

        // 超过阈值视为显著移动
        if (magnitude > MOVEMENT_THRESHOLD) {
          this.movementEventCount++;
          logInfo('Movement detected: %{public}s m/s², count: %{public}s',
            magnitude.toFixed(2), this.movementEventCount.toString());
          this.callback?.onSignificantMovement(magnitude);
        }
      }, { interval: ACCELEROMETER_INTERVAL });

      this.monitoring = true;
      logInfo('SensorMonitorService started');
    } catch (err) {
      logError('Failed to start sensor monitoring: %{public}s', JSON.stringify(err));
    }
  }

  stopMonitoring(): void {
    if (this.monitoring) {
      try {
        sensor.off(sensor.SensorId.ACCELEROMETER);
        logInfo('SensorMonitorService stopped, movements: %{public}s, maxAcc: %{public}s',
          this.movementEventCount.toString(), this.maxAcceleration.toFixed(2));
      } catch (err) {
        logError('Failed to stop sensor: %{public}s', JSON.stringify(err));
      }
      this.monitoring = false;
    }
    this.callback = null;
  }

  getMovementEventCount(): number {
    return this.movementEventCount;
  }

  resetMovementEventCount(): void {
    this.movementEventCount = 0;
    this.maxAcceleration = 0;
  }

  /**
   * 获取记录的最大加速度值
   */
  getMaxAcceleration(): number {
    return this.maxAcceleration;
  }
}
