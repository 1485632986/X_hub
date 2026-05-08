import { router } from '@kit.ArkUI';
import { media } from '@kit.MediaKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { EmbyApi } from '../services/EmbyApi';
import { SessionInfo, MediaItem, MediaSource } from '../models/EmbyTypes';

const TAG = 'PlayerPage';
const DOMAIN = 0xFF00;

@Entry
@Component
struct Player {
  @State streamUrl: string = '';
  @State title: string = '';
  @State isPlaying: boolean = false;
  @State isPrepared: boolean = false;
  @State showControls: boolean = true;
  @State currentTime: number = 0;
  @State totalDuration: number = 0;
  @State seekValue: number = 0;
  @State isSeeking: boolean = false;
  @State errorMsg: string = '';
  @State playerState: string = 'idle';
  @State surfaceReady: boolean = false;
  @State showCodecInfo: boolean = false;

  // Codec / MediaSource info for display
  @State codecName: string = '';
  @State resolution: string = '';
  @State bitrateDisplay: string = '';
  @State videoRange: string = 'SDR';
  @State isHardwareDecode: boolean = false;
  @State isFallbackMode: boolean = false;

  private avPlayer: media.AVPlayer | undefined = undefined;
  private controlsTimer: number = -1;
  private fallbackAttempt: number = 0;

  // Received from router
  private itemId: string = '';
  private session: SessionInfo = {
    serverUrl: '',
    accessToken: '',
    userId: '',
    userName: ''
  };

