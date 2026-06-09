/**
 * 轻量 Toast 反馈封装（基于 promptAction）
 */
import { promptAction } from '@kit.ArkUI';
import { logError } from './Logger';

export function showToast(message: string, durationMs: number = 2000): void {
  try {
    promptAction.showToast({
      message: message,
      duration: durationMs,
      bottom: 80
    });
  } catch (err) {
    logError('showToast failed: %{public}s', (err as Error).message ?? '');
  }
}
