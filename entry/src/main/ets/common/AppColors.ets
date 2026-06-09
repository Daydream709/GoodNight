/**
 * 主题颜色配置 - 亮色 / 暗色
 */

export interface ColorPalette {
  background: string;
  cardBg: string;
  textPrimary: string;
  textSecondary: string;
  primary: string;
  success: string;
  danger: string;
  progressTrack: string;
  inputBg: string;
  divider: string;
  tabBarBg: string;
  avatarPlaceholder: string;
  glassBg: string;
  glassBorder: string;
  glassInputBg: string;
  glassBlur: number;
}

export class AppColors {
  static readonly light: ColorPalette = {
    background: '#F0F2F5',
    cardBg: '#FFFFFF',
    textPrimary: '#2D3436',
    textSecondary: '#636E72',
    primary: '#6C5CE7',
    success: '#00B894',
    danger: '#E17055',
    progressTrack: '#DFE6E9',
    inputBg: '#F0F2F5',
    divider: '#DFE6E9',
    tabBarBg: '#FFFFFF',
    avatarPlaceholder: '#DFE6E9',
    // 浅色模式下卡片为不透明白底 + 浅灰描边（无毛玻璃，blur 对实色无意义）
    glassBg: '#FFFFFF',
    glassBorder: '#E8EAED',
    glassInputBg: '#F0F2F5',
    glassBlur: 0,
  };

  static readonly dark: ColorPalette = {
    background: '#000000',
    cardBg: '#16213E',
    textPrimary: '#EAEAEA',
    textSecondary: '#A0A0B0',
    primary: '#A78BFA',
    success: '#34D399',
    danger: '#F87171',
    progressTrack: '#2D3748',
    inputBg: '#0F3460',
    divider: '#2D3748',
    tabBarBg: '#0F3460',
    avatarPlaceholder: '#2D3748',
    glassBg: '#18FFFFFF',
    glassBorder: '#30FFFFFF',
    glassInputBg: '#10FFFFFF',
    glassBlur: 24,
  };

  static current(isDark: boolean): ColorPalette {
    return isDark ? AppColors.dark : AppColors.light;
  }
}
