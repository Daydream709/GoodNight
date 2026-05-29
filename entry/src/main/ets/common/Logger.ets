/**
 * 日志工具封装 - 基于 hilog
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import { LOG_DOMAIN, LOG_TAG } from './Constants';

export function logInfo(format: string, ...args: string[]): void {
  hilog.info(LOG_DOMAIN, LOG_TAG, format, ...args);
}

export function logError(format: string, ...args: string[]): void {
  hilog.error(LOG_DOMAIN, LOG_TAG, format, ...args);
}

export function logDebug(format: string, ...args: string[]): void {
  hilog.debug(LOG_DOMAIN, LOG_TAG, format, ...args);
}

export function logWarn(format: string, ...args: string[]): void {
  hilog.warn(LOG_DOMAIN, LOG_TAG, format, ...args);
}
