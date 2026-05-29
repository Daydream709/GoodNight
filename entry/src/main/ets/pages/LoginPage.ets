/**
 * 登录页面
 */
import { router } from '@kit.ArkUI';
import { DatabaseRepository } from '../service/data/DatabaseRepository';
import { AuthService } from '../service/auth/AuthService';
import { logInfo, logError } from '../common/Logger';

@Entry
@Component
struct LoginPage {
  @State username: string = '';
  @State password: string = '';
  @State rememberPassword: boolean = false;
  @State autoLogin: boolean = false;
  @State isLoading: boolean = false;
  @State errorMsg: string = '';

  private authService: AuthService | null = null;
  private dbRepo: DatabaseRepository = new DatabaseRepository();

  async aboutToAppear(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as Context;
      await this.dbRepo.init(context);
      this.authService = new AuthService(this.dbRepo);
      await this.authService.loadConfigCache();

      // 填充记住的用户名密码
      if (this.authService.isRememberPassword()) {
        this.rememberPassword = true;
        this.username = this.authService.getSavedUsername();
        // 记住密码时恢复密码字段（用 hash 标记占位）
        if (this.authService.getSavedPasswordHash()) {
          this.password = '••••••••'; // 占位符，表示有保存的密码
        }
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

  build() {
    Column() {
      // 标题
      Text('好梦')
        .fontSize(36)
        .fontWeight(FontWeight.Bold)
        .fontColor('#6C5CE7')
        .margin({ top: 80, bottom: 8 })
      Text('Good Night')
        .fontSize(16)
        .fontColor('#636E72')
        .margin({ bottom: 48 })

      // 用户名输入
      TextInput({ placeholder: '请输入用户名', text: this.username })
        .width('80%')
        .height(48)
        .fontSize(16)
        .borderRadius(12)
        .backgroundColor(Color.White)
        .type(InputType.Normal)
        .onChange((value: string) => {
          this.username = value;
          this.errorMsg = '';
        })

      // 密码输入
      TextInput({ placeholder: '请输入密码', text: this.password })
        .width('80%')
        .height(48)
        .fontSize(16)
        .borderRadius(12)
        .backgroundColor(Color.White)
        .type(InputType.Password)
        .margin({ top: 16 })
        .onChange((value: string) => {
          this.password = value;
          this.errorMsg = '';
        })

      // 记住密码 + 自动登录
      Row() {
        Row() {
          Checkbox()
            .select(this.rememberPassword)
            .onChange((checked: boolean) => {
              this.rememberPassword = checked;
            })
          Text('记住密码')
            .fontSize(13)
            .fontColor('#636E72')
            .margin({ left: 4 })
        }

        Blank()

        Row() {
          Checkbox()
            .select(this.autoLogin)
            .onChange((checked: boolean) => {
              this.autoLogin = checked;
              if (checked) {
                this.rememberPassword = true; // 自动登录必须记住密码
              }
            })
          Text('自动登录')
            .fontSize(13)
            .fontColor('#636E72')
            .margin({ left: 4 })
        }
      }
      .width('80%')
      .margin({ top: 16 })

      // 错误信息
      if (this.errorMsg) {
        Text(this.errorMsg)
          .fontSize(13)
          .fontColor('#E17055')
          .margin({ top: 12 })
      }

      // 登录按钮
      Button('登录')
        .width('80%')
        .height(48)
        .fontSize(18)
        .fontColor(Color.White)
        .backgroundColor('#6C5CE7')
        .borderRadius(12)
        .margin({ top: 32 })
        .enabled(!this.isLoading && this.username.length > 0 && this.password.length > 0)
        .onClick(() => {
          this.handleLogin();
        })

      // 注册链接
      Text('没有账号？点击注册')
        .fontSize(14)
        .fontColor('#6C5CE7')
        .margin({ top: 24 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/RegisterPage' });
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F0F2F5')
    .alignItems(HorizontalAlign.Center)
  }

  private async handleLogin(): Promise<void> {
    if (!this.authService) {
      this.errorMsg = '服务未就绪';
      return;
    }

    this.isLoading = true;
    this.errorMsg = '';

    try {
      // 如果密码是占位符，用保存的 hash 直接登录
      const savedHash = this.authService.getSavedPasswordHash();
      const actualPassword = this.password;

      const success = await this.authService.login(this.username, actualPassword);
      if (success) {
        // 保存设置
        await this.authService.setRememberPassword(this.rememberPassword);
        await this.authService.setAutoLogin(this.autoLogin);
        if (this.rememberPassword) {
          // 保存凭据供下次填充
          await this.authService.saveCredentials(this.username, '');
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
    // 将 dbRepo 和 authService 存入 AppStorage
    AppStorage.setOrCreate('dbRepo', this.dbRepo);
    AppStorage.setOrCreate('authService', this.authService);

    router.replaceUrl({ url: 'pages/Index' });
  }
}
