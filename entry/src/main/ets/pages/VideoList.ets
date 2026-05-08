import { router } from '@kit.ArkUI';
import { EmbyApi } from '../services/EmbyApi';
import { CodecCapabilityService } from '../services/CodecCapabilityService';
import { SessionInfo, MediaItem, ItemsResponse, MediaSource } from '../models/EmbyTypes';

@Entry
@Component
struct VideoList {
  @State items: MediaItem[] = [];
  @State isLoading: boolean = true;
  @State errorMsg: string = '';
  @State userName: string = '';

  private session: SessionInfo = {
    serverUrl: '',
    accessToken: '',
    userId: '',
    userName: ''
  };

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    if (params) {
      this.session = {
        serverUrl: params['serverUrl'] || '',
        accessToken: params['accessToken'] || '',
        userId: params['userId'] || '',
        userName: params['userName'] || ''
      };
      this.userName = this.session.userName;
      this.loadItems();
    } else {
      this.isLoading = false;
      this.errorMsg = '未获取到登录信息';
    }
  }

  async loadItems(): Promise<void> {
    this.isLoading = true;
    this.errorMsg = '';
    try {
      const result: ItemsResponse = await EmbyApi.getVideoItems(this.session, 0, 50);
      this.items = result.Items.filter(
        (item: MediaItem) => !item.IsFolder && item.MediaType === 'Video'
      );
      if (this.items.length === 0) {
        this.errorMsg = '没有找到视频';
      }
    } catch (err) {
      if (err instanceof Error) {
        this.errorMsg = `加载失败: ${err.message}`;
      } else {
        this.errorMsg = '加载失败: 未知错误';
      }
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * Navigate to Player page, passing itemId + session info.
   * The Player will fetch MediaSource details and determine the optimal
   * hardware decode pipeline.
   */
  navigateToPlayer(item: MediaItem): void {
    router.pushUrl({
      url: 'pages/Player',
      params: {
        itemId: item.Id,
        title: item.Name,
        serverUrl: this.session.serverUrl,
        accessToken: this.session.accessToken,
        userId: this.session.userId,
        userName: this.session.userName
      }
    });
  }

  /**
   * Extract a brief codec summary from the item's MediaSources (if available).
   * Returns e.g. "H.265 · 4K" or empty string if no info.
   */
  private getCodecSummary(item: MediaItem): string {
    if (!item.MediaSources || item.MediaSources.length === 0) {
      return '';
    }
    const source = item.MediaSources[0];
    const videoStream = source.MediaStreams?.find((s) => s.Type === 'Video');
    if (!videoStream) {
      return '';
    }
    const codec = videoStream.Codec || videoStream.VideoCodec || '';
    const codecName = CodecCapabilityService.getCodecDisplayName(codec);
    const res = videoStream.Height ? `${videoStream.Height}p` : '';
    const parts: string[] = [];
    if (codecName) {
      parts.push(codecName);
    }
    if (res) {
      parts.push(res);
    }
    return parts.join(' · ');
  }

  @Builder
  PosterImage(item: MediaItem) {
    if (item.ImageTags?.Primary) {
      Image(EmbyApi.getImageUrl(this.session, item.Id, item.ImageTags.Primary, 120))
        .width(90)
        .height(135)
        .borderRadius(6)
        .objectFit(ImageFit.Cover)
    } else {
      Column() {
        Text('🎬')
          .fontSize(32)
      }
      .width(90)
      .height(135)
      .borderRadius(6)
      .backgroundColor('#333333')
      .justifyContent(FlexAlign.Center)
    }
  }

  build() {
    Column() {
      Row() {
        Text('视频列表')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')

        Blank()

        Text(this.userName)
          .fontSize(14)
          .fontColor('#B3B3B3')
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color('#4FC3F7')
          Text('加载中...')
            .fontSize(14)
            .fontColor('#B3B3B3')
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.errorMsg) {
        Column() {
          Text(this.errorMsg)
            .fontSize(16)
            .fontColor('#F44336')
            .margin({ bottom: 16 })
          Button('重试')
            .type(ButtonType.Capsule)
            .width(120)
            .height(40)
            .backgroundColor('#4FC3F7')
            .onClick(() => { this.loadItems(); })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 8 }) {
          ForEach(this.items, (item: MediaItem) => {
            ListItem() {
              Row() {
                this.PosterImage(item)

                Column() {
                  Text(item.Name)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#FFFFFF')
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ bottom: 6 })

                  if (item.ProductionYear) {
                    Text(`${item.ProductionYear}`)
                      .fontSize(13)
                      .fontColor('#B3B3B3')
                      .margin({ bottom: 4 })
                  }

                  if (item.CommunityRating) {
                    Row() {
                      Text('⭐')
                        .fontSize(12)
                      Text(`${item.CommunityRating.toFixed(1)}`)
                        .fontSize(13)
                        .fontColor('#FFC107')
                    }
                    .margin({ bottom: 4 })
                  }

                  // Codec info badge (e.g. "H.265 · 1080p")
                  if (this.getCodecSummary(item)) {
                    Text(this.getCodecSummary(item))
                      .fontSize(11)
                      .fontColor('#4FC3F7')
                      .margin({ bottom: 4 })
                  }

                  if (item.RunTimeTicks) {
                    Text(this.formatDuration(item.RunTimeTicks))
                      .fontSize(12)
                      .fontColor('#666666')
                  }
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .margin({ left: 12 })
              }
              .width('100%')
              .padding(12)
              .backgroundColor('#252525')
              .borderRadius(12)
            }
            .onClick(() => { this.navigateToPlayer(item); })
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 8, bottom: 16 })
        .divider({ strokeWidth: 0 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#121212')
  }

  private formatDuration(ticks: number): string {
    const totalSeconds = Math.floor(ticks / 10000000);
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    if (hours > 0) {
      return `${hours}h ${minutes}m`;
    }
    return `${minutes}m`;
  }
}
