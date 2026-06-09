/**
 * 登录页面
 * 接入 AppColors 主题体系，支持深浅色模式，与主功能区视觉统一
 */
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { DatabaseRepository } from '../service/data/DatabaseRepository';
import { AuthService } from '../service/auth/AuthService';
import { TestDataGenerator } from '../common/TestDataGenerator';
import { AppColors, ColorPalette } from '../common/AppColors';
import { AppSettings } from '../common/AppSettings';
import { EVENT_LOGIN_SUCCESS, ENABLE_DEV_TOOLS } from '../common/Constants';
import { logError } from '../common/Logger';

@Entry
@Component
struct LoginPage {
  @StorageLink('isDarkMode') isDarkMode: boolean = false;
  @State username: string = '';
  @State password: string = '';
  @State rememberAccount: boolean = false;
  @State autoLogin: boolean = false;
  @State isLoading: boolean = false;
  @State errorMsg: string = '';
  @State testMsg: string = '';

  private authService: AuthService | null = null;
  private dbRepo: DatabaseRepository = new DatabaseRepository();

  async aboutToAppear(): Promise<void> {
    PersistentStorage.persistProp('isDarkMode', false);
    try {
      const context = this.getUIContext().getHostContext() as Context;
      await this.dbRepo.init(context);
      this.authService = new AuthService(this.dbRepo);
      await this.authService.loadConfigCache();
      // 加载可配置设置（睡眠窗口/阈值/通知）
      const store = this.dbRepo.getStore();
      if (store) { await AppSettings.load(store); }

      // 预填记住的账号
      if (this.authService.isRememberAccount()) {
        this.rememberAccount = true;
        this.username = this.authService.getSavedUsername();
        this.autoLogin = this.authService.isAutoLogin();
      }

      // 尝试自动登录
      if (this.authService.isAutoLogin()) {
        this.isLoading = true;
        const success = await this.authService.tryAutoLogin();
        if (success) {
          this.navigateToMain();
          return;
        }
        this.isLoading = false;
      }
    } catch (err) {
      logError('LoginPage init failed: %{public}s', (err as Error).message ?? '');
    }
  }

  private colors(): ColorPalette {
    return AppColors.current(this.isDarkMode);
  }

