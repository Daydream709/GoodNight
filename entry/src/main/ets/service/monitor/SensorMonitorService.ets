/**
 * 加速度传感器监听服务
 * 使用 @kit.SensorServiceKit 监测设备移动
 */
import { sensor } from '@kit.SensorServiceKit';
import { ISensorMonitorService, SensorEventCallback } from '../../interface/ISensorMonitorService';
import { MOVEMENT_THRESHOLD, MOVEMENT_DELTA_HIGH, MOVEMENT_DELTA_LOW, ACCELEROMETER_INTERVAL } from '../../common/Constants';
import { logInfo, logError } from '../../common/Logger';

export class SensorMonitorService implements ISensorMonitorService {
  private movementEventCount: number = 0;
  private maxAcceleration: number = 0;
  private monitoring: boolean = false;
  private callback: SensorEventCallback | null = null;
  // 相邻采样状态（差值法，捕捉摇晃 + 旋转）
  private prevX: number = 0;
  private prevY: number = 0;
  private prevZ: number = 0;
  private hasPrev: boolean = false;
  private inMotion: boolean = false;

  startMonitoring(callback: SensorEventCallback): void {
    this.callback = callback;
    this.movementEventCount = 0;
    this.maxAcceleration = 0;
    this.hasPrev = false;
    this.inMotion = false;

    try {
      sensor.on(sensor.SensorId.ACCELEROMETER, (data: sensor.AccelerometerResponse) => {
        if (!this.monitoring) {
          return;
        }
        const magnitude = Math.sqrt(data.x * data.x + data.y * data.y + data.z * data.z);
        if (magnitude > this.maxAcceleration) {
          this.maxAcceleration = magnitude;
        }

        // 相邻采样三轴差值之和：摇一摇（模长突变）与左右旋转（重力分量重新分布）都会产生大差值
        if (this.hasPrev) {
          const delta = Math.abs(data.x - this.prevX) + Math.abs(data.y - this.prevY) + Math.abs(data.z - this.prevZ);
          // 突发剧烈摇晃也直接计入
          const violent = magnitude > MOVEMENT_THRESHOLD;
          if ((delta > MOVEMENT_DELTA_HIGH || violent) && !this.inMotion) {
            this.movementEventCount++;
            this.inMotion = true;
            logInfo('Movement detected: delta=%{public}s, count=%{public}s',
              delta.toFixed(2), this.movementEventCount.toString());
            this.callback?.onSignificantMovement(delta);
          } else if (delta < MOVEMENT_DELTA_LOW) {
            this.inMotion = false; // 回到静止，可记下一次
          }
        }
        this.prevX = data.x;
        this.prevY = data.y;
        this.prevZ = data.z;
        this.hasPrev = true;
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
    this.hasPrev = false;
    this.inMotion = false;
  }

  /**
   * 获取记录的最大加速度值
   */
  getMaxAcceleration(): number {
    return this.maxAcceleration;
  }
}