  // MediaSource data
  private mediaSource: MediaSource | undefined = undefined;
  private mediaItem: MediaItem | undefined = undefined;

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
  }

  aboutToDisappear(): void {
    this.clearControlsTimer();
    this.releasePlayer();
  }

  /**
   * Fetch MediaSource details, determine codec, and build the optimal stream URL.
   */
  async prepareStream(): Promise<void> {
    try {
      this.mediaItem = await EmbyApi.getItemDetail(this.session, this.itemId);
      hilog.info(DOMAIN, TAG, `Item detail loaded, MediaSources: ${this.mediaItem.MediaSources?.length || 0}`);

      if (this.mediaItem.MediaSources && this.mediaItem.MediaSources.length > 0) {
        this.mediaSource = this.mediaItem.MediaSources[0];

        const videoStream = EmbyApi.getVideoStream(this.mediaSource);
        if (videoStream) {
          this.codecName = videoStream.Codec || videoStream.VideoCodec || 'unknown';
          this.resolution = `${videoStream.Width || '?'}x${videoStream.Height || '?'}`;
          this.videoRange = videoStream.VideoRangeType || videoStream.VideoRange || 'SDR';

          if (this.mediaSource.Bitrate) {
            const mbps = (this.mediaSource.Bitrate / 1000000).toFixed(1);
            this.bitrateDisplay = `${mbps} Mbps`;
          }

          this.isHardwareDecode = true;
          this.isFallbackMode = false;

          hilog.info(DOMAIN, TAG,
            `Codec: ${this.codecName}, Res: ${this.resolution}, Range: ${this.videoRange}, Container: ${this.mediaSource.Container}`);
        }

        this.streamUrl = EmbyApi.getStreamUrl(this.session, this.itemId, this.mediaSource.Id);
      } else {
        this.streamUrl = EmbyApi.getStreamUrl(this.session, this.itemId);
      }

      hilog.info(DOMAIN, TAG, `Stream URL: ${this.streamUrl.substring(0, 120)}`);
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Failed to prepare stream: ${err}`);
      this.streamUrl = EmbyApi.getStreamUrl(this.session, this.itemId);
    }
  }

  /**
   * Initialize AVPlayer and start playback.
   * Called after XComponent surface is ready.
   */
  async initPlayer(): Promise<void> {
    try {
      // First, prepare the stream URL based on codec capabilities
      await this.prepareStream();

      if (!this.streamUrl) {
        this.errorMsg = '无法获取播放地址';
        return;
      }

      // Create hardware-accelerated AVPlayer
      this.avPlayer = await media.createAVPlayer();

      // State change handler
      this.avPlayer.on('stateChange', (state: string) => {
        this.playerState = state;
        hilog.info(DOMAIN, TAG, `AVPlayer state: ${state}`);

        switch (state) {
          case 'initialized':
            // Source URL is set, prepare the player (configures decoders)
            this.avPlayer!.prepare();
            break;

          case 'prepared':
            // Player is ready, hardware decoder is configured
            this.isPrepared = true;
            this.totalDuration = this.avPlayer!.duration;
            hilog.info(DOMAIN, TAG, `Prepared. Duration: ${this.totalDuration}ms`);
            // Auto-play
            this.avPlayer!.play();
            break;

          case 'playing':
            this.isPlaying = true;
            this.startControlsTimer();
            break;

          case 'paused':
            this.isPlaying = false;
            break;

          case 'stopped':
            this.isPlaying = false;
            this.isPrepared = false;
            break;

          case 'error':
            this.handlePlaybackError();
            break;

          default:
            break;
        }
      });

      // Time update handler for progress bar
      this.avPlayer.on('timeUpdate', (timeMs: number) => {
        if (!this.isSeeking) {
          this.currentTime = timeMs;
          this.seekValue = timeMs;
        }
      });

      // Error handler
      this.avPlayer.on('error', (err: BusinessError) => {
        hilog.error(DOMAIN, TAG, `AVPlayer error: ${err.message}`);
        this.handlePlaybackError();
      });

      // Set the stream URL — triggers state change to 'initialized'
      // AVPlayer automatically uses hardware decoding when available
      hilog.info(DOMAIN, TAG, `Setting stream URL: ${this.streamUrl.substring(0, 80)}...`);
      this.avPlayer.url = this.streamUrl;

    } catch (err) {
      hilog.error(DOMAIN, TAG, `Player init failed: ${err}`);
      this.errorMsg = `初始化播放器失败: ${err instanceof Error ? err.message : '未知错误'}`;
    }
  }

  /**
   * Handle playback error — try fallback strategies.
   * Attempt 0 = HLS, 1 = direct play, 2 = transcode, 3 = give up
   */
  private handlePlaybackError(): void {
    this.fallbackAttempt++;
    hilog.warn(DOMAIN, TAG, `Playback failed, fallback attempt ${this.fallbackAttempt}`);

    if (this.fallbackAttempt === 1 && this.mediaSource) {
      hilog.warn(DOMAIN, TAG, 'HLS failed, trying direct play');
      this.isFallbackMode = true;
      this.isHardwareDecode = false;
      this.codecName = '直接播放';

      this.streamUrl = EmbyApi.getDirectPlayUrl(this.session, this.itemId, this.mediaSource.Id);
      hilog.info(DOMAIN, TAG, `Direct play URL: ${this.streamUrl.substring(0, 100)}`);
      this.releasePlayer();
      this.retryWithUrl(this.streamUrl);
    } else if (this.fallbackAttempt === 2 && this.mediaSource) {
      hilog.warn(DOMAIN, TAG, 'Direct play failed, trying transcode');
      this.codecName = 'H.264 (转码)';

      this.streamUrl = EmbyApi.getTranscodeStreamUrl(
        this.session, this.itemId, this.mediaSource.Id, 'h264', 'aac', 1920
      );
      hilog.info(DOMAIN, TAG, `Transcode URL: ${this.streamUrl.substring(0, 100)}`);
      this.releasePlayer();
      this.retryWithUrl(this.streamUrl);
    } else {
      hilog.error(DOMAIN, TAG, 'All playback methods failed');
      this.errorMsg = '播放失败: 无法解码此视频';
      this.isPlaying = false;
    }
  }

  /**
   * Retry playback with a new URL (used for fallback).
   */
  private async retryWithUrl(url: string): Promise<void> {
    try {
      this.avPlayer = await media.createAVPlayer();

      this.avPlayer.on('stateChange', (state: string) => {
        this.playerState = state;
        switch (state) {
          case 'initialized':
            this.avPlayer!.prepare();
            break;
          case 'prepared':
            this.isPrepared = true;
            this.totalDuration = this.avPlayer!.duration;
            this.avPlayer!.play();
            break;
          case 'playing':
            this.isPlaying = true;
            this.startControlsTimer();
            break;
          case 'paused':
            this.isPlaying = false;
            break;
          case 'stopped':
            this.isPlaying = false;
            this.isPrepared = false;
            break;
          case 'error':
            this.handlePlaybackError();
            break;
          default:
            break;
        }
      });

      this.avPlayer.on('timeUpdate', (timeMs: number) => {
        if (!this.isSeeking) {
          this.currentTime = timeMs;
          this.seekValue = timeMs;
        }
      });

      this.avPlayer.on('error', (err: BusinessError) => {
        hilog.error(DOMAIN, TAG, `Fallback AVPlayer error: ${err.message}`);
        this.handlePlaybackError();
      });

      this.avPlayer.url = url;
    } catch (err) {
      this.errorMsg = `重试失败: ${err instanceof Error ? err.message : '未知错误'}`;
    }
  }

  releasePlayer(): void {
    if (this.avPlayer) {
      this.avPlayer.release();
      this.avPlayer = undefined;
    }
  }

  togglePlayPause(): void {
    if (!this.avPlayer || !this.isPrepared) {
      return;
    }
    if (this.isPlaying) {
      this.avPlayer.pause();
    } else {
      this.avPlayer.play();
    }
    this.resetControlsTimer();
  }

  seekTo(value: number): void {
    if (!this.avPlayer || !this.isPrepared) {
      return;
    }
    this.isSeeking = false;
    this.avPlayer.seek(Math.floor(value));
    this.currentTime = value;
  }

  onSeekChange(value: number): void {
    this.isSeeking = true;
    this.currentTime = value;
  }

  toggleControls(): void {
    this.showControls = !this.showControls;
    if (this.showControls) {
      this.startControlsTimer();
    }
  }

  startControlsTimer(): void {
    this.clearControlsTimer();
    this.controlsTimer = setTimeout(() => {
      this.showControls = false;
    }, 3000);
  }

  resetControlsTimer(): void {
    if (this.showControls) {
      this.startControlsTimer();
    }
  }

  clearControlsTimer(): void {
    if (this.controlsTimer !== -1) {
      clearTimeout(this.controlsTimer);
      this.controlsTimer = -1;
    }
  }

  formatTime(ms: number): string {
    const totalSeconds = Math.floor(ms / 1000);
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = totalSeconds % 60;
    const pad = (n: number): string => n.toString().padStart(2, '0');
    if (hours > 0) {
      return `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`;
    }
    return `${pad(minutes)}:${pad(seconds)}`;
  }

  build() {
    Stack() {
      // ── Video Surface ──
      XComponent({ id: 'video_surface', type: 'surface', libraryname: '' })
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .onLoad(() => {
          this.surfaceReady = true;
          this.initPlayer();
        })

      // ── Tap to toggle controls ──
      Column()
        .width('100%')
        .height('100%')
        .onClick(() => {
          this.toggleControls();
        })

      // ── Error Overlay ──
      if (this.errorMsg) {
        Column() {
          Text(this.errorMsg)
            .fontSize(16)
            .fontColor('#F44336')
            .margin({ bottom: 16 })
          if (this.isFallbackMode) {
            Text('已尝试服务器转码，仍然失败')
              .fontSize(13)
              .fontColor('#B3B3B3')
              .margin({ bottom: 16 })
          }
          Text(`URL: ${this.streamUrl.substring(0, 80)}...`)
            .fontSize(10)
            .fontColor('#666666')
            .margin({ bottom: 16 })
            .width('90%')
          Button('返回')
            .type(ButtonType.Capsule)
            .width(120)
            .height(40)
            .backgroundColor('#4FC3F7')
            .onClick(() => {
              router.back();
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#000000CC')
      }

      // ── Loading Indicator ──
      if (!this.isPrepared && !this.errorMsg) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color('#4FC3F7')
          Text(this.isFallbackMode ? '正在切换到转码播放...' : '正在加载...')
            .fontSize(14)
            .fontColor('#FFFFFF')
            .margin({ top: 12 })
          if (this.streamUrl) {
            Text(this.streamUrl.substring(0, 60))
              .fontSize(10)
              .fontColor('#666666')
              .margin({ top: 8 })
              .width('80%')
              .textAlign(TextAlign.Center)
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }

      // ── Codec Info Overlay ──
      if (this.showCodecInfo) {
        Column() {
          Row() {
            Text('解码信息')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
            Blank()
            Text('✕')
              .fontSize(18)
              .fontColor('#FFFFFF')
              .onClick(() => { this.showCodecInfo = false; })
          }
          .width('100%')
          .margin({ bottom: 16 })

          this.CodecInfoRow('编码格式', this.codecName || '检测中...')
          this.CodecInfoRow('分辨率', this.resolution || '检测中...')
          this.CodecInfoRow('码率', this.bitrateDisplay || '检测中...')
          this.CodecInfoRow('动态范围', this.videoRange)
          this.CodecInfoRow('硬件解码', this.isHardwareDecode ? '✓ 启用' : '✗ 软解/转码')
          if (this.isFallbackMode) {
            this.CodecInfoRow('播放模式', '服务器转码')
          } else {
            this.CodecInfoRow('播放模式', '直接播放')
          }
        }
        .width('85%')
        .padding(20)
        .backgroundColor('#1E1E1EEE')
        .borderRadius(12)
      }

      // ── Playback Controls ──
      if (this.showControls && this.isPrepared) {
        Column() {
          // Top bar: back button + title + codec info button
          Row() {
            Text('←')
              .fontSize(24)
              .fontColor('#FFFFFF')
              .padding(12)
              .onClick(() => { router.back(); })

            Text(this.title)
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
              .margin({ left: 8 })

            // Codec info button
            Text('ℹ')
              .fontSize(20)
              .fontColor('#FFFFFF')
              .padding(12)
              .onClick(() => { this.showCodecInfo = !this.showCodecInfo; })
          }
          .width('100%')
          .height(56)
          .padding({ left: 8, right: 8 })
          .alignItems(VerticalAlign.Center)
          .backgroundColor('#00000066')

          // Codec badge (top-left, below title bar)
          if (this.codecName || this.isFallbackMode) {
            Row() {
              Text(this.isFallbackMode ? '转码' : this.codecName.toUpperCase())
                .fontSize(10)
                .fontColor('#FFFFFF')
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .backgroundColor(this.isHardwareDecode ? '#4CAF5066' : '#FF980066')
                .borderRadius(4)

              if (this.isHardwareDecode) {
                Text('HW')
                  .fontSize(10)
                  .fontColor('#FFFFFF')
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .backgroundColor('#4CAF5066')
                  .borderRadius(4)
                  .margin({ left: 6 })
              }

              if (this.videoRange !== 'SDR') {
                Text(this.videoRange)
                  .fontSize(10)
                  .fontColor('#FFFFFF')
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .backgroundColor('#FF980066')
                  .borderRadius(4)
                  .margin({ left: 6 })
              }
            }
            .width('100%')
            .padding({ left: 16 })
            .margin({ top: 4 })
          }

          // Spacer
          Blank()

          // Center play/pause button
          Text(this.isPlaying ? '⏸' : '▶')
            .fontSize(56)
            .fontColor('#FFFFFF')
            .onClick(() => { this.togglePlayPause(); })

          // Spacer
          Blank()

          // Bottom bar: seek bar + time
          Column() {
            Slider({
              value: this.seekValue,
              min: 0,
              max: this.totalDuration,
              step: 1000
            })
              .blockColor('#4FC3F7')
              .trackColor('#444444')
              .selectedColor('#4FC3F7')
              .width('100%')
              .height(24)
              .onChange((value: number, mode: SliderChangeMode) => {
                this.onSeekChange(value);
                if (mode === SliderChangeMode.End) {
                  this.seekTo(value);
                }
              })

            Row() {
              Text(this.formatTime(this.currentTime))
                .fontSize(12)
                .fontColor('#FFFFFF')

              Blank()

              Text(this.formatTime(this.totalDuration))
                .fontSize(12)
                .fontColor('#FFFFFF')
            }
            .width('100%')
            .padding({ left: 4, right: 4 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 24, top: 8 })
          .backgroundColor('#00000066')
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }

  /**
   * Helper builder for codec info display rows
   */
  @Builder
  CodecInfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#B3B3B3')
        .width(90)
      Text(value)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .layoutWeight(1)
    }
    .width('100%')
    .margin({ bottom: 10 })
  }
}
