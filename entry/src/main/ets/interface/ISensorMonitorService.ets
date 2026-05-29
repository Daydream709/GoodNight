/**
 * 加速度传感器监听接口
 */
export interface SensorEventCallback {
  /** 检测到显著移动 */
  onSignificantMovement(accelerationMagnitude: number): void;
}

export interface ISensorMonitorService {
  /** 开始监听加速度传感器 */
  startMonitoring(callback: SensorEventCallback): void;

  /** 停止监听 */
  stopMonitoring(): void;

  /** 获取累计显著移动事件次数 */
  getMovementEventCount(): number;

  /** 重置移动计数 */
  resetMovementEventCount(): void;

  /** 获取记录的最大加速度值 */
  getMaxAcceleration(): number;
}
