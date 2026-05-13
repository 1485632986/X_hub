import hilog from "@ohos:hilog";
const TAG = 'CodecCapability';
const DOMAIN = 0xFF00;
export interface HardwareCodecInfo {
    codecName: string;
    mimeType: string;
    codecType: string;
    maxWidth: number;
    maxHeight: number;
    isHardwareAccelerated: boolean;
}
export interface HdrCapability {
    hdr10: boolean;
    hlg: boolean;
    hdr10Plus: boolean;
    dolbyVision: boolean;
}
export interface DeviceCodecProfile {
    hardwareCodecs: HardwareCodecInfo[];
    hdrCapability: HdrCapability;
    supportsH264: boolean;
    supportsH265: boolean;
    supportsVP9: boolean;
    supportsAV1: boolean;
    maxResolution: string;
}
interface CodecMimeMap {
    AVC: string;
    HEVC: string;
    VP9: string;
    AV1: string;
}
const CODEC_MIME: CodecMimeMap = {
    AVC: 'video/avc',
    HEVC: 'video/hevc',
    VP9: 'video/x-vnd.on2.vp9',
    AV1: 'video/av01',
};
const CODEC_TYPE_NAMES: Record<string, string> = {
    'video/avc': 'H.264/AVC',
    'video/hevc': 'H.265/HEVC',
    'video/x-vnd.on2.vp9': 'VP9',
    'video/av01': 'AV1',
};
export class CodecCapabilityService {
    private static profile: DeviceCodecProfile | null = null;
    static async getDeviceCodecProfile(): Promise<DeviceCodecProfile> {
        if (CodecCapabilityService.profile) {
            return CodecCapabilityService.profile;
        }
        const defaultCodecs: HardwareCodecInfo[] = [
            {
                codecName: 'H.264/AVC Hardware Decoder',
                mimeType: CODEC_MIME.AVC,
                codecType: 'avc',
                maxWidth: 3840,
                maxHeight: 2160,
                isHardwareAccelerated: true
            },
            {
                codecName: 'H.265/HEVC Hardware Decoder',
                mimeType: CODEC_MIME.HEVC,
                codecType: 'hevc',
                maxWidth: 3840,
                maxHeight: 2160,
                isHardwareAccelerated: true
            }
        ];
        CodecCapabilityService.profile = {
            hardwareCodecs: defaultCodecs,
            hdrCapability: CodecCapabilityService.detectHdrCapability(),
            supportsH264: true,
            supportsH265: true,
            supportsVP9: false,
            supportsAV1: false,
            maxResolution: '4K'
        };
        hilog.info(DOMAIN, TAG, `Codec profile: H264=${CodecCapabilityService.profile.supportsH264}, ` +
            `H265=${CodecCapabilityService.profile.supportsH265}, VP9=${CodecCapabilityService.profile.supportsVP9}, ` +
            `AV1=${CodecCapabilityService.profile.supportsAV1}, MaxRes=${CodecCapabilityService.profile.maxResolution}`);
        return CodecCapabilityService.profile;
    }
    static async findBestDecoder(mimeType: string): Promise<HardwareCodecInfo | null> {
        const profile = await CodecCapabilityService.getDeviceCodecProfile();
        const candidates: HardwareCodecInfo[] = [];
        for (let i = 0; i < profile.hardwareCodecs.length; i++) {
            if (profile.hardwareCodecs[i].mimeType === mimeType) {
                candidates.push(profile.hardwareCodecs[i]);
            }
        }
        if (candidates.length === 0) {
            return null;
        }
        for (let i = 0; i < candidates.length; i++) {
            if (candidates[i].isHardwareAccelerated) {
                return candidates[i];
            }
        }
        return candidates[0];
    }
    static async canDecode(codecType: string): Promise<boolean> {
        const profile = await CodecCapabilityService.getDeviceCodecProfile();
        const lower: string = codecType.toLowerCase();
        if (lower === 'avc' || lower === 'h264') {
            return profile.supportsH264;
        }
        if (lower === 'hevc' || lower === 'h265') {
            return profile.supportsH265;
        }
        if (lower === 'vp9') {
            return profile.supportsVP9;
        }
        if (lower === 'av1') {
            return profile.supportsAV1;
        }
        return false;
    }
    static codecToMimeType(videoCodec: string): string {
        const codec: string = videoCodec.toLowerCase();
        if (codec.includes('h264') || codec.includes('avc')) {
            return CODEC_MIME.AVC;
        }
        if (codec.includes('h265') || codec.includes('hevc')) {
            return CODEC_MIME.HEVC;
        }
        if (codec.includes('vp9')) {
            return CODEC_MIME.VP9;
        }
        if (codec.includes('av1')) {
            return CODEC_MIME.AV1;
        }
        return '';
    }
    static getCodecDisplayName(videoCodec: string): string {
        const mime: string = CodecCapabilityService.codecToMimeType(videoCodec);
        const name: string | undefined = CODEC_TYPE_NAMES[mime];
        if (name !== undefined) {
            return name;
        }
        return videoCodec.toUpperCase();
    }
    static async shouldUseHardwareDecode(videoCodec: string): Promise<boolean> {
        const mime: string = CodecCapabilityService.codecToMimeType(videoCodec);
        if (!mime) {
            return false;
        }
        const decoder: HardwareCodecInfo | null = await CodecCapabilityService.findBestDecoder(mime);
        return decoder !== null && decoder.isHardwareAccelerated;
    }
    private static detectHdrCapability(): HdrCapability {
        return {
            hdr10: true,
            hlg: true,
            hdr10Plus: false,
            dolbyVision: false
        };
    }
}
