import { router } from '@kit.ArkUI';
import { media } from '@kit.MediaKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { webview } from '@kit.ArkWeb';
import { socket } from '@kit.NetworkKit';
import nativePlayer from 'libembyplayer.so';
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
  @State useWebView: boolean = false;
  private webController: webview.WebviewController = new webview.WebviewController();

  // Playback controls state
  @State currentSpeed: number = 1.0;
  @State showSpeedPanel: boolean = false;
  @State currentAspectRatio: string = 'fit';
  @State showAspectPanel: boolean = false;

  private readonly SPEED_OPTIONS: number[] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  private readonly ASPECT_OPTIONS: string[] = ['fit', 'fill', '16:9', '4:3'];
  private readonly ASPECT_LABELS: Record<string, string> = {
    'fit': '自适应',
    'fill': '填充',
    '16:9': '16:9',
    '4:3': '4:3'
  };

  private avPlayer: media.AVPlayer | undefined = undefined;
  private controlsTimer: number = -1;
  private fallbackAttempt: number = 0;
  private nativeEngineId: number = -1;
  private xComponentController: XComponentController = new XComponentController();
  private tcpSocket: socket.TCPSocket | null = null;

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
   * Initialize native hardware decoder engine.
   * Falls back to AVPlayer if native engine fails.
   */
  async initPlayer(): Promise<void> {
    try {
      await this.prepareStream();

      if (!this.streamUrl) {
        this.errorMsg = '无法获取播放地址';
        return;
      }

      // Try native hardware decode engine first
      hilog.info(DOMAIN, TAG, 'Initializing native hardware decoder...');
      this.nativeEngineId = nativePlayer.createEngine() as number;

      const surfaceId: string = this.xComponentController.getXComponentSurfaceId();
      hilog.info(DOMAIN, TAG, `Surface ID: ${surfaceId}`);

      // Use continuous TS stream URL (not HLS m3u8 playlist)
      const nativeUrl: string = EmbyApi.getNativeStreamUrl(
        this.session, this.itemId, this.mediaSource?.Id
      );
      hilog.info(DOMAIN, TAG, `Native stream URL: ${nativeUrl.substring(0, 120)}`);

      nativePlayer.setDataSource(this.nativeEngineId, nativeUrl);
      nativePlayer.setSurface(this.nativeEngineId, surfaceId);

      const prepared: boolean = nativePlayer.prepare(this.nativeEngineId) as boolean;
      if (prepared) {
        this.isPrepared = true;
        this.isPlaying = true;
        this.isHardwareDecode = true;
        hilog.info(DOMAIN, TAG, 'Native hardware decoder prepared, starting HTTP stream...');
        this.startNativeStream(nativeUrl);
        this.startControlsTimer();
        return;
      }

      // Native engine failed, release and fall back to AVPlayer
      hilog.warn(DOMAIN, TAG, 'Native engine failed, falling back to AVPlayer');
      nativePlayer.release(this.nativeEngineId);
      this.nativeEngineId = -1;
      this.initAVPlayer();

    } catch (err) {
      hilog.error(DOMAIN, TAG, `Player init failed: ${err}`);
      this.initAVPlayer();
    }
  }

  /**
   * Stream HTTP data from ArkTS and feed to native decoder via NAPI.
   */
  async startNativeStream(nativeUrl: string): Promise<void> {
    try {
      const schemeEnd = nativeUrl.indexOf('://');
      const hostStart = schemeEnd + 3;
      const pathStart = nativeUrl.indexOf('/', hostStart);
      const hostPort = nativeUrl.substring(hostStart, pathStart);
      const path = nativeUrl.substring(pathStart);

      let host = hostPort;
      let port = 80;
      const colonPos = hostPort.indexOf(':');
      if (colonPos >= 0) {
        host = hostPort.substring(0, colonPos);
        port = parseInt(hostPort.substring(colonPos + 1));
      }

      hilog.info(DOMAIN, TAG, `Native stream connecting to ${host}:${port}`);

      this.tcpSocket = socket.constructTCPSocketInstance();

      await this.tcpSocket.connect({
        address: { address: host, port: port, family: 1 }
      });

      const request = `GET ${path} HTTP/1.1\r\nHost: ${hostPort}\r\nConnection: close\r\n\r\n`;
      await this.tcpSocket.send({ data: request });

      let headersParsed = false;
      let headerAccum: number[] = [];

      this.tcpSocket.on('message', (value: Record<string, Object>) => {
        const data = value['message'] as ArrayBuffer;
        if (!data || data.byteLength === 0) return;

        if (!headersParsed) {
          const bytes = new Uint8Array(data);
          for (let i = 0; i < bytes.length; i++) {
            headerAccum.push(bytes[i]);
          }
          for (let i = 0; i < headerAccum.length - 3; i++) {
            if (headerAccum[i] === 0x0D && headerAccum[i + 1] === 0x0A &&
                headerAccum[i + 2] === 0x0D && headerAccum[i + 3] === 0x0A) {
              headersParsed = true;
              hilog.info(DOMAIN, TAG, 'HTTP headers parsed, streaming body data');
              const bodyStart = i + 4;
              if (bodyStart < headerAccum.length) {
                const body = new Uint8Array(headerAccum.slice(bodyStart));
                nativePlayer.feedData(this.nativeEngineId, body.buffer as ArrayBuffer);
              }
              headerAccum = [];
              break;
            }
          }
        } else {
          nativePlayer.feedData(this.nativeEngineId, data);
        }
      });

      hilog.info(DOMAIN, TAG, 'Native stream started');
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Native stream error: ${err}`);
    }
  }

  /**
   * Fallback: Initialize AVPlayer (software decode).
   */
  async initAVPlayer(): Promise<void> {
    try {
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
        hilog.error(DOMAIN, TAG, `AVPlayer error: code=${err.code}, message=${err.message}`);
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
   * 1=direct play, 2=remux MP4, 3=HLS transcode, 4+=give up
   */
  private handlePlaybackError(): void {
    this.fallbackAttempt++;
    hilog.warn(DOMAIN, TAG, `Playback failed, fallback attempt ${this.fallbackAttempt}`);

    if (this.fallbackAttempt === 1 && this.mediaSource) {
      hilog.warn(DOMAIN, TAG, 'HLS failed, trying direct play (static=true)');
      this.isFallbackMode = true;
      this.isHardwareDecode = false;
      this.codecName = '直接播放';

      this.streamUrl = EmbyApi.getDirectPlayUrl(this.session, this.itemId, this.mediaSource.Id);
      hilog.info(DOMAIN, TAG, `Direct play URL: ${this.streamUrl.substring(0, 120)}`);
      this.releasePlayer();
      this.retryWithUrl(this.streamUrl);
    } else if (this.fallbackAttempt === 2 && this.mediaSource) {
      hilog.warn(DOMAIN, TAG, 'Direct play failed, trying remux MP4 stream');
      this.codecName = 'H.264 (Remux)';

      this.streamUrl = EmbyApi.getRemuxStreamUrl(this.session, this.itemId, this.mediaSource.Id);
      hilog.info(DOMAIN, TAG, `Remux URL: ${this.streamUrl.substring(0, 120)}`);
      this.releasePlayer();
      this.retryWithUrl(this.streamUrl);
    } else if (this.fallbackAttempt === 3 && this.mediaSource) {
      hilog.warn(DOMAIN, TAG, 'Remux failed, trying HLS transcode');
      this.codecName = 'H.264 (HLS转码)';

      this.streamUrl = EmbyApi.getTranscodeStreamUrl(
        this.session, this.itemId, this.mediaSource.Id, 'h264', 'aac', 1920
      );
      hilog.info(DOMAIN, TAG, `HLS transcode URL: ${this.streamUrl.substring(0, 120)}`);
      this.releasePlayer();
      this.retryWithUrl(this.streamUrl);
    } else {
      hilog.warn(DOMAIN, TAG, 'All AVPlayer methods failed, switching to WebView');
      this.releasePlayer();
      this.useWebView = true;
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
        hilog.error(DOMAIN, TAG, `Fallback AVPlayer error: code=${err.code}, message=${err.message}`);
        this.handlePlaybackError();
      });

      this.avPlayer.url = url;
    } catch (err) {
      this.errorMsg = `重试失败: ${err instanceof Error ? err.message : '未知错误'}`;
    }
  }

  releasePlayer(): void {
    if (this.tcpSocket) {
      this.tcpSocket.close();
      this.tcpSocket = null;
    }
    if (this.nativeEngineId >= 0) {
      nativePlayer.release(this.nativeEngineId);
      this.nativeEngineId = -1;
    }
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

  setSpeed(speed: number): void {
    if (!this.avPlayer) {
      return;
    }
    this.currentSpeed = speed;
    this.showSpeedPanel = false;
    try {
      const speedEnum = this.mapSpeedToEnum(speed);
      if (speedEnum !== undefined) {
        this.avPlayer.setSpeed(speedEnum);
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, `setSpeed failed: ${err}`);
    }
  }

  private mapSpeedToEnum(speed: number): media.PlaybackSpeed | undefined {
    const map: Record<number, media.PlaybackSpeed> = {
      0.5: media.PlaybackSpeed.SPEED_FORWARD_0_50_X,
      0.75: media.PlaybackSpeed.SPEED_FORWARD_0_75_X,
      1.0: media.PlaybackSpeed.SPEED_FORWARD_1_00_X,
      1.25: media.PlaybackSpeed.SPEED_FORWARD_1_25_X,
      1.5: media.PlaybackSpeed.SPEED_FORWARD_1_50_X,
      2.0: media.PlaybackSpeed.SPEED_FORWARD_2_00_X,
    };
    return map[speed];
  }

  setAspectRatio(ratio: string): void {
    this.currentAspectRatio = ratio;
    this.showAspectPanel = false;
  }

  buildEmbyWebUrl(): string {
    return `${this.session.serverUrl}/web/index.html#!/item?id=${this.itemId}&serverId=&context=home`;
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
    if (this.useWebView) {
      Column() {
        Row() {
          Text('←')
            .fontSize(24)
            .fontColor('#FFFFFF')
            .padding(12)
            .onClick(() => { router.back(); })
          Text(this.title)
            .fontSize(16)
            .fontColor('#FFFFFF')
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('原生')
            .fontSize(13)
            .fontColor('#4FC3F7')
            .padding(12)
            .onClick(() => {
              this.useWebView = false;
              this.fallbackAttempt = 0;
              this.initPlayer();
            })
        }
        .width('100%')
        .height(48)
        .backgroundColor('#1E1E1E')
        .alignItems(VerticalAlign.Center)

        Web({ src: this.buildEmbyWebUrl(), controller: this.webController })
          .width('100%')
          .layoutWeight(1)
          .backgroundColor('#000000')
          .domStorageAccess(true)
          .javaScriptAccess(true)
          .mixedMode(MixedMode.All)
          .mediaPlayGestureAccess(true)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#000000')
    } else {
      Stack() {
      // ── Video Surface ──
      XComponent({ id: 'video_surface', type: 'surface', controller: this.xComponentController })
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

          // Bottom bar: seek bar + time + controls
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

            Row({ space: 16 }) {
              Text(this.currentSpeed === 1.0 ? '倍速' : `${this.currentSpeed}x`)
                .fontSize(13)
                .fontColor(this.currentSpeed === 1.0 ? '#FFFFFF' : '#4FC3F7')
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .borderRadius(16)
                .backgroundColor('#FFFFFF11')
                .onClick(() => {
                  this.showSpeedPanel = !this.showSpeedPanel;
                  this.showAspectPanel = false;
                })

              Text(this.ASPECT_LABELS[this.currentAspectRatio])
                .fontSize(13)
                .fontColor(this.currentAspectRatio === 'fit' ? '#FFFFFF' : '#4FC3F7')
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .borderRadius(16)
                .backgroundColor('#FFFFFF11')
                .onClick(() => {
                  this.showAspectPanel = !this.showAspectPanel;
                  this.showSpeedPanel = false;
                })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .margin({ top: 12 })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 24, top: 8 })
          .backgroundColor('#00000066')

          // Speed selection panel
          if (this.showSpeedPanel) {
            Column() {
              Text('播放倍速')
                .fontSize(14)
                .fontColor('#B3B3B3')
                .margin({ bottom: 12 })
              Row({ space: 12 }) {
                ForEach(this.SPEED_OPTIONS, (speed: number) => {
                  Text(`${speed}x`)
                    .fontSize(14)
                    .fontColor(this.currentSpeed === speed ? '#000000' : '#FFFFFF')
                    .fontWeight(this.currentSpeed === speed ? FontWeight.Bold : FontWeight.Normal)
                    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                    .borderRadius(20)
                    .backgroundColor(this.currentSpeed === speed ? '#4FC3F7' : '#333333')
                    .onClick(() => { this.setSpeed(speed); })
                })
              }
            }
            .width('90%')
            .padding(20)
            .backgroundColor('#1E1E1EEE')
            .borderRadius(12)
            .position({ x: '5%', bottom: 120 })
          }

          // Aspect ratio selection panel
          if (this.showAspectPanel) {
            Column() {
              Text('画面比例')
                .fontSize(14)
                .fontColor('#B3B3B3')
                .margin({ bottom: 12 })
              Row({ space: 12 }) {
                ForEach(this.ASPECT_OPTIONS, (ratio: string) => {
                  Text(this.ASPECT_LABELS[ratio])
                    .fontSize(14)
                    .fontColor(this.currentAspectRatio === ratio ? '#000000' : '#FFFFFF')
                    .fontWeight(this.currentAspectRatio === ratio ? FontWeight.Bold : FontWeight.Normal)
                    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                    .borderRadius(20)
                    .backgroundColor(this.currentAspectRatio === ratio ? '#4FC3F7' : '#333333')
                    .onClick(() => { this.setAspectRatio(ratio); })
                })
              }
            }
            .width('90%')
            .padding(20)
            .backgroundColor('#1E1E1EEE')
            .borderRadius(12)
            .position({ x: '5%', bottom: 120 })
          }
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
    }
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
