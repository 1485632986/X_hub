import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { EmbyApi } from '../services/EmbyApi';
import { SessionInfo, MediaItem, ServerInfo, ActiveSession } from '../models/EmbyTypes';

const TAG = 'MainPage';
const DOMAIN = 0xFF00;

interface CategoryConfig {
  name: string;
  includeItemTypes: string;
  sortBy: string;
  genre?: string;
  filters?: string;
}

const CATEGORIES: CategoryConfig[] = [
  { name: '最新电影', includeItemTypes: 'Movie', sortBy: 'DateCreated' },
  { name: '最新动漫', includeItemTypes: 'Series', sortBy: 'DateCreated', genre: 'Animation' },
  { name: '最新剧集', includeItemTypes: 'Series', sortBy: 'DateCreated' },
  { name: '最新纪录片', includeItemTypes: 'Movie', sortBy: 'DateCreated', genre: 'Documentary' },
  { name: '最近观看', includeItemTypes: 'Movie,Episode', sortBy: 'DatePlayed', filters: 'IsPlayed' },
];

@Entry
@Component
struct Main {
  @State currentTab: number = 0;
  @State session: SessionInfo = { serverUrl: '', accessToken: '', userId: '', userName: '' };

  @State serverInfo: ServerInfo | undefined = undefined;
  @State activeSessions: ActiveSession[] = [];
  @State serverLoading: boolean = true;
  @State serverError: string = '';

