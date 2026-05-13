if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Player_Params {
    streamUrl?: string;
    title?: string;
    isPlaying?: boolean;
    isPrepared?: boolean;
    showControls?: boolean;
    currentTime?: number;
    totalDuration?: number;
    seekValue?: number;
    isSeeking?: boolean;
    errorMsg?: string;
    playerState?: string;
    surfaceReady?: boolean;
    showCodecInfo?: boolean;
    codecName?: string;
    resolution?: string;
    bitrateDisplay?: string;
    videoRange?: string;
    isHardwareDecode?: boolean;
    isFallbackMode?: boolean;
    avPlayer?: media.AVPlayer | undefined;
    controlsTimer?: number;
    itemId?: string;
    session?: SessionInfo;
    mediaSource?: MediaSource | undefined;
    mediaItem?: MediaItem | undefined;
}
import router from "@ohos:router";
import media from "@ohos:multimedia.media";
import hilog from "@ohos:hilog";
import type { BusinessError as BusinessError } from "@ohos:base";
import { EmbyApi } from "@bundle:com.emby.harmonyos/entry/ets/services/EmbyApi";
import { CodecCapabilityService } from "@bundle:com.emby.harmonyos/entry/ets/services/CodecCapabilityService";
import type { SessionInfo, MediaItem, MediaSource } from '../models/EmbyTypes';
const TAG = 'PlayerPage';
const DOMAIN = 0xFF00;
class Player extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__streamUrl = new ObservedPropertySimplePU('', this, "streamUrl");
        this.__title = new ObservedPropertySimplePU('', this, "title");
        this.__isPlaying = new ObservedPropertySimplePU(false, this, "isPlaying");
        this.__isPrepared = new ObservedPropertySimplePU(false, this, "isPrepared");
        this.__showControls = new ObservedPropertySimplePU(true, this, "showControls");
        this.__currentTime = new ObservedPropertySimplePU(0, this, "currentTime");
        this.__totalDuration = new ObservedPropertySimplePU(0, this, "totalDuration");
        this.__seekValue = new ObservedPropertySimplePU(0, this, "seekValue");
        this.__isSeeking = new ObservedPropertySimplePU(false, this, "isSeeking");
        this.__errorMsg = new ObservedPropertySimplePU('', this, "errorMsg");
        this.__playerState = new ObservedPropertySimplePU('idle', this, "playerState");
        this.__surfaceReady = new ObservedPropertySimplePU(false, this, "surfaceReady");
        this.__showCodecInfo = new ObservedPropertySimplePU(false, this, "showCodecInfo");
        this.__codecName = new ObservedPropertySimplePU('', this, "codecName");
        this.__resolution = new ObservedPropertySimplePU('', this, "resolution");
        this.__bitrateDisplay = new ObservedPropertySimplePU('', this, "bitrateDisplay");
        this.__videoRange = new ObservedPropertySimplePU('SDR', this, "videoRange");
        this.__isHardwareDecode = new ObservedPropertySimplePU(false, this, "isHardwareDecode");
        this.__isFallbackMode = new ObservedPropertySimplePU(false, this, "isFallbackMode");
        this.avPlayer = undefined;
        this.controlsTimer = -1;
        this.itemId = '';
        this.session = {
            serverUrl: '',
            accessToken: '',
            userId: '',
            userName: ''
        };
        this.mediaSource = undefined;
        this.mediaItem = undefined;
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Player_Params) {
        if (params.streamUrl !== undefined) {
            this.streamUrl = params.streamUrl;
        }
        if (params.title !== undefined) {
            this.title = params.title;
        }
        if (params.isPlaying !== undefined) {
            this.isPlaying = params.isPlaying;
        }
        if (params.isPrepared !== undefined) {
            this.isPrepared = params.isPrepared;
        }
        if (params.showControls !== undefined) {
            this.showControls = params.showControls;
        }
        if (params.currentTime !== undefined) {
            this.currentTime = params.currentTime;
        }
        if (params.totalDuration !== undefined) {
            this.totalDuration = params.totalDuration;
        }
        if (params.seekValue !== undefined) {
            this.seekValue = params.seekValue;
        }
        if (params.isSeeking !== undefined) {
            this.isSeeking = params.isSeeking;
        }
        if (params.errorMsg !== undefined) {
            this.errorMsg = params.errorMsg;
        }
        if (params.playerState !== undefined) {
            this.playerState = params.playerState;
        }
        if (params.surfaceReady !== undefined) {
            this.surfaceReady = params.surfaceReady;
        }
        if (params.showCodecInfo !== undefined) {
            this.showCodecInfo = params.showCodecInfo;
        }
        if (params.codecName !== undefined) {
            this.codecName = params.codecName;
        }
        if (params.resolution !== undefined) {
            this.resolution = params.resolution;
        }
        if (params.bitrateDisplay !== undefined) {
            this.bitrateDisplay = params.bitrateDisplay;
        }
        if (params.videoRange !== undefined) {
            this.videoRange = params.videoRange;
        }
        if (params.isHardwareDecode !== undefined) {
            this.isHardwareDecode = params.isHardwareDecode;
        }
        if (params.isFallbackMode !== undefined) {
            this.isFallbackMode = params.isFallbackMode;
        }
        if (params.avPlayer !== undefined) {
            this.avPlayer = params.avPlayer;
        }
        if (params.controlsTimer !== undefined) {
            this.controlsTimer = params.controlsTimer;
        }
        if (params.itemId !== undefined) {
            this.itemId = params.itemId;
        }
        if (params.session !== undefined) {
            this.session = params.session;
        }
        if (params.mediaSource !== undefined) {
            this.mediaSource = params.mediaSource;
        }
        if (params.mediaItem !== undefined) {
            this.mediaItem = params.mediaItem;
        }
    }
    updateStateVars(params: Player_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__streamUrl.purgeDependencyOnElmtId(rmElmtId);
        this.__title.purgeDependencyOnElmtId(rmElmtId);
        this.__isPlaying.purgeDependencyOnElmtId(rmElmtId);
        this.__isPrepared.purgeDependencyOnElmtId(rmElmtId);
        this.__showControls.purgeDependencyOnElmtId(rmElmtId);
        this.__currentTime.purgeDependencyOnElmtId(rmElmtId);
        this.__totalDuration.purgeDependencyOnElmtId(rmElmtId);
        this.__seekValue.purgeDependencyOnElmtId(rmElmtId);
        this.__isSeeking.purgeDependencyOnElmtId(rmElmtId);
        this.__errorMsg.purgeDependencyOnElmtId(rmElmtId);
        this.__playerState.purgeDependencyOnElmtId(rmElmtId);
        this.__surfaceReady.purgeDependencyOnElmtId(rmElmtId);
        this.__showCodecInfo.purgeDependencyOnElmtId(rmElmtId);
        this.__codecName.purgeDependencyOnElmtId(rmElmtId);
        this.__resolution.purgeDependencyOnElmtId(rmElmtId);
        this.__bitrateDisplay.purgeDependencyOnElmtId(rmElmtId);
        this.__videoRange.purgeDependencyOnElmtId(rmElmtId);
        this.__isHardwareDecode.purgeDependencyOnElmtId(rmElmtId);
        this.__isFallbackMode.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__streamUrl.aboutToBeDeleted();
        this.__title.aboutToBeDeleted();
        this.__isPlaying.aboutToBeDeleted();
        this.__isPrepared.aboutToBeDeleted();
        this.__showControls.aboutToBeDeleted();
        this.__currentTime.aboutToBeDeleted();
        this.__totalDuration.aboutToBeDeleted();
        this.__seekValue.aboutToBeDeleted();
        this.__isSeeking.aboutToBeDeleted();
        this.__errorMsg.aboutToBeDeleted();
        this.__playerState.aboutToBeDeleted();
        this.__surfaceReady.aboutToBeDeleted();
        this.__showCodecInfo.aboutToBeDeleted();
        this.__codecName.aboutToBeDeleted();
        this.__resolution.aboutToBeDeleted();
        this.__bitrateDisplay.aboutToBeDeleted();
        this.__videoRange.aboutToBeDeleted();
        this.__isHardwareDecode.aboutToBeDeleted();
        this.__isFallbackMode.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __streamUrl: ObservedPropertySimplePU<string>;
    get streamUrl() {
        return this.__streamUrl.get();
    }
    set streamUrl(newValue: string) {
        this.__streamUrl.set(newValue);
    }
    private __title: ObservedPropertySimplePU<string>;
    get title() {
        return this.__title.get();
    }
    set title(newValue: string) {
        this.__title.set(newValue);
    }
    private __isPlaying: ObservedPropertySimplePU<boolean>;
    get isPlaying() {
        return this.__isPlaying.get();
    }
    set isPlaying(newValue: boolean) {
        this.__isPlaying.set(newValue);
    }
    private __isPrepared: ObservedPropertySimplePU<boolean>;
    get isPrepared() {
        return this.__isPrepared.get();
    }
    set isPrepared(newValue: boolean) {
        this.__isPrepared.set(newValue);
    }
    private __showControls: ObservedPropertySimplePU<boolean>;
    get showControls() {
        return this.__showControls.get();
    }
    set showControls(newValue: boolean) {
        this.__showControls.set(newValue);
    }
    private __currentTime: ObservedPropertySimplePU<number>;
    get currentTime() {
        return this.__currentTime.get();
    }
    set currentTime(newValue: number) {
        this.__currentTime.set(newValue);
    }
    private __totalDuration: ObservedPropertySimplePU<number>;
    get totalDuration() {
        return this.__totalDuration.get();
    }
    set totalDuration(newValue: number) {
        this.__totalDuration.set(newValue);
    }
    private __seekValue: ObservedPropertySimplePU<number>;
    get seekValue() {
        return this.__seekValue.get();
    }
    set seekValue(newValue: number) {
        this.__seekValue.set(newValue);
    }
    private __isSeeking: ObservedPropertySimplePU<boolean>;
    get isSeeking() {
        return this.__isSeeking.get();
    }
    set isSeeking(newValue: boolean) {
        this.__isSeeking.set(newValue);
    }
    private __errorMsg: ObservedPropertySimplePU<string>;
    get errorMsg() {
        return this.__errorMsg.get();
    }
    set errorMsg(newValue: string) {
        this.__errorMsg.set(newValue);
    }
    private __playerState: ObservedPropertySimplePU<string>;
    get playerState() {
        return this.__playerState.get();
    }
    set playerState(newValue: string) {
        this.__playerState.set(newValue);
    }
    private __surfaceReady: ObservedPropertySimplePU<boolean>;
    get surfaceReady() {
        return this.__surfaceReady.get();
    }
    set surfaceReady(newValue: boolean) {
        this.__surfaceReady.set(newValue);
    }
    private __showCodecInfo: ObservedPropertySimplePU<boolean>;
    get showCodecInfo() {
        return this.__showCodecInfo.get();
    }
    set showCodecInfo(newValue: boolean) {
        this.__showCodecInfo.set(newValue);
    }
    // Codec / MediaSource info for display
    private __codecName: ObservedPropertySimplePU<string>;
    get codecName() {
        return this.__codecName.get();
    }
    set codecName(newValue: string) {
        this.__codecName.set(newValue);
    }
    private __resolution: ObservedPropertySimplePU<string>;
    get resolution() {
        return this.__resolution.get();
    }
    set resolution(newValue: string) {
        this.__resolution.set(newValue);
    }
    private __bitrateDisplay: ObservedPropertySimplePU<string>;
    get bitrateDisplay() {
        return this.__bitrateDisplay.get();
    }
    set bitrateDisplay(newValue: string) {
        this.__bitrateDisplay.set(newValue);
    }
    private __videoRange: ObservedPropertySimplePU<string>;
    get videoRange() {
        return this.__videoRange.get();
    }
    set videoRange(newValue: string) {
        this.__videoRange.set(newValue);
    }
    private __isHardwareDecode: ObservedPropertySimplePU<boolean>;
    get isHardwareDecode() {
        return this.__isHardwareDecode.get();
    }
    set isHardwareDecode(newValue: boolean) {
        this.__isHardwareDecode.set(newValue);
    }
    private __isFallbackMode: ObservedPropertySimplePU<boolean>;
    get isFallbackMode() {
        return this.__isFallbackMode.get();
    }
    set isFallbackMode(newValue: boolean) {
        this.__isFallbackMode.set(newValue);
    }
    private avPlayer: media.AVPlayer | undefined;
    private controlsTimer: number;
    // Received from router
    private itemId: string;
    private session: SessionInfo;
    // MediaSource data
    private mediaSource: MediaSource | undefined;
    private mediaItem: MediaItem | undefined;
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
            // Fetch full item details with MediaSource/MediaStreams
            this.mediaItem = await EmbyApi.getItemDetail(this.session, this.itemId);
            if (this.mediaItem.MediaSources && this.mediaItem.MediaSources.length > 0) {
                this.mediaSource = this.mediaItem.MediaSources[0];
                // Extract video stream info
                const videoStream = EmbyApi.getVideoStream(this.mediaSource);
                if (videoStream) {
                    this.codecName = videoStream.Codec || videoStream.VideoCodec || 'unknown';
                    this.resolution = `${videoStream.Width || '?'}x${videoStream.Height || '?'}`;
                    this.videoRange = videoStream.VideoRangeType || videoStream.VideoRange || 'SDR';
                    if (this.mediaSource.Bitrate) {
                        const mbps = (this.mediaSource.Bitrate / 1000000).toFixed(1);
                        this.bitrateDisplay = `${mbps} Mbps`;
                    }
                    // Check if device can hardware-decode this codec
                    const canHwDecode = await CodecCapabilityService.shouldUseHardwareDecode(this.codecName);
                    this.isHardwareDecode = canHwDecode;
                    this.isFallbackMode = !canHwDecode;
                    hilog.info(DOMAIN, TAG, `Codec: ${this.codecName}, HW: ${canHwDecode}, Res: ${this.resolution}, Range: ${this.videoRange}`);
                    if (canHwDecode) {
                        // Direct play with hardware decoding
                        this.streamUrl = EmbyApi.getStreamUrl(this.session, this.itemId, this.mediaSource.Id);
                    }
                    else {
                        // Fallback: request server-side transcoding to H.264
                        this.streamUrl = EmbyApi.getTranscodeStreamUrl(this.session, this.itemId, this.mediaSource.Id, 'h264', 'aac', 1920);
                    }
                }
                else {
                    // No video stream info — try direct play anyway
                    this.streamUrl = EmbyApi.getStreamUrl(this.session, this.itemId, this.mediaSource.Id);
                }
            }
            else {
                // No MediaSource info — try direct play with item ID
                this.streamUrl = EmbyApi.getStreamUrl(this.session, this.itemId);
            }
        }
        catch (err) {
            hilog.error(DOMAIN, TAG, `Failed to prepare stream: ${err}`);
            // Fallback to basic stream URL
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
        }
        catch (err) {
            hilog.error(DOMAIN, TAG, `Player init failed: ${err}`);
            this.errorMsg = `初始化播放器失败: ${err instanceof Error ? err.message : '未知错误'}`;
        }
    }
    /**
     * Handle playback error — try fallback to HLS transcoding if not already in fallback mode.
     */
    private handlePlaybackError(): void {
        if (!this.isFallbackMode && this.mediaSource) {
            // Try HLS fallback with server-side transcoding
            hilog.warn(DOMAIN, TAG, 'Direct play failed, falling back to HLS transcoding');
            this.isFallbackMode = true;
            this.isHardwareDecode = false;
            this.codecName = 'H.264 (转码)';
            this.streamUrl = EmbyApi.getTranscodeStreamUrl(this.session, this.itemId, this.mediaSource.Id, 'h264', 'aac', 1920);
            // Reset player and retry
            this.releasePlayer();
            this.retryWithUrl(this.streamUrl);
        }
        else {
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
                        this.errorMsg = '播放失败: 转码播放也失败了';
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
                this.errorMsg = '播放失败: 转码播放也失败了';
            });
            this.avPlayer.url = url;
        }
        catch (err) {
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
        }
        else {
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
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.debugLine("entry/src/main/ets/pages/Player.ets(374:5)", "entry");
            Stack.width('100%');
            Stack.height('100%');
            Stack.backgroundColor('#000000');
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // ── Video Surface ──
            XComponent.create({ id: 'video_surface', type: 'surface', libraryname: '' }, "com.emby.harmonyos/entry");
            XComponent.debugLine("entry/src/main/ets/pages/Player.ets(376:7)", "entry");
            // ── Video Surface ──
            XComponent.width('100%');
            // ── Video Surface ──
            XComponent.height('100%');
            // ── Video Surface ──
            XComponent.backgroundColor('#000000');
            // ── Video Surface ──
            XComponent.onLoad(() => {
                this.surfaceReady = true;
                this.initPlayer();
            });
        }, XComponent);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // ── Tap to toggle controls ──
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/Player.ets(386:7)", "entry");
            // ── Tap to toggle controls ──
            Column.width('100%');
            // ── Tap to toggle controls ──
            Column.height('100%');
            // ── Tap to toggle controls ──
            Column.onClick(() => {
                this.toggleControls();
            });
        }, Column);
        // ── Tap to toggle controls ──
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // ── Error Overlay ──
            if (this.errorMsg) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.debugLine("entry/src/main/ets/pages/Player.ets(395:9)", "entry");
                        Column.width('100%');
                        Column.height('100%');
                        Column.justifyContent(FlexAlign.Center);
                        Column.backgroundColor('#000000CC');
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.errorMsg);
                        Text.debugLine("entry/src/main/ets/pages/Player.ets(396:11)", "entry");
                        Text.fontSize(16);
                        Text.fontColor('#F44336');
                        Text.margin({ bottom: 16 });
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        If.create();
                        if (this.isFallbackMode) {
                            this.ifElseBranchUpdateFunction(0, () => {
                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                    Text.create('已尝试服务器转码，仍然失败');
                                    Text.debugLine("entry/src/main/ets/pages/Player.ets(401:13)", "entry");
                                    Text.fontSize(13);
                                    Text.fontColor('#B3B3B3');
                                    Text.margin({ bottom: 16 });
                                }, Text);
                                Text.pop();
                            });
                        }
                        else {
                            this.ifElseBranchUpdateFunction(1, () => {
                            });
                        }
                    }, If);
                    If.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('返回');
                        Button.debugLine("entry/src/main/ets/pages/Player.ets(406:11)", "entry");
                        Button.type(ButtonType.Capsule);
                        Button.width(120);
                        Button.height(40);
                        Button.backgroundColor('#4FC3F7');
                        Button.onClick(() => {
                            router.back();
                        });
                    }, Button);
                    Button.pop();
                    Column.pop();
                });
            }
            // ── Loading Indicator ──
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // ── Loading Indicator ──
            if (!this.isPrepared && !this.errorMsg) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.debugLine("entry/src/main/ets/pages/Player.ets(423:9)", "entry");
                        Column.width('100%');
                        Column.height('100%');
                        Column.justifyContent(FlexAlign.Center);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        LoadingProgress.create();
                        LoadingProgress.debugLine("entry/src/main/ets/pages/Player.ets(424:11)", "entry");
                        LoadingProgress.width(48);
                        LoadingProgress.height(48);
                        LoadingProgress.color('#4FC3F7');
                    }, LoadingProgress);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.isFallbackMode ? '正在切换到转码播放...' : '正在加载...');
                        Text.debugLine("entry/src/main/ets/pages/Player.ets(428:11)", "entry");
                        Text.fontSize(14);
                        Text.fontColor('#FFFFFF');
                        Text.margin({ top: 12 });
                    }, Text);
                    Text.pop();
                    Column.pop();
                });
            }
            // ── Codec Info Overlay ──
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // ── Codec Info Overlay ──
            if (this.showCodecInfo) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.debugLine("entry/src/main/ets/pages/Player.ets(440:9)", "entry");
                        Column.width('85%');
                        Column.padding(20);
                        Column.backgroundColor('#1E1E1EEE');
                        Column.borderRadius(12);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create();
                        Row.debugLine("entry/src/main/ets/pages/Player.ets(441:11)", "entry");
                        Row.width('100%');
                        Row.margin({ bottom: 16 });
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('解码信息');
                        Text.debugLine("entry/src/main/ets/pages/Player.ets(442:13)", "entry");
                        Text.fontSize(16);
                        Text.fontWeight(FontWeight.Bold);
                        Text.fontColor('#FFFFFF');
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Blank.create();
                        Blank.debugLine("entry/src/main/ets/pages/Player.ets(446:13)", "entry");
                    }, Blank);
                    Blank.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('✕');
                        Text.debugLine("entry/src/main/ets/pages/Player.ets(447:13)", "entry");
                        Text.fontSize(18);
                        Text.fontColor('#FFFFFF');
                        Text.onClick(() => { this.showCodecInfo = false; });
                    }, Text);
                    Text.pop();
                    Row.pop();
                    this.CodecInfoRow.bind(this)('编码格式', this.codecName || '检测中...');
                    this.CodecInfoRow.bind(this)('分辨率', this.resolution || '检测中...');
                    this.CodecInfoRow.bind(this)('码率', this.bitrateDisplay || '检测中...');
                    this.CodecInfoRow.bind(this)('动态范围', this.videoRange);
                    this.CodecInfoRow.bind(this)('硬件解码', this.isHardwareDecode ? '✓ 启用' : '✗ 软解/转码');
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        If.create();
                        if (this.isFallbackMode) {
                            this.ifElseBranchUpdateFunction(0, () => {
                                this.CodecInfoRow.bind(this)('播放模式', '服务器转码');
                            });
                        }
                        else {
                            this.ifElseBranchUpdateFunction(1, () => {
                                this.CodecInfoRow.bind(this)('播放模式', '直接播放');
                            });
                        }
                    }, If);
                    If.pop();
                    Column.pop();
                });
            }
            // ── Playback Controls ──
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // ── Playback Controls ──
            if (this.showControls && this.isPrepared) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.debugLine("entry/src/main/ets/pages/Player.ets(474:9)", "entry");
                        Column.width('100%');
                        Column.height('100%');
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // Top bar: back button + title + codec info button
                        Row.create();
                        Row.debugLine("entry/src/main/ets/pages/Player.ets(476:11)", "entry");
                        // Top bar: back button + title + codec info button
                        Row.width('100%');
                        // Top bar: back button + title + codec info button
                        Row.height(56);
                        // Top bar: back button + title + codec info button
                        Row.padding({ left: 8, right: 8 });
                        // Top bar: back button + title + codec info button
                        Row.alignItems(VerticalAlign.Center);
                        // Top bar: back button + title + codec info button
                        Row.backgroundColor('#00000066');
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('←');
                        Text.debugLine("entry/src/main/ets/pages/Player.ets(477:13)", "entry");
                        Text.fontSize(24);
                        Text.fontColor('#FFFFFF');
                        Text.padding(12);
                        Text.onClick(() => { router.back(); });
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.title);
                        Text.debugLine("entry/src/main/ets/pages/Player.ets(483:13)", "entry");
                        Text.fontSize(18);
                        Text.fontWeight(FontWeight.Medium);
                        Text.fontColor('#FFFFFF');
                        Text.maxLines(1);
                        Text.textOverflow({ overflow: TextOverflow.Ellipsis });
                        Text.layoutWeight(1);
                        Text.margin({ left: 8 });
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // Codec info button
                        Text.create('ℹ');
                        Text.debugLine("entry/src/main/ets/pages/Player.ets(493:13)", "entry");
                        // Codec info button
                        Text.fontSize(20);
                        // Codec info button
                        Text.fontColor('#FFFFFF');
                        // Codec info button
                        Text.padding(12);
                        // Codec info button
                        Text.onClick(() => { this.showCodecInfo = !this.showCodecInfo; });
                    }, Text);
                    // Codec info button
                    Text.pop();
                    // Top bar: back button + title + codec info button
                    Row.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        If.create();
                        // Codec badge (top-left, below title bar)
                        if (this.codecName || this.isFallbackMode) {
                            this.ifElseBranchUpdateFunction(0, () => {
                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                    Row.create();
                                    Row.debugLine("entry/src/main/ets/pages/Player.ets(507:13)", "entry");
                                    Row.width('100%');
                                    Row.padding({ left: 16 });
                                    Row.margin({ top: 4 });
                                }, Row);
                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                    Text.create(this.isFallbackMode ? '转码' : this.codecName.toUpperCase());
                                    Text.debugLine("entry/src/main/ets/pages/Player.ets(508:15)", "entry");
                                    Text.fontSize(10);
                                    Text.fontColor('#FFFFFF');
                                    Text.padding({ left: 8, right: 8, top: 2, bottom: 2 });
                                    Text.backgroundColor(this.isHardwareDecode ? '#4CAF5066' : '#FF980066');
                                    Text.borderRadius(4);
                                }, Text);
                                Text.pop();
                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                    If.create();
                                    if (this.isHardwareDecode) {
                                        this.ifElseBranchUpdateFunction(0, () => {
                                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                                Text.create('HW');
                                                Text.debugLine("entry/src/main/ets/pages/Player.ets(516:17)", "entry");
                                                Text.fontSize(10);
                                                Text.fontColor('#FFFFFF');
                                                Text.padding({ left: 6, right: 6, top: 2, bottom: 2 });
                                                Text.backgroundColor('#4CAF5066');
                                                Text.borderRadius(4);
                                                Text.margin({ left: 6 });
                                            }, Text);
                                            Text.pop();
                                        });
                                    }
                                    else {
                                        this.ifElseBranchUpdateFunction(1, () => {
                                        });
                                    }
                                }, If);
                                If.pop();
                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                    If.create();
                                    if (this.videoRange !== 'SDR') {
                                        this.ifElseBranchUpdateFunction(0, () => {
                                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                                Text.create(this.videoRange);
                                                Text.debugLine("entry/src/main/ets/pages/Player.ets(526:17)", "entry");
                                                Text.fontSize(10);
                                                Text.fontColor('#FFFFFF');
                                                Text.padding({ left: 6, right: 6, top: 2, bottom: 2 });
                                                Text.backgroundColor('#FF980066');
                                                Text.borderRadius(4);
                                                Text.margin({ left: 6 });
                                            }, Text);
                                            Text.pop();
                                        });
                                    }
                                    else {
                                        this.ifElseBranchUpdateFunction(1, () => {
                                        });
                                    }
                                }, If);
                                If.pop();
                                Row.pop();
                            });
                        }
                        // Spacer
                        else {
                            this.ifElseBranchUpdateFunction(1, () => {
                            });
                        }
                    }, If);
                    If.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // Spacer
                        Blank.create();
                        Blank.debugLine("entry/src/main/ets/pages/Player.ets(541:11)", "entry");
                    }, Blank);
                    // Spacer
                    Blank.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // Center play/pause button
                        Text.create(this.isPlaying ? '⏸' : '▶');
                        Text.debugLine("entry/src/main/ets/pages/Player.ets(544:11)", "entry");
                        // Center play/pause button
                        Text.fontSize(56);
                        // Center play/pause button
                        Text.fontColor('#FFFFFF');
                        // Center play/pause button
                        Text.onClick(() => { this.togglePlayPause(); });
                    }, Text);
                    // Center play/pause button
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // Spacer
                        Blank.create();
                        Blank.debugLine("entry/src/main/ets/pages/Player.ets(550:11)", "entry");
                    }, Blank);
                    // Spacer
                    Blank.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // Bottom bar: seek bar + time
                        Column.create();
                        Column.debugLine("entry/src/main/ets/pages/Player.ets(553:11)", "entry");
                        // Bottom bar: seek bar + time
                        Column.width('100%');
                        // Bottom bar: seek bar + time
                        Column.padding({ left: 16, right: 16, bottom: 24, top: 8 });
                        // Bottom bar: seek bar + time
                        Column.backgroundColor('#00000066');
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Slider.create({
                            value: this.seekValue,
                            min: 0,
                            max: this.totalDuration,
                            step: 1000
                        });
                        Slider.debugLine("entry/src/main/ets/pages/Player.ets(554:13)", "entry");
                        Slider.blockColor('#4FC3F7');
                        Slider.trackColor('#444444');
                        Slider.selectedColor('#4FC3F7');
                        Slider.width('100%');
                        Slider.height(24);
                        Slider.onChange((value: number, mode: SliderChangeMode) => {
                            this.onSeekChange(value);
                            if (mode === SliderChangeMode.End) {
                                this.seekTo(value);
                            }
                        });
                    }, Slider);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create();
                        Row.debugLine("entry/src/main/ets/pages/Player.ets(572:13)", "entry");
                        Row.width('100%');
                        Row.padding({ left: 4, right: 4 });
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.formatTime(this.currentTime));
                        Text.debugLine("entry/src/main/ets/pages/Player.ets(573:15)", "entry");
                        Text.fontSize(12);
                        Text.fontColor('#FFFFFF');
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Blank.create();
                        Blank.debugLine("entry/src/main/ets/pages/Player.ets(577:15)", "entry");
                    }, Blank);
                    Blank.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.formatTime(this.totalDuration));
                        Text.debugLine("entry/src/main/ets/pages/Player.ets(579:15)", "entry");
                        Text.fontSize(12);
                        Text.fontColor('#FFFFFF');
                    }, Text);
                    Text.pop();
                    Row.pop();
                    // Bottom bar: seek bar + time
                    Column.pop();
                    Column.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        Stack.pop();
    }
    /**
     * Helper builder for codec info display rows
     */
    CodecInfoRow(label: string, value: string, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/Player.ets(604:5)", "entry");
            Row.width('100%');
            Row.margin({ bottom: 10 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(label);
            Text.debugLine("entry/src/main/ets/pages/Player.ets(605:7)", "entry");
            Text.fontSize(14);
            Text.fontColor('#B3B3B3');
            Text.width(90);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(value);
            Text.debugLine("entry/src/main/ets/pages/Player.ets(609:7)", "entry");
            Text.fontSize(14);
            Text.fontColor('#FFFFFF');
            Text.layoutWeight(1);
        }, Text);
        Text.pop();
        Row.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "Player";
    }
}
registerNamedRoute(() => new Player(undefined, {}), "", { bundleName: "com.emby.harmonyos", moduleName: "entry", pagePath: "pages/Player", pageFullPath: "entry/src/main/ets/pages/Player", integratedHsp: "false", moduleType: "followWithHap" });
