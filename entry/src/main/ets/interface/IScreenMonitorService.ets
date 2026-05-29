/**
 * 屏幕事件监听接口
 */
export interface ScreenEventCallback {
  /** 屏幕亮起回调 */
  onScreenOn(): void;
  /** 屏幕熄灭回调 */
  onScreenOff(): void;
}

export interface IScreenMonitorService {
  /** 开始监听屏幕事件 */
  startMonitoring(callback: ScreenEventCallback): void;

  /** 停止监听 */
  stopMonitoring(): void;

  /** 获取累计亮屏次数 */
  getScreenOnCount(): number;

  /** 重置亮屏计数 */
  resetScreenOnCount(): void;
}
