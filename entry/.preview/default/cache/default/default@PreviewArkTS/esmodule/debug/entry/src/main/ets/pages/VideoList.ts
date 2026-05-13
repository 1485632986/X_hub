if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface VideoList_Params {
    items?: MediaItem[];
    isLoading?: boolean;
    errorMsg?: string;
    userName?: string;
    session?: SessionInfo;
}
import router from "@ohos:router";
import { EmbyApi } from "@bundle:com.emby.harmonyos/entry/ets/services/EmbyApi";
import { CodecCapabilityService } from "@bundle:com.emby.harmonyos/entry/ets/services/CodecCapabilityService";
import type { SessionInfo, MediaItem, ItemsResponse } from '../models/EmbyTypes';
class VideoList extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__items = new ObservedPropertyObjectPU([], this, "items");
        this.__isLoading = new ObservedPropertySimplePU(true, this, "isLoading");
        this.__errorMsg = new ObservedPropertySimplePU('', this, "errorMsg");
        this.__userName = new ObservedPropertySimplePU('', this, "userName");
        this.session = {
            serverUrl: '',
            accessToken: '',
            userId: '',
            userName: ''
        };
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: VideoList_Params) {
        if (params.items !== undefined) {
            this.items = params.items;
        }
        if (params.isLoading !== undefined) {
            this.isLoading = params.isLoading;
        }
        if (params.errorMsg !== undefined) {
            this.errorMsg = params.errorMsg;
        }
        if (params.userName !== undefined) {
            this.userName = params.userName;
        }
        if (params.session !== undefined) {
            this.session = params.session;
        }
    }
    updateStateVars(params: VideoList_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__items.purgeDependencyOnElmtId(rmElmtId);
        this.__isLoading.purgeDependencyOnElmtId(rmElmtId);
        this.__errorMsg.purgeDependencyOnElmtId(rmElmtId);
        this.__userName.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__items.aboutToBeDeleted();
        this.__isLoading.aboutToBeDeleted();
        this.__errorMsg.aboutToBeDeleted();
        this.__userName.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __items: ObservedPropertyObjectPU<MediaItem[]>;
    get items() {
        return this.__items.get();
    }
    set items(newValue: MediaItem[]) {
        this.__items.set(newValue);
    }
    private __isLoading: ObservedPropertySimplePU<boolean>;
    get isLoading() {
        return this.__isLoading.get();
    }
    set isLoading(newValue: boolean) {
        this.__isLoading.set(newValue);
    }
    private __errorMsg: ObservedPropertySimplePU<string>;
    get errorMsg() {
        return this.__errorMsg.get();
    }
    set errorMsg(newValue: string) {
        this.__errorMsg.set(newValue);
    }
    private __userName: ObservedPropertySimplePU<string>;
    get userName() {
        return this.__userName.get();
    }
    set userName(newValue: string) {
        this.__userName.set(newValue);
    }
    private session: SessionInfo;
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
        }
        else {
            this.isLoading = false;
            this.errorMsg = '未获取到登录信息';
        }
    }
    async loadItems(): Promise<void> {
        this.isLoading = true;
        this.errorMsg = '';
        try {
            const result: ItemsResponse = await EmbyApi.getVideoItems(this.session, 0, 50);
            this.items = result.Items.filter((item: MediaItem) => !item.IsFolder && item.MediaType === 'Video');
            if (this.items.length === 0) {
                this.errorMsg = '没有找到视频';
            }
        }
        catch (err) {
            if (err instanceof Error) {
                this.errorMsg = `加载失败: ${err.message}`;
            }
            else {
                this.errorMsg = '加载失败: 未知错误';
            }
        }
        finally {
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
    PosterImage(item: MediaItem, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (item.ImageTags?.Primary) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Image.create(EmbyApi.getImageUrl(this.session, item.Id, item.ImageTags.Primary, 120));
                        Image.debugLine("entry/src/main/ets/pages/VideoList.ets(108:7)", "entry");
                        Image.width(90);
                        Image.height(135);
                        Image.borderRadius(6);
                        Image.objectFit(ImageFit.Cover);
                    }, Image);
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.debugLine("entry/src/main/ets/pages/VideoList.ets(114:7)", "entry");
                        Column.width(90);
                        Column.height(135);
                        Column.borderRadius(6);
                        Column.backgroundColor('#333333');
                        Column.justifyContent(FlexAlign.Center);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('🎬');
                        Text.debugLine("entry/src/main/ets/pages/VideoList.ets(115:9)", "entry");
                        Text.fontSize(32);
                    }, Text);
                    Text.pop();
                    Column.pop();
                });
            }
        }, If);
        If.pop();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/VideoList.ets(127:5)", "entry");
            Column.width('100%');
            Column.height('100%');
            Column.backgroundColor('#121212');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/VideoList.ets(128:7)", "entry");
            Row.width('100%');
            Row.height(56);
            Row.padding({ left: 16, right: 16 });
            Row.alignItems(VerticalAlign.Center);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('视频列表');
            Text.debugLine("entry/src/main/ets/pages/VideoList.ets(129:9)", "entry");
            Text.fontSize(20);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor('#FFFFFF');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
            Blank.debugLine("entry/src/main/ets/pages/VideoList.ets(134:9)", "entry");
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.userName);
            Text.debugLine("entry/src/main/ets/pages/VideoList.ets(136:9)", "entry");
            Text.fontSize(14);
            Text.fontColor('#B3B3B3');
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.isLoading) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.debugLine("entry/src/main/ets/pages/VideoList.ets(146:9)", "entry");
                        Column.width('100%');
                        Column.layoutWeight(1);
                        Column.justifyContent(FlexAlign.Center);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        LoadingProgress.create();
                        LoadingProgress.debugLine("entry/src/main/ets/pages/VideoList.ets(147:11)", "entry");
                        LoadingProgress.width(48);
                        LoadingProgress.height(48);
                        LoadingProgress.color('#4FC3F7');
                    }, LoadingProgress);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('加载中...');
                        Text.debugLine("entry/src/main/ets/pages/VideoList.ets(151:11)", "entry");
                        Text.fontSize(14);
                        Text.fontColor('#B3B3B3');
                        Text.margin({ top: 12 });
                    }, Text);
                    Text.pop();
                    Column.pop();
                });
            }
            else if (this.errorMsg) {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.debugLine("entry/src/main/ets/pages/VideoList.ets(160:9)", "entry");
                        Column.width('100%');
                        Column.layoutWeight(1);
                        Column.justifyContent(FlexAlign.Center);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.errorMsg);
                        Text.debugLine("entry/src/main/ets/pages/VideoList.ets(161:11)", "entry");
                        Text.fontSize(16);
                        Text.fontColor('#F44336');
                        Text.margin({ bottom: 16 });
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel('重试');
                        Button.debugLine("entry/src/main/ets/pages/VideoList.ets(165:11)", "entry");
                        Button.type(ButtonType.Capsule);
                        Button.width(120);
                        Button.height(40);
                        Button.backgroundColor('#4FC3F7');
                        Button.onClick(() => { this.loadItems(); });
                    }, Button);
                    Button.pop();
                    Column.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(2, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        List.create({ space: 8 });
                        List.debugLine("entry/src/main/ets/pages/VideoList.ets(176:9)", "entry");
                        List.width('100%');
                        List.layoutWeight(1);
                        List.padding({ left: 16, right: 16, top: 8, bottom: 16 });
                        List.divider({ strokeWidth: 0 });
                    }, List);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        ForEach.create();
                        const forEachItemGenFunction = _item => {
                            const item = _item;
                            {
                                const itemCreation = (elmtId, isInitialRender) => {
                                    ViewStackProcessor.StartGetAccessRecordingFor(elmtId);
                                    ListItem.create(deepRenderFunction, true);
                                    if (!isInitialRender) {
                                        ListItem.pop();
                                    }
                                    ViewStackProcessor.StopGetAccessRecording();
                                };
                                const itemCreation2 = (elmtId, isInitialRender) => {
                                    ListItem.create(deepRenderFunction, true);
                                    ListItem.onClick(() => { this.navigateToPlayer(item); });
                                    ListItem.debugLine("entry/src/main/ets/pages/VideoList.ets(178:13)", "entry");
                                };
                                const deepRenderFunction = (elmtId, isInitialRender) => {
                                    itemCreation(elmtId, isInitialRender);
                                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                                        Row.create();
                                        Row.debugLine("entry/src/main/ets/pages/VideoList.ets(179:15)", "entry");
                                        Row.width('100%');
                                        Row.padding(12);
                                        Row.backgroundColor('#252525');
                                        Row.borderRadius(12);
                                    }, Row);
                                    this.PosterImage.bind(this)(item);
                                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                                        Column.create();
                                        Column.debugLine("entry/src/main/ets/pages/VideoList.ets(182:17)", "entry");
                                        Column.alignItems(HorizontalAlign.Start);
                                        Column.layoutWeight(1);
                                        Column.margin({ left: 12 });
                                    }, Column);
                                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                                        Text.create(item.Name);
                                        Text.debugLine("entry/src/main/ets/pages/VideoList.ets(183:19)", "entry");
                                        Text.fontSize(16);
                                        Text.fontWeight(FontWeight.Medium);
                                        Text.fontColor('#FFFFFF');
                                        Text.maxLines(2);
                                        Text.textOverflow({ overflow: TextOverflow.Ellipsis });
                                        Text.margin({ bottom: 6 });
                                    }, Text);
                                    Text.pop();
                                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                                        If.create();
                                        if (item.ProductionYear) {
                                            this.ifElseBranchUpdateFunction(0, () => {
                                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                                    Text.create(`${item.ProductionYear}`);
                                                    Text.debugLine("entry/src/main/ets/pages/VideoList.ets(192:21)", "entry");
                                                    Text.fontSize(13);
                                                    Text.fontColor('#B3B3B3');
                                                    Text.margin({ bottom: 4 });
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
                                        if (item.CommunityRating) {
                                            this.ifElseBranchUpdateFunction(0, () => {
                                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                                    Row.create();
                                                    Row.debugLine("entry/src/main/ets/pages/VideoList.ets(199:21)", "entry");
                                                    Row.margin({ bottom: 4 });
                                                }, Row);
                                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                                    Text.create('⭐');
                                                    Text.debugLine("entry/src/main/ets/pages/VideoList.ets(200:23)", "entry");
                                                    Text.fontSize(12);
                                                }, Text);
                                                Text.pop();
                                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                                    Text.create(`${item.CommunityRating.toFixed(1)}`);
                                                    Text.debugLine("entry/src/main/ets/pages/VideoList.ets(202:23)", "entry");
                                                    Text.fontSize(13);
                                                    Text.fontColor('#FFC107');
                                                }, Text);
                                                Text.pop();
                                                Row.pop();
                                            });
                                        }
                                        // Codec info badge (e.g. "H.265 · 1080p")
                                        else {
                                            this.ifElseBranchUpdateFunction(1, () => {
                                            });
                                        }
                                    }, If);
                                    If.pop();
                                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                                        If.create();
                                        // Codec info badge (e.g. "H.265 · 1080p")
                                        if (this.getCodecSummary(item)) {
                                            this.ifElseBranchUpdateFunction(0, () => {
                                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                                    Text.create(this.getCodecSummary(item));
                                                    Text.debugLine("entry/src/main/ets/pages/VideoList.ets(211:21)", "entry");
                                                    Text.fontSize(11);
                                                    Text.fontColor('#4FC3F7');
                                                    Text.margin({ bottom: 4 });
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
                                        if (item.RunTimeTicks) {
                                            this.ifElseBranchUpdateFunction(0, () => {
                                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                                    Text.create(this.formatDuration(item.RunTimeTicks));
                                                    Text.debugLine("entry/src/main/ets/pages/VideoList.ets(218:21)", "entry");
                                                    Text.fontSize(12);
                                                    Text.fontColor('#666666');
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
                                    Column.pop();
                                    Row.pop();
                                    ListItem.pop();
                                };
                                this.observeComponentCreation2(itemCreation2, ListItem);
                                ListItem.pop();
                            }
                        };
                        this.forEachUpdateFunction(elmtId, this.items, forEachItemGenFunction);
                    }, ForEach);
                    ForEach.pop();
                    List.pop();
                });
            }
        }, If);
        If.pop();
        Column.pop();
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
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "VideoList";
    }
}
registerNamedRoute(() => new VideoList(undefined, {}), "", { bundleName: "com.emby.harmonyos", moduleName: "entry", pagePath: "pages/VideoList", pageFullPath: "entry/src/main/ets/pages/VideoList", integratedHsp: "false", moduleType: "followWithHap" });
