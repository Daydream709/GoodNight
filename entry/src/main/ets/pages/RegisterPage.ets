/**
 * 注册页面
 */
import { router } from '@kit.ArkUI';
import { DatabaseRepository } from '../service/data/DatabaseRepository';
import { AuthService } from '../service/auth/AuthService';
import { logError } from '../common/Logger';

@Entry
@Component
struct RegisterPage {
  @State username: string = '';
  @State password: string = '';
  @State confirmPassword: string = '';
  @State isLoading: boolean = false;
  @State errorMsg: string = '';

  private dbRepo: DatabaseRepository = new DatabaseRepository();
  private authService: AuthService | null = null;

  async aboutToAppear(): Promise<void> {
    // 复用已初始化的 dbRepo（从 AppStorage 获取），或新建
    const existingRepo = AppStorage.get<DatabaseRepository>('dbRepo');
    if (existingRepo) {
      this.dbRepo = existingRepo;
    } else {
      const context = this.getUIContext().getHostContext() as Context;
      await this.dbRepo.init(context);
    }
    this.authService = new AuthService(this.dbRepo);
    await this.authService.loadConfigCache();
  }

  build() {
    Column() {
      // 返回按钮
      Row() {
        Text('< 返回登录')
          .fontSize(14)
          .fontColor('#6C5CE7')
          .margin({ left: 20, top: 16 })
          .onClick(() => {
            router.back();
          })
      }
      .width('100%')

      // 标题
      Text('注册账号')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2D3436')
        .margin({ top: 60, bottom: 48 })

      // 用户名
      TextInput({ placeholder: '用户名（至少 2 个字符）', text: this.username })
        .width('80%')
        .height(48)
        .fontSize(16)
        .borderRadius(12)
        .backgroundColor(Color.White)
        .onChange((value: string) => {
          this.username = value;
          this.errorMsg = '';
        })

      // 密码
      TextInput({ placeholder: '密码（至少 4 个字符）', text: this.password })
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

      // 确认密码
      TextInput({ placeholder: '确认密码', text: this.confirmPassword })
        .width('80%')
        .height(48)
        .fontSize(16)
        .borderRadius(12)
        .backgroundColor(Color.White)
        .type(InputType.Password)
        .margin({ top: 16 })
        .onChange((value: string) => {
          this.confirmPassword = value;
          this.errorMsg = '';
        })

      // 错误信息
      if (this.errorMsg) {
        Text(this.errorMsg)
          .fontSize(13)
          .fontColor('#E17055')
          .margin({ top: 12 })
      }

      // 注册按钮
      Button('注册')
        .width('80%')
        .height(48)
        .fontSize(18)
        .fontColor(Color.White)
        .backgroundColor('#6C5CE7')
        .borderRadius(12)
        .margin({ top: 32 })
        .enabled(!this.isLoading && this.username.length >= 2 &&
          this.password.length >= 4 && this.confirmPassword.length > 0)
        .onClick(() => {
          this.handleRegister();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F0F2F5')
    .alignItems(HorizontalAlign.Center)
  }

  private async handleRegister(): Promise<void> {
    if (!this.authService) {
      this.errorMsg = '服务未就绪';
      return;
    }

    if (this.password !== this.confirmPassword) {
      this.errorMsg = '两次密码输入不一致';
      return;
    }

    this.isLoading = true;
    this.errorMsg = '';

    try {
      const success = await this.authService.register(this.username, this.password);
      if (success) {
        // 注册成功，自动登录
        await this.authService.login(this.username, this.password);

        // 存入 AppStorage 并跳转主页
        AppStorage.setOrCreate('dbRepo', this.dbRepo);
        AppStorage.setOrCreate('authService', this.authService);

        router.replaceUrl({ url: 'pages/Index' });
      } else {
        this.errorMsg = '注册失败，用户名可能已存在';
      }
    } catch (err) {
      this.errorMsg = '注册失败，请重试';
      logError('Register failed: %{public}s', (err as Error).message ?? '');
    }
    this.isLoading = false;
  }
}
