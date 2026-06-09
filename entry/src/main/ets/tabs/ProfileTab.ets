/**
 * 我的 Tab - 个人设置（液态玻璃风格）
 */
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { IAuthService } from '../interface/IAuthService';
import { DatabaseRepository } from '../service/data/DatabaseRepository';
import { AppColors, ColorPalette } from '../common/AppColors';
import { EVENT_LOGOUT } from '../common/Constants';
import { logError } from '../common/Logger';

@Component
export struct ProfileTab {
  @StorageLink('isDarkMode') isDarkMode: boolean = false;
  @State username: string = '';
  @State avatarPath: string = '';
  @State editUsername: string = '';
  @State isEditingUsername: boolean = false;
  @State oldPassword: string = '';
  @State newPassword: string = '';
  @State confirmPassword: string = '';
  @State isChangingPassword: boolean = false;
  @State statusMsg: string = '';
  @State statusIsError: boolean = false;
  @State cycleCount: number = 0;
  @State totalReturned: number = 0;
  // 防止异步操作（改名/改密/换头像）被快速重复点击并发提交
  @State busy: boolean = false;
  // 入场淡入，与首页/统计页 Tab 切换体验一致
  @State appeared: boolean = false;
  @StorageLink('dataVersion') @Watch('onDataVersionChanged') dataVersion: number = 0;

  private authService: IAuthService | null = null;
  private dbRepo: DatabaseRepository | null = null;

  async aboutToAppear(): Promise<void> {
    this.authService = AppStorage.get<IAuthService>('authService') ?? null;
    this.dbRepo = AppStorage.get<DatabaseRepository>('dbRepo') ?? null;
    this.loadUserInfo();
    animateTo({ duration: 420, curve: Curve.EaseOut }, () => { this.appeared = true; });
    await this.loadSummary();
  }

  onDataVersionChanged(): void {
    this.loadSummary();
  }

  private async loadSummary(): Promise<void> {
    if (!this.dbRepo) { return; }
    try {
      this.cycleCount = await this.dbRepo.getCycleCount();
      this.totalReturned = await this.dbRepo.getTotalReturnedPoints();
    } catch (err) {
      logError('Load summary failed: %{public}s', (err as Error).message ?? '');
    }
  }

  private colors(): ColorPalette {
    return AppColors.current(this.isDarkMode);
  }

  build() {
    Scroll() {
      Column() {
        Text('我的')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colors().textPrimary)
          .margin({ top: 16, bottom: 24 })
          .width('100%')
          .padding({ left: 20 })

        // 头像卡片 - 液态玻璃
        Column() {
          if (this.avatarPath) {
            Image(this.avatarPath)
              .width(80)
              .height(80)
              .borderRadius(40)
              .objectFit(ImageFit.Cover)
          } else {
            Column() {
              Text('\uD83D\uDC64')
                .fontSize(36)
            }
            .width(80)
            .height(80)
            .borderRadius(40)
            .backgroundColor(this.colors().avatarPlaceholder)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          }
          Text('更换头像')
            .fontSize(13)
            .fontColor(this.colors().primary)
            .margin({ top: 8 })
        }
        .width('90%')
        .padding(20)
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 16 })
        .backgroundColor(this.colors().glassBg)
        .borderRadius(20)
        .border({ width: 1, color: this.colors().glassBorder })
        .backdropBlur(this.colors().glassBlur)
        .onClick(() => {
          this.pickAvatar();
        })

        // 账号汇总卡片
        Row() {
          Column() {
            Text('累计周期').fontSize(12).fontColor(this.colors().textSecondary)
            Text(`${this.cycleCount}`).fontSize(28).fontWeight(FontWeight.Bold)
              .fontColor(this.colors().textPrimary).margin({ top: 4 })
          }
          .layoutWeight(1).alignItems(HorizontalAlign.Center)
          Divider().vertical(true).height(40).color(this.colors().divider)
          Column() {
            Text('累计赚回').fontSize(12).fontColor(this.colors().textSecondary)
            Text(`${this.totalReturned}`).fontSize(28).fontWeight(FontWeight.Bold)
              .fontColor(this.colors().success).margin({ top: 4 })
          }
          .layoutWeight(1).alignItems(HorizontalAlign.Center)
        }
        .width('90%')
        .padding(20)
        .backgroundColor(this.colors().glassBg)
        .borderRadius(20)
        .border({ width: 1, color: this.colors().glassBorder })
        .backdropBlur(this.colors().glassBlur)
        .margin({ bottom: 16 })

