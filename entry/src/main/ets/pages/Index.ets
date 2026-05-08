import { router } from '@kit.ArkUI';
import { EmbyApi } from '../services/EmbyApi';
import { SessionInfo } from '../models/EmbyTypes';

@Entry
@Component
struct Index {
  @State serverUrl: string = '';
  @State username: string = '';
  @State password: string = '';
  @State isLoading: boolean = false;
  @State errorMsg: string = '';

  async handleConnect(): Promise<void> {
    if (!this.serverUrl.trim()) {
      this.errorMsg = '请输入服务器地址';
      return;
    }
    if (!this.username.trim()) {
      this.errorMsg = '请输入用户名';
      return;
    }
    if (!this.password) {
      this.errorMsg = '请输入密码';
      return;
    }

    this.isLoading = true;
    this.errorMsg = '';

    try {
      const session: SessionInfo = await EmbyApi.login(
        this.serverUrl.trim(),
        this.username.trim(),
        this.password
      );

      router.pushUrl({
        url: 'pages/VideoList',
        params: {
          serverUrl: session.serverUrl,
          accessToken: session.accessToken,
          userId: session.userId,
          userName: session.userName
        }
      });
    } catch (err) {
      if (err instanceof Error) {
        this.errorMsg = `连接失败: ${err.message}`;
      } else {
        this.errorMsg = '连接失败: 未知错误';
      }
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      Blank()

      Text('Emby')
        .fontSize(36)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .margin({ bottom: 8 })

      Text('连接到您的媒体服务器')
        .fontSize(14)
        .fontColor('#B3B3B3')
        .margin({ bottom: 48 })

      TextInput({ placeholder: '服务器地址 (如 http://192.168.1.100:8096)', text: this.serverUrl })
        .type(InputType.URL)
        .onChange((value: string) => { this.serverUrl = value; })
        .width('90%')
        .height(48)
        .backgroundColor('#252525')
        .borderRadius(8)
        .fontColor('#FFFFFF')
        .placeholderColor('#666666')
        .padding({ left: 16, right: 16 })
        .margin({ bottom: 16 })
        .enabled(!this.isLoading)

      TextInput({ placeholder: '用户名', text: this.username })
        .type(InputType.Normal)
        .onChange((value: string) => { this.username = value; })
        .width('90%')
        .height(48)
        .backgroundColor('#252525')
        .borderRadius(8)
        .fontColor('#FFFFFF')
        .placeholderColor('#666666')
        .padding({ left: 16, right: 16 })
        .margin({ bottom: 16 })
        .enabled(!this.isLoading)

      TextInput({ placeholder: '密码', text: this.password })
        .type(InputType.Password)
        .onChange((value: string) => { this.password = value; })
        .width('90%')
        .height(48)
        .backgroundColor('#252525')
        .borderRadius(8)
        .fontColor('#FFFFFF')
        .placeholderColor('#666666')
        .padding({ left: 16, right: 16 })
        .margin({ bottom: 24 })
        .enabled(!this.isLoading)

      Button(this.isLoading ? '连接中...' : '连接')
        .type(ButtonType.Capsule)
        .width('90%')
        .height(48)
        .backgroundColor(this.isLoading ? '#1E88E5' : '#4FC3F7')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .onClick(() => { this.handleConnect(); })
        .enabled(!this.isLoading)

      if (this.isLoading) {
        LoadingProgress()
          .width(40)
          .height(40)
          .color('#4FC3F7')
          .margin({ top: 16 })
      }

      if (this.errorMsg) {
        Text(this.errorMsg)
          .fontSize(14)
          .fontColor('#F44336')
          .margin({ top: 16 })
          .width('90%')
          .textAlign(TextAlign.Center)
      }

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#121212')
  }
}
