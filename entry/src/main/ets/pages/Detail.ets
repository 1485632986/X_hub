import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { EmbyApi } from '../services/EmbyApi';
import { SessionInfo, MediaItem, PersonInfo } from '../models/EmbyTypes';

const TAG = 'DetailPage';
const DOMAIN = 0xFF00;

@Entry
@Component
struct Detail {
  @State item: MediaItem | undefined = undefined;
  @State isLoading: boolean = true;
  @State errorMsg: string = '';
  @State isWatchlisted: boolean = false;

  private itemId: string = '';
  private title: string = '';
  private session: SessionInfo = { serverUrl: '', accessToken: '', userId: '', userName: '' };

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    if (params) {
      this.itemId = params['itemId'] || '';
      this.title = params['title'] || '';
      this.session = {
        serverUrl: params['serverUrl'] || '',
        accessToken: params['accessToken'] || '',
        userId: params['userId'] || '',
        userName: params['userName'] || ''
      };
    }
    this.loadDetail();
  }

  async loadDetail(): Promise<void> {
    this.isLoading = true;
    this.errorMsg = '';
    try {
      this.item = await EmbyApi.getItemDetailFull(this.session, this.itemId);
    } catch (err) {
      this.errorMsg = err instanceof Error ? err.message : '加载失败';
    } finally {
      this.isLoading = false;
    }
  }

  navigateToPlayer(): void {
    if (!this.item) {
      return;
    }
    router.pushUrl({
      url: 'pages/Player',
      params: {
        itemId: this.item.Id,
        title: this.item.Name,
        serverUrl: this.session.serverUrl,
        accessToken: this.session.accessToken,
        userId: this.session.userId,
        userName: this.session.userName
      }
    });
  }

  formatDuration(ticks: number): string {
    const totalMinutes = Math.floor(ticks / 10000000 / 60);
    const hours = Math.floor(totalMinutes / 60);
    const minutes = totalMinutes % 60;
    if (hours > 0 && minutes > 0) {
      return `${hours}小时${minutes}分钟`;
    }
    if (hours > 0) {
      return `${hours}小时`;
    }
    return `${minutes}分钟`;
  }

  getDirector(): string {
    if (!this.item?.People) {
      return '';
    }
    const directors: PersonInfo[] = this.item.People.filter((p: PersonInfo) => p.Type === 'Director');
    return directors.map((d: PersonInfo) => d.Name).join(' / ');
  }

  getActors(): string {
    if (!this.item?.People) {
      return '';
    }
    const actors: PersonInfo[] = this.item.People.filter((p: PersonInfo) => p.Type === 'Actor');
    return actors.slice(0, 5).map((a: PersonInfo) => a.Name).join(' / ');
  }

  build() {
    Column() {
      if (this.isLoading) {
        Column() {
          LoadingProgress().width(48).height(48).color('#4FC3F7')
          Text('加载中...').fontSize(14).fontColor('#B3B3B3').margin({ top: 12 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#121212')
      } else if (this.errorMsg) {
        Column() {
          Text(this.errorMsg).fontSize(16).fontColor('#F44336').margin({ bottom: 16 })
          Button('重试').type(ButtonType.Capsule).width(120).height(40).backgroundColor('#4FC3F7')
            .onClick(() => { this.loadDetail(); })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#121212')
      } else if (this.item) {
        Column() {
          Scroll() {
            Column() {
              Stack({ alignContent: Alignment.BottomStart }) {
                if (this.item.BackdropImageTags && this.item.BackdropImageTags.length > 0) {
                  Image(EmbyApi.getBackdropUrl(this.session, this.item.Id, this.item.BackdropImageTags[0], 1280))
                    .width('100%')
                    .height(240)
                    .objectFit(ImageFit.Cover)
                } else if (this.item.ImageTags?.Primary) {
                  Image(EmbyApi.getImageUrl(this.session, this.item.Id, this.item.ImageTags.Primary, 600))
                    .width('100%')
                    .height(240)
                    .objectFit(ImageFit.Cover)
                } else {
                  Column()
                    .width('100%')
                    .height(240)
                    .backgroundColor('#1E1E1E')
                }

                Row() {
                  Text('←')
                    .fontSize(24)
                    .fontColor('#FFFFFF')
                    .padding(12)
                    .onClick(() => { router.back(); })
                }
                .width('100%')
                .padding({ top: 44 })

                Row() {
                  Column() {
                    Row({ space: 6 }) {
                      if (this.item.CommunityRating) {
                        Text(`★ ${this.item.CommunityRating.toFixed(1)}`)
                          .fontSize(12)
                          .fontColor('#FFC107')
                          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                          .backgroundColor('#00000099')
                          .borderRadius(4)
                      }
                      if (this.item.ProductionYear) {
                        Text(`${this.item.ProductionYear}`)
                          .fontSize(12)
                          .fontColor('#FFFFFF')
                          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                          .backgroundColor('#00000099')
                          .borderRadius(4)
                      }
                      if (this.item.RunTimeTicks) {
                        Text(this.formatDuration(this.item.RunTimeTicks))
                          .fontSize(12)
                          .fontColor('#FFFFFF')
                          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                          .backgroundColor('#00000099')
                          .borderRadius(4)
                      }
                      if (this.item.OfficialRating) {
                        Text(this.item.OfficialRating)
                          .fontSize(12)
                          .fontColor('#FFFFFF')
                          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                          .backgroundColor('#00000099')
                          .borderRadius(4)
                      }
                    }
                  }
                  .layoutWeight(1)
                  .padding({ left: 16, bottom: 12 })
                }
                .width('100%')
              }
              .width('100%')

              Column() {
                Text(this.item.Name)
                  .fontSize(24)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFFFFF')
                  .width('100%')
                  .margin({ bottom: 16 })

                if (this.item.Genres && this.item.Genres.length > 0) {
                  Row({ space: 8 }) {
                    ForEach(this.item.Genres, (genre: string) => {
                      Text(genre)
                        .fontSize(12)
                        .fontColor('#4FC3F7')
                        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                        .borderRadius(12)
                        .backgroundColor('#4FC3F722')
                    })
                  }
                  .width('100%')
                  .margin({ bottom: 16 })
                }

                if (this.getDirector()) {
                  this.MetaRow('导演', this.getDirector())
                }
                if (this.getActors()) {
                  this.MetaRow('主演', this.getActors())
                }
                if (this.item.Studios && this.item.Studios.length > 0) {
                  this.MetaRow('制片', this.item.Studios.join(' / '))
                }

                if (this.item.Overview) {
                  Column() {
                    Text('剧情简介')
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#FFFFFF')
                      .margin({ bottom: 8 })
                    Text(this.item.Overview)
                      .fontSize(14)
                      .fontColor('#B3B3B3')
                      .lineHeight(22)
                  }
                  .width('100%')
                  .margin({ top: 16 })
                }
              }
              .width('100%')
              .padding(16)
            }
          }
          .scrollBar(BarState.Off)
          .layoutWeight(1)

          Row() {
            Button() {
              Text(this.isWatchlisted ? '♥' : '♡')
                .fontSize(22)
                .fontColor(this.isWatchlisted ? '#F44336' : '#FFFFFF')
            }
            .type(ButtonType.Circle)
            .width(48)
            .height(48)
            .backgroundColor('#252525')
            .onClick(() => { this.isWatchlisted = !this.isWatchlisted; })

            Button('立即播放')
              .type(ButtonType.Capsule)
              .layoutWeight(1)
              .height(48)
              .backgroundColor('#4FC3F7')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#000000')
              .margin({ left: 12 })
              .onClick(() => { this.navigateToPlayer(); })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 24 })
          .backgroundColor('#1E1E1E')
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#121212')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#121212')
  }

  @Builder
  MetaRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#666666')
        .width(50)
      Text(value)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .layoutWeight(1)
    }
    .width('100%')
    .margin({ bottom: 10 })
  }
}