  build() {
    Column() {
      // 品牌标题
      Text('好梦')
        .fontSize(40)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.colors().primary)
        .margin({ top: 96, bottom: 8 })
      Text('Good Night')
        .fontSize(15)
        .fontColor(this.colors().textSecondary)
        .margin({ bottom: 40 })

      // 表单卡片 - 液态玻璃
      Column({ space: 16 }) {
        TextInput({ placeholder: '请输入用户名', text: this.username })
          .height(48)
          .fontSize(16)
          .fontColor(this.colors().textPrimary)
          .borderRadius(12)
          .backgroundColor(this.colors().glassInputBg)
          .type(InputType.Normal)
          .maxLength(20)
          .onChange((value: string) => {
            this.username = value;
            this.errorMsg = '';
          })

        TextInput({ placeholder: '请输入密码', text: this.password })
          .height(48)
          .fontSize(16)
          .fontColor(this.colors().textPrimary)
          .borderRadius(12)
          .backgroundColor(this.colors().glassInputBg)
          .type(InputType.Password)
          .showPasswordIcon(true)
          .maxLength(32)
          .onChange((value: string) => {
            this.password = value;
            this.errorMsg = '';
          })

        // 记住账号 + 自动登录
        Row() {
          Row() {
            Checkbox()
              .select(this.rememberAccount)
              .selectedColor(this.colors().primary)
              .onChange((checked: boolean) => {
                this.rememberAccount = checked;
                if (!checked) {
                  this.autoLogin = false;
                }
              })
            Text('记住账号')
              .fontSize(13)
              .fontColor(this.colors().textSecondary)
              .margin({ left: 2 })
          }

          Blank()

          Row() {
            Checkbox()
              .select(this.autoLogin)
              .selectedColor(this.colors().primary)
              .onChange((checked: boolean) => {
                this.autoLogin = checked;
                if (checked) {
                  this.rememberAccount = true; // 自动登录需记住账号
                }
              })
            Text('自动登录')
              .fontSize(13)
              .fontColor(this.colors().textSecondary)
              .margin({ left: 2 })
          }
        }
        .width('100%')

        if (this.errorMsg) {
          Text(this.errorMsg)
            .fontSize(13)
            .fontColor(this.colors().danger)
        }

        Button() {
          if (this.isLoading) {
            Row({ space: 8 }) {
              LoadingProgress().width(22).height(22).color(Color.White)
              Text('登录中…').fontSize(18).fontColor(Color.White)
            }
          } else {
            Text('登录').fontSize(18).fontColor(Color.White)
          }
        }
        .width('100%')
        .height(48)
        .backgroundColor(this.colors().primary)
        .borderRadius(12)
        .enabled(!this.isLoading && this.username.length > 0 && this.password.length > 0)
        .onClick(() => {
          this.handleLogin();
        })
      }
      .width('86%')
      .padding(24)
      .backgroundColor(this.colors().glassBg)
      .borderRadius(20)
      .border({ width: 1, color: this.colors().glassBorder })
      .backdropBlur(this.colors().glassBlur)

      // 注册链接
      Text('没有账号？点击注册')
        .fontSize(14)
        .fontColor(this.colors().primary)
        .margin({ top: 24 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/RegisterPage' });
        })

      // 开发工具：生成测试数据（仅 ENABLE_DEV_TOOLS 时显示）
      if (ENABLE_DEV_TOOLS) {
        Text('生成测试数据')
          .fontSize(12)
          .fontColor(this.colors().textSecondary)
          .margin({ top: 32 })
          .onClick(() => {
            this.handleGenerateTestData();
          })

        if (this.testMsg) {
          Text(this.testMsg)
            .fontSize(12)
            .fontColor(this.colors().success)
            .margin({ top: 4 })
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors().background)
    .alignItems(HorizontalAlign.Center)
  }

  private async handleLogin(): Promise<void> {
    if (!this.authService) {
      this.errorMsg = '服务未就绪';
      return;
    }

    // 与注册时的 trim 保持一致，避免首尾空格导致匹配不到已存用户名
    const name = this.username.trim();
    this.isLoading = true;
    this.errorMsg = '';

    try {
      const success = await this.authService.login(name, this.password);
      if (success) {
        await this.authService.setRememberAccount(this.rememberAccount);
        await this.authService.setAutoLogin(this.autoLogin);
        if (this.rememberAccount) {
          await this.authService.saveUsername(name);
        }
        this.navigateToMain();
      } else {
        this.errorMsg = '用户名或密码错误';
      }
    } catch (err) {
      this.errorMsg = '登录失败，请重试';
      logError('Login failed: %{public}s', (err as Error).message ?? '');
    }
    this.isLoading = false;
  }

  private navigateToMain(): void {
    // 将 dbRepo 和 authService 存入 AppStorage（全局共享单实例）
    AppStorage.setOrCreate('dbRepo', this.dbRepo);
    AppStorage.setOrCreate('authService', this.authService);

    // 通知 EntryAbility 构建监测服务链（共享同一 dbRepo，含已设置的 currentUserId）
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    ctx.eventHub.emit(EVENT_LOGIN_SUCCESS);

    router.replaceUrl({ url: 'pages/Index' });
  }

  private async handleGenerateTestData(): Promise<void> {
    const store = this.dbRepo.getStore();
    if (!store) {
      this.testMsg = '数据库未就绪';
      return;
    }
    this.testMsg = '正在生成...';
    const ok = await TestDataGenerator.generate(store);
    this.testMsg = ok ? '已生成 test01 用户及一年数据' : '生成失败';
  }
}
