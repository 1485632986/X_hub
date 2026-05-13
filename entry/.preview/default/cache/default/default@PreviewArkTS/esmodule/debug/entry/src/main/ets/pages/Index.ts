if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Index_Params {
    serverUrl?: string;
    username?: string;
    password?: string;
    isLoading?: boolean;
    errorMsg?: string;
}
import router from "@ohos:router";
import { EmbyApi } from "@bundle:com.emby.harmonyos/entry/ets/services/EmbyApi";
import type { SessionInfo } from '../models/EmbyTypes';
class Index extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__serverUrl = new ObservedPropertySimplePU('', this, "serverUrl");
        this.__username = new ObservedPropertySimplePU('', this, "username");
        this.__password = new ObservedPropertySimplePU('', this, "password");
        this.__isLoading = new ObservedPropertySimplePU(false, this, "isLoading");
        this.__errorMsg = new ObservedPropertySimplePU('', this, "errorMsg");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Index_Params) {
        if (params.serverUrl !== undefined) {
            this.serverUrl = params.serverUrl;
        }
        if (params.username !== undefined) {
            this.username = params.username;
        }
        if (params.password !== undefined) {
            this.password = params.password;
        }
        if (params.isLoading !== undefined) {
            this.isLoading = params.isLoading;
        }
        if (params.errorMsg !== undefined) {
            this.errorMsg = params.errorMsg;
        }
    }
    updateStateVars(params: Index_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__serverUrl.purgeDependencyOnElmtId(rmElmtId);
        this.__username.purgeDependencyOnElmtId(rmElmtId);
        this.__password.purgeDependencyOnElmtId(rmElmtId);
        this.__isLoading.purgeDependencyOnElmtId(rmElmtId);
        this.__errorMsg.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__serverUrl.aboutToBeDeleted();
        this.__username.aboutToBeDeleted();
        this.__password.aboutToBeDeleted();
        this.__isLoading.aboutToBeDeleted();
        this.__errorMsg.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __serverUrl: ObservedPropertySimplePU<string>;
    get serverUrl() {
        return this.__serverUrl.get();
    }
    set serverUrl(newValue: string) {
        this.__serverUrl.set(newValue);
    }
    private __username: ObservedPropertySimplePU<string>;
    get username() {
        return this.__username.get();
    }
    set username(newValue: string) {
        this.__username.set(newValue);
    }
    private __password: ObservedPropertySimplePU<string>;
    get password() {
        return this.__password.get();
    }
    set password(newValue: string) {
        this.__password.set(newValue);
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
            const session: SessionInfo = await EmbyApi.login(this.serverUrl.trim(), this.username.trim(), this.password);
            router.pushUrl({
                url: 'pages/VideoList',
                params: {
                    serverUrl: session.serverUrl,
                    accessToken: session.accessToken,
                    userId: session.userId,
                    userName: session.userName
                }
            });
        }
        catch (err) {
            if (err instanceof Error) {
                this.errorMsg = `连接失败: ${err.message}`;
            }
            else {
                this.errorMsg = '连接失败: 未知错误';
            }
        }
        finally {
            this.isLoading = false;
        }
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/Index.ets(59:5)", "entry");
            Column.width('100%');
            Column.height('100%');
            Column.backgroundColor('#121212');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
            Blank.debugLine("entry/src/main/ets/pages/Index.ets(60:7)", "entry");
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('Emby');
            Text.debugLine("entry/src/main/ets/pages/Index.ets(62:7)", "entry");
            Text.fontSize(36);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor('#FFFFFF');
            Text.margin({ bottom: 8 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('连接到您的媒体服务器');
            Text.debugLine("entry/src/main/ets/pages/Index.ets(68:7)", "entry");
            Text.fontSize(14);
            Text.fontColor('#B3B3B3');
            Text.margin({ bottom: 48 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TextInput.create({ placeholder: '服务器地址 (如 http://192.168.1.100:8096)', text: this.serverUrl });
            TextInput.debugLine("entry/src/main/ets/pages/Index.ets(73:7)", "entry");
            TextInput.type(InputType.URL);
            TextInput.onChange((value: string) => { this.serverUrl = value; });
            TextInput.width('90%');
            TextInput.height(48);
            TextInput.backgroundColor('#252525');
            TextInput.borderRadius(8);
            TextInput.fontColor('#FFFFFF');
            TextInput.placeholderColor('#666666');
            TextInput.padding({ left: 16, right: 16 });
            TextInput.margin({ bottom: 16 });
            TextInput.enabled(!this.isLoading);
        }, TextInput);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TextInput.create({ placeholder: '用户名', text: this.username });
            TextInput.debugLine("entry/src/main/ets/pages/Index.ets(86:7)", "entry");
            TextInput.type(InputType.Normal);
            TextInput.onChange((value: string) => { this.username = value; });
            TextInput.width('90%');
            TextInput.height(48);
            TextInput.backgroundColor('#252525');
            TextInput.borderRadius(8);
            TextInput.fontColor('#FFFFFF');
            TextInput.placeholderColor('#666666');
            TextInput.padding({ left: 16, right: 16 });
            TextInput.margin({ bottom: 16 });
            TextInput.enabled(!this.isLoading);
        }, TextInput);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TextInput.create({ placeholder: '密码', text: this.password });
            TextInput.debugLine("entry/src/main/ets/pages/Index.ets(99:7)", "entry");
            TextInput.type(InputType.Password);
            TextInput.onChange((value: string) => { this.password = value; });
            TextInput.width('90%');
            TextInput.height(48);
            TextInput.backgroundColor('#252525');
            TextInput.borderRadius(8);
            TextInput.fontColor('#FFFFFF');
            TextInput.placeholderColor('#666666');
            TextInput.padding({ left: 16, right: 16 });
            TextInput.margin({ bottom: 24 });
            TextInput.enabled(!this.isLoading);
        }, TextInput);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel(this.isLoading ? '连接中...' : '连接');
            Button.debugLine("entry/src/main/ets/pages/Index.ets(112:7)", "entry");
            Button.type(ButtonType.Capsule);
            Button.width('90%');
            Button.height(48);
            Button.backgroundColor(this.isLoading ? '#1E88E5' : '#4FC3F7');
            Button.fontSize(16);
            Button.fontWeight(FontWeight.Medium);
            Button.onClick(() => { this.handleConnect(); });
            Button.enabled(!this.isLoading);
        }, Button);
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.isLoading) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        LoadingProgress.create();
                        LoadingProgress.debugLine("entry/src/main/ets/pages/Index.ets(123:9)", "entry");
                        LoadingProgress.width(40);
                        LoadingProgress.height(40);
                        LoadingProgress.color('#4FC3F7');
                        LoadingProgress.margin({ top: 16 });
                    }, LoadingProgress);
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
            if (this.errorMsg) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.errorMsg);
                        Text.debugLine("entry/src/main/ets/pages/Index.ets(131:9)", "entry");
                        Text.fontSize(14);
                        Text.fontColor('#F44336');
                        Text.margin({ top: 16 });
                        Text.width('90%');
                        Text.textAlign(TextAlign.Center);
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
            Blank.create();
            Blank.debugLine("entry/src/main/ets/pages/Index.ets(139:7)", "entry");
        }, Blank);
        Blank.pop();
        Column.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "Index";
    }
}
registerNamedRoute(() => new Index(undefined, {}), "", { bundleName: "com.emby.harmonyos", moduleName: "entry", pagePath: "pages/Index", pageFullPath: "entry/src/main/ets/pages/Index", integratedHsp: "false", moduleType: "followWithHap" });