        // 用户名卡片 - 液态玻璃
        Column() {
          Row() {
            Text('用户名')
              .fontSize(14)
              .fontColor(this.colors().textSecondary)
              .width(70)
            if (this.isEditingUsername) {
              TextInput({ text: this.editUsername })
                .layoutWeight(1)
                .height(40)
                .fontSize(16)
                .borderRadius(8)
                .backgroundColor(this.colors().glassInputBg)
                .maxLength(20)
                .onChange((value: string) => { this.editUsername = value; })
            } else {
              Text(this.username)
                .fontSize(16)
                .fontColor(this.colors().textPrimary)
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            Button(this.isEditingUsername ? '保存' : '修改')
              .height(32)
              .fontSize(13)
              .fontColor(this.colors().primary)
              .backgroundColor(Color.Transparent)
              .enabled(!this.busy)
              .onClick(() => {
                if (this.isEditingUsername) {
                  this.doUpdateUsername();
                } else {
                  this.editUsername = this.username;
                  this.isEditingUsername = true;
                }
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        }
        .width('90%')
        .backgroundColor(this.colors().glassBg)
        .borderRadius(20)
        .border({ width: 1, color: this.colors().glassBorder })
        .backdropBlur(this.colors().glassBlur)
        .margin({ bottom: 16 })

        // 修改密码卡片 - 液态玻璃
        Column() {
          Row() {
            Text('修改密码')
              .fontSize(16)
              .fontColor(this.colors().textPrimary)
              .layoutWeight(1)
            Text(this.isChangingPassword ? '收起 \u25B2' : '展开 \u25BC')
              .fontSize(14)
              .fontColor(this.colors().primary)
              .onClick(() => {
                this.isChangingPassword = !this.isChangingPassword;
              })
          }
          .width('100%')
          .padding(16)

          if (this.isChangingPassword) {
            Column({ space: 12 }) {
              TextInput({ placeholder: '当前密码' })
                .height(44)
                .fontSize(15)
                .borderRadius(8)
                .backgroundColor(this.colors().glassInputBg)
                .type(InputType.Password)
                .maxLength(32)
                .onChange((value: string) => { this.oldPassword = value; })
              TextInput({ placeholder: '新密码（至少4位）' })
                .height(44)
                .fontSize(15)
                .borderRadius(8)
                .backgroundColor(this.colors().glassInputBg)
                .type(InputType.Password)
                .maxLength(32)
                .onChange((value: string) => { this.newPassword = value; })
              TextInput({ placeholder: '确认新密码' })
                .height(44)
                .fontSize(15)
                .borderRadius(8)
                .backgroundColor(this.colors().glassInputBg)
                .type(InputType.Password)
                .maxLength(32)
                .onChange((value: string) => { this.confirmPassword = value; })
              Button('确认修改')
                .width('100%')
                .height(44)
                .fontSize(16)
                .fontColor(Color.White)
                .backgroundColor(this.colors().primary)
                .borderRadius(8)
                .enabled(!this.busy)
                .onClick(() => { this.doChangePassword(); })
            }
            .padding({ left: 16, right: 16, bottom: 16 })
          }
        }
        .width('90%')
        .backgroundColor(this.colors().glassBg)
        .borderRadius(20)
        .border({ width: 1, color: this.colors().glassBorder })
        .backdropBlur(this.colors().glassBlur)
        .margin({ bottom: 16 })
        .alignItems(HorizontalAlign.Start)

        // 状态消息 - 药丸提示
        if (this.statusMsg) {
          Row() {
            Text(this.statusIsError ? '⚠️' : '✓')
              .fontSize(13)
            Text(this.statusMsg)
              .fontSize(13)
              .fontColor(this.statusIsError ? this.colors().danger : this.colors().success)
              .margin({ left: 6 })
          }
          .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          .backgroundColor(this.colors().glassInputBg)
          .borderRadius(16)
          .margin({ bottom: 16 })
          .alignItems(VerticalAlign.Center)
        }

        // 设置 / 关于 入口
        Column() {
          this.EntryRow('⚙️', '设置', () => { router.pushUrl({ url: 'pages/SettingsPage' }); })
          Divider().color(this.colors().divider).margin({ left: 16, right: 16 })
          this.EntryRow('ℹ️', '关于好梦', () => { router.pushUrl({ url: 'pages/AboutPage' }); })
        }
        .width('90%')
        .backgroundColor(this.colors().glassBg)
        .borderRadius(20)
        .border({ width: 1, color: this.colors().glassBorder })
        .backdropBlur(this.colors().glassBlur)
        .margin({ bottom: 16 })

        // 登出按钮 - 液态玻璃
        Button('退出登录')
          .width('90%')
          .height(48)
          .fontSize(16)
          .fontColor(this.colors().danger)
          .backgroundColor(this.colors().glassBg)
          .borderRadius(20)
          .border({ width: 1, color: this.colors().glassBorder })
          .backdropBlur(this.colors().glassBlur)
          .margin({ top: 16, bottom: 24 })
          .onClick(() => { this.confirmLogout(); })
      }
      .alignItems(HorizontalAlign.Center)
      .opacity(this.appeared ? 1 : 0)
      .translate({ y: this.appeared ? 0 : 14 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors().background)
  }

  @Builder
  EntryRow(icon: string, label: string, onTap: () => void): void {
    Row() {
      Text(icon).fontSize(18)
      Text(label).fontSize(16).fontColor(this.colors().textPrimary).margin({ left: 12 }).layoutWeight(1)
      Text('›').fontSize(20).fontColor(this.colors().textSecondary)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .alignItems(VerticalAlign.Center)
    .onClick(onTap)
  }

  private loadUserInfo(): void {
    if (this.authService && this.authService.getCurrentUser()) {
      const user = this.authService.getCurrentUser()!;
      this.username = user.username;
      this.avatarPath = user.avatarPath;
    }
  }

  private async doUpdateUsername(): Promise<void> {
    if (!this.authService || this.busy) { return; }
    const name = this.editUsername.trim();
    if (name.length < 2) {
      this.statusMsg = '用户名至少2个字符';
      this.statusIsError = true;
      return;
    }
    this.busy = true;
    try {
      const ok = await this.authService.updateUsername(name);
      if (ok) {
        this.username = name;
        this.editUsername = name;
        this.isEditingUsername = false;
        this.statusMsg = '用户名修改成功';
        this.statusIsError = false;
      } else {
        this.statusMsg = '用户名已被占用';
        this.statusIsError = true;
      }
    } finally {
      this.busy = false;
    }
  }

  private async doChangePassword(): Promise<void> {
    if (!this.authService || this.busy) { return; }
    if (this.newPassword.length < 4) {
      this.statusMsg = '新密码至少4位';
      this.statusIsError = true;
      return;
    }
    if (this.newPassword !== this.confirmPassword) {
      this.statusMsg = '两次密码不一致';
      this.statusIsError = true;
      return;
    }
    this.busy = true;
    try {
      const ok = await this.authService.updatePassword(this.oldPassword, this.newPassword);
      if (ok) {
        this.oldPassword = '';
        this.newPassword = '';
        this.confirmPassword = '';
        this.isChangingPassword = false;
        this.statusMsg = '密码修改成功';
        this.statusIsError = false;
      } else {
        this.statusMsg = '当前密码错误';
        this.statusIsError = true;
      }
    } finally {
      this.busy = false;
    }
  }

  private async pickAvatar(): Promise<void> {
    if (this.busy) { return; }
    this.busy = true;
    try {
      const context = this.getUIContext().getHostContext() as Context;
      const options: photoAccessHelper.PhotoSelectOptions = {
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      };
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(options);
      if (result.photoUris.length > 0) {
        const srcUri: string = result.photoUris[0];
        const userId: number = this.authService?.getCurrentUser()?.id ?? 0;
        const destPath: string = context.filesDir + '/avatar_' + userId + '.jpg';
        // 复制到沙箱
        const srcFile: fs.File = fs.openSync(srcUri, fs.OpenMode.READ_ONLY);
        const destFile: fs.File = fs.openSync(destPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
        const statResult: fs.Stat = fs.statSync(srcFile.fd);
        const buf: ArrayBuffer = new ArrayBuffer(statResult.size);
        fs.readSync(srcFile.fd, buf);
        fs.writeSync(destFile.fd, buf);
        fs.closeSync(srcFile);
        fs.closeSync(destFile);

        this.avatarPath = destPath;
        if (this.authService) {
          await this.authService.updateAvatar(destPath);
        }
        this.statusMsg = '头像已更新';
        this.statusIsError = false;
      }
    } catch (err) {
      const msg = (err as Error).message ?? '';
      if (msg.indexOf('Cancel') >= 0) {
        // 用户取消选择，不报错
        return;
      }
      logError('Avatar pick failed: %{public}s', msg);
      this.statusMsg = '头像选择失败';
      this.statusIsError = true;
    } finally {
      this.busy = false;
    }
  }

  private confirmLogout(): void {
    AlertDialog.show({
      title: '退出登录',
      message: '退出后将停止今晚的睡眠监测，确定要退出吗？',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      secondaryButton: {
        value: '取消',
        action: () => {}
      },
      primaryButton: {
        value: '退出',
        fontColor: this.colors().danger,
        action: () => {
          this.handleLogout();
        }
      }
    });
  }

  private async handleLogout(): Promise<void> {
    // 通知 EntryAbility 停止监测并清理后台任务
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    ctx.eventHub.emit(EVENT_LOGOUT);
    if (this.authService) {
      await this.authService.logout();
    }
    router.replaceUrl({ url: 'pages/LoginPage' });
  }
}