  @State selectedCategory: number = 0;
  @State currentItems: MediaItem[] = [];
  @State mediaLoading: boolean = true;
  @State mediaError: string = '';
  private itemCache: Map<number, MediaItem[]> = new Map();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    if (params) {
      this.session = {
        serverUrl: params['serverUrl'] || '',
        accessToken: params['accessToken'] || '',
        userId: params['userId'] || '',
        userName: params['userName'] || ''
      };
    }
    this.loadServerInfo();
    this.loadCategory(0);
  }

  async loadServerInfo(): Promise<void> {
    this.serverLoading = true;
    this.serverError = '';
    try {
      const results = await Promise.all([
        EmbyApi.getServerInfo(this.session),
        EmbyApi.getActiveSessions(this.session)
      ]);
      this.serverInfo = results[0];
      this.activeSessions = results[1];
    } catch (err) {
      this.serverError = err instanceof Error ? err.message : '加载失败';
    } finally {
      this.serverLoading = false;
    }
  }

  async loadCategory(index: number): Promise<void> {
    const cached = this.itemCache.get(index);
    if (cached) {
      this.currentItems = cached;
      this.mediaLoading = false;
      return;
    }
    this.mediaLoading = true;
    this.mediaError = '';
    try {
      const cat = CATEGORIES[index];
      const result = await EmbyApi.getItemsByCategory(
        this.session, cat.includeItemTypes, cat.sortBy, 'Descending',
        cat.genre, 20, cat.filters ?? 'IsNotFolder'
      );
      this.currentItems = result.Items;
      this.itemCache.set(index, this.currentItems);
    } catch (err) {
      this.mediaError = err instanceof Error ? err.message : '加载失败';
    } finally {
      this.mediaLoading = false;
    }
  }

  selectCategory(index: number): void {
    this.selectedCategory = index;
    this.loadCategory(index);
  }

  navigateToDetail(item: MediaItem): void {
    router.pushUrl({
      url: 'pages/Detail',
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

  formatDuration(ticks: number): string {
    const totalMinutes = Math.floor(ticks / 10000000 / 60);
    const hours = Math.floor(totalMinutes / 60);
    const minutes = totalMinutes % 60;
    if (hours > 0) {
      return `${hours}h ${minutes}m`;
    }
    return `${minutes}m`;
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
      TabContent() {
        this.ServerInfoTab()
      }
      .tabBar(this.TabItem('资源库', 0))

      TabContent() {
        this.MediaLibraryTab()
      }
      .tabBar(this.TabItem('媒体库', 1))
    }
    .barWidth('100%')
    .barHeight(56)
    .scrollable(false)
    .backgroundColor('#121212')
    .onChange((index: number) => {
      this.currentTab = index;
    })
  }

  @Builder
  TabItem(label: string, index: number) {
    Column() {
      Text(label)
        .fontSize(this.currentTab === index ? 15 : 13)
        .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentTab === index ? '#4FC3F7' : '#888888')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  ServerInfoTab() {
    Column() {
      Row() {
        Text('资源库')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
        Blank()
        Text(this.session.userName)
          .fontSize(14)
          .fontColor('#B3B3B3')
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      if (this.serverLoading) {
        Column() {
          LoadingProgress().width(48).height(48).color('#4FC3F7')
          Text('加载中...').fontSize(14).fontColor('#B3B3B3').margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.serverError) {
        Column() {
          Text(this.serverError).fontSize(16).fontColor('#F44336').margin({ bottom: 16 })
          Button('重试').type(ButtonType.Capsule).width(120).height(40).backgroundColor('#4FC3F7')
            .onClick(() => { this.loadServerInfo(); })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            Column() {
              Row() {
                Column() {
                  Text(this.serverInfo?.ServerName || 'Emby Server')
                    .fontSize(20)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FFFFFF')
                  Text(`v${this.serverInfo?.Version || '?'}`)
                    .fontSize(12)
                    .fontColor('#666666')
                    .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Column() {
                  Row() {
                    Circle({ width: 8, height: 8 }).fill('#4CAF50').margin({ right: 6 })
                    Text('在线').fontSize(12).fontColor('#4CAF50')
                  }
                }
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .backgroundColor('#4CAF5022')
                .borderRadius(12)
              }
              .width('100%')
              .margin({ bottom: 20 })

              this.InfoDivider()

              this.InfoRow('连接地址', this.session.serverUrl)
              this.InfoRow('用户名', this.session.userName)
              this.InfoRow('用户ID', this.session.userId)
              this.InfoRow('服务器版本', this.serverInfo?.Version || '未知')
              this.InfoRow('操作系统', this.serverInfo?.OperatingSystem || '未知')

              this.InfoDivider()

              Row() {
                Text('活跃设备')
                  .fontSize(14)
                  .fontColor('#B3B3B3')
                Blank()
                Text(`${this.activeSessions.length} 台`)
                  .fontSize(14)
                  .fontColor('#4FC3F7')
                  .fontWeight(FontWeight.Medium)
              }
              .width('100%')
              .margin({ top: 12 })

              if (this.activeSessions.length > 0) {
                Column() {
                  ForEach(this.activeSessions, (session: ActiveSession) => {
                    Row() {
                      Column() {
                        Text(session.DeviceName || '未知设备')
                          .fontSize(13)
                          .fontColor('#FFFFFF')
                        Text(session.Client || '')
                          .fontSize(11)
                          .fontColor('#666666')
                          .margin({ top: 2 })
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)
                    }
                    .width('100%')
                    .padding({ top: 8, bottom: 8 })
                  })
                }
                .width('100%')
                .margin({ top: 8 })
              }
            }
            .width('100%')
            .padding(20)
            .backgroundColor('#1E1E1E')
            .borderRadius(16)
          }
          .width('100%')
          .padding(16)
        }
        .scrollBar(BarState.Off)
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#121212')
  }

  @Builder
  InfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#B3B3B3')
        .width(90)
      Text(value)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .layoutWeight(1)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .margin({ top: 12 })
  }

  @Builder
  InfoDivider() {
    Divider().color('#333333').margin({ top: 4, bottom: 4 })
  }

  @Builder
  MediaLibraryTab() {
    Column() {
      Row() {
        Text('媒体库')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Row({ space: 8 }) {
          ForEach(CATEGORIES, (cat: CategoryConfig, index: number) => {
            Text(cat.name)
              .fontSize(13)
              .fontColor(this.selectedCategory === index ? '#FFFFFF' : '#B3B3B3')
              .fontWeight(this.selectedCategory === index ? FontWeight.Medium : FontWeight.Normal)
              .padding({ left: 16, right: 16, top: 8, bottom: 8 })
              .borderRadius(20)
              .backgroundColor(this.selectedCategory === index ? '#4FC3F7' : '#252525')
              .onClick(() => { this.selectCategory(index); })
          })
        }
        .padding({ left: 16, right: 16 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .margin({ bottom: 12 })

      if (this.mediaLoading) {
        Column() {
          LoadingProgress().width(48).height(48).color('#4FC3F7')
          Text('加载中...').fontSize(14).fontColor('#B3B3B3').margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.mediaError) {
        Column() {
          Text(this.mediaError).fontSize(14).fontColor('#F44336').margin({ bottom: 16 })
          Button('重试').type(ButtonType.Capsule).width(120).height(36).backgroundColor('#4FC3F7')
            .onClick(() => { this.loadCategory(this.selectedCategory); })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.currentItems.length === 0) {
        Column() {
          Text('暂无内容').fontSize(14).fontColor('#666666')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Grid() {
          ForEach(this.currentItems, (item: MediaItem) => {
            GridItem() {
              this.MediaCard(item)
            }
          }, (item: MediaItem) => item.Id)
        }
        .columnsTemplate('1fr 1fr 1fr')
        .columnsGap(10)
        .rowsGap(16)
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#121212')
  }

  @Builder
  MediaCard(item: MediaItem) {
    Column() {
      Stack({ alignContent: Alignment.BottomStart }) {
        if (item.ImageTags?.Primary) {
          Image(EmbyApi.getImageUrl(this.session, item.Id, item.ImageTags.Primary, 300))
            .width('100%')
            .aspectRatio(2 / 3)
            .borderRadius(8)
            .objectFit(ImageFit.Cover)
        } else {
          Column() {
            Text('🎬').fontSize(32)
          }
          .width('100%')
          .aspectRatio(2 / 3)
          .borderRadius(8)
          .backgroundColor('#333333')
          .justifyContent(FlexAlign.Center)
        }

        if (item.CommunityRating) {
          Row() {
            Text(`★ ${item.CommunityRating.toFixed(1)}`)
              .fontSize(10)
              .fontColor('#FFC107')
              .fontWeight(FontWeight.Medium)
          }
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor('#00000099')
          .borderRadius(4)
          .margin({ left: 6, bottom: 6 })
        }
      }
      .width('100%')

      Text(item.Name)
        .fontSize(12)
        .fontColor('#FFFFFF')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 6 })
        .width('100%')

      if (item.ProductionYear || item.RunTimeTicks) {
        Row() {
          if (item.ProductionYear) {
            Text(`${item.ProductionYear}`)
              .fontSize(10)
              .fontColor('#888888')
          }
          if (item.ProductionYear && item.RunTimeTicks) {
            Text(' · ')
              .fontSize(10)
              .fontColor('#555555')
          }
          if (item.RunTimeTicks) {
            Text(this.formatDuration(item.RunTimeTicks))
              .fontSize(10)
              .fontColor('#888888')
          }
        }
        .margin({ top: 4 })
        .width('100%')
      }
    }
    .width('100%')
    .onClick(() => { this.navigateToDetail(item); })
  }
}
