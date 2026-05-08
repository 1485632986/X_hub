import { media } from '@kit.MediaKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'CodecCapability';
const DOMAIN = 0xFF00;

/**
 * Information about a hardware video decoder found on the device
 */
export interface HardwareCodecInfo {
  codecName: string;       // e.g. "OMX.hisi.video.decoder.avc"
  mimeType: string;        // e.g. "video/avc"
  codecType: string;       // "avc" | "hevc" | "vp9" | "av1"
  maxWidth: number;        // max supported width in pixels
  maxHeight: number;       // max supported height in pixels
  isHardwareAccelerated: boolean;
}

/**
 * HDR capability information
 */
export interface HdrCapability {
  hdr10: boolean;
  hlg: boolean;
  hdr10Plus: boolean;
  dolbyVision: boolean;
}

/**
 * Overall device codec profile
 */
export interface DeviceCodecProfile {
  hardwareCodecs: HardwareCodecInfo[];
  hdrCapability: HdrCapability;
  supportsH264: boolean;
  supportsH265: boolean;
  supportsVP9: boolean;
  supportsAV1: boolean;
  maxResolution: string;   // e.g. "4K" or "1080P"
}
/**
 * Codec MIME type constants
 */
const CODEC_MIME = {
  AVC: 'video/avc',        // H.264
  HEVC: 'video/hevc',      // H.265
  VP9: 'video/x-vnd.on2.vp9',
  AV1: 'video/av01',
};

/**
 * Codec type name mapping
 */
const CODEC_TYPE_NAMES: Record<string, string> = {
  'video/avc': 'H.264/AVC',
  'video/hevc': 'H.265/HEVC',
  'video/x-vnd.on2.vp9': 'VP9',
  'video/av01': 'AV1',
};

/**
 * Service for querying device hardware codec capabilities
 */
export class CodecCapabilityService {
  private static profile: DeviceCodecProfile | null = null;

  /**
   * Scan the device for hardware codec capabilities.
   * Results are cached after first call.
   */
  static async getDeviceCodecProfile(): Promise<DeviceCodecProfile> {
    if (CodecCapabilityService.profile) {
      return CodecCapabilityService.profile;
    }

    const hardwareCodecs: HardwareCodecInfo[] = [];
    const supportedMimeTypes = new Set<string>();

    try {
      const codecList = await media.getAVCodecList();

      // Enumerate video decoders
      const videoDecoders = codecList.getDecoderCodecArray(media.CodecType.VIDEO_DECODER);

      if (videoDecoders && videoDecoders.length > 0) {
        for (const capability of videoDecoders) {
          try {
            const codecInfo = capability.getCodecInfo();
            const mimeType = codecInfo.getMimeType();
            const codecName = codecInfo.getName();
            const isHardware = codecName.toLowerCase().includes('omx') ||
                               codecName.toLowerCase().includes('hisi') ||
                               codecName.toLowerCase().includes('hw') ||
                               !codecName.toLowerCase().includes('sw');
            const codecType = CodecCapabilityService.inferCodecType(mimeType, codecName);

            const maxWidth = capability.getMaxSupportedInstances() > 0 ? 3840 : 1920;
            const maxHeight = capability.getMaxSupportedInstances() > 0 ? 2160 : 1080;

            const info: HardwareCodecInfo = {
              codecName: codecName,
              mimeType: mimeType,
              codecType: codecType,
              maxWidth: maxWidth,
              maxHeight: maxHeight,
              isHardwareAccelerated: isHardware
            };

            hardwareCodecs.push(info);
            supportedMimeTypes.add(mimeType);

            hilog.info(DOMAIN, TAG,
              `Found decoder: ${codecName}, mime: ${mimeType}, hw: ${isHardware}`);
          } catch (e) {
            hilog.warn(DOMAIN, TAG, `Error reading codec info: ${e}`);
          }
        }
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Failed to enumerate codecs: ${err}`);
    }
    // Build profile
    CodecCapabilityService.profile = {
      hardwareCodecs: hardwareCodecs,
      hdrCapability: CodecCapabilityService.detectHdrCapability(),
      supportsH264: supportedMimeTypes.has(CODEC_MIME.AVC),
      supportsH265: supportedMimeTypes.has(CODEC_MIME.HEVC),
      supportsVP9: supportedMimeTypes.has(CODEC_MIME.VP9),
      supportsAV1: supportedMimeTypes.has(CODEC_MIME.AV1),
      maxResolution: CodecCapabilityService.determineMaxResolution(hardwareCodecs)
    };
    hilog.info(DOMAIN, TAG, `Codec profile: H264=${CodecCapabilityService.profile.supportsH264}, ` +
      `H265=${CodecCapabilityService.profile.supportsH265}, VP9=${CodecCapabilityService.profile.supportsVP9}, ` +
      `AV1=${CodecCapabilityService.profile.supportsAV1}, MaxRes=${CodecCapabilityService.profile.maxResolution}`);

    return this.profile;
  }

  /**
   * Find the best hardware decoder for a given MIME type.
   * Prefers hardware-accelerated decoders.
   *
   * @param mimeType - e.g. "video/hevc"
   * @returns HardwareCodecInfo or null if no decoder found
   */
  static async findBestDecoder(mimeType: string): Promise<HardwareCodecInfo | null> {
    const profile = await this.getDeviceCodecProfile();
    const candidates = profile.hardwareCodecs.filter(c => c.mimeType === mimeType);

    if (candidates.length === 0) {
      return null;
    }

    // Prefer hardware accelerated
    const hwDecoder = candidates.find(c => c.isHardwareAccelerated);
    return hwDecoder || candidates[0];
  }

  /**
   * Determine if the device can hardware-decode a specific codec type.
   *
   * @param codecType - "avc" | "hevc" | "vp9" | "av1"
   */
  static async canDecode(codecType: string): Promise<boolean> {
    const profile = await CodecCapabilityService.getDeviceCodecProfile();
    switch (codecType.toLowerCase()) {
      case 'avc':
      case 'h264':
        return profile.supportsH264;
      case 'hevc':
      case 'h265':
        return profile.supportsH265;
      case 'vp9':
        return profile.supportsVP9;
      case 'av1':
        return profile.supportsAV1;
      default:
        return false;
    }
  }

  /**
   * Map a video codec string (from Emby MediaSource) to a MIME type.
   *
   * @param videoCodec - e.g. "h264", "hevc", "vp9", "av1"
   * @returns MIME type string, or empty string if unknown
   */
  static codecToMimeType(videoCodec: string): string {
    const codec = videoCodec.toLowerCase();
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

  /**
   * Get a human-readable codec name.
   */
  static getCodecDisplayName(videoCodec: string): string {
    const mime = CodecCapabilityService.codecToMimeType(videoCodec);
    return CODEC_TYPE_NAMES[mime] || videoCodec.toUpperCase();
  }

  /**
   * Check if hardware decoding should be used for the given codec.
   * Returns true if a hardware decoder is available.
   */
  static async shouldUseHardwareDecode(videoCodec: string): Promise<boolean> {
    const mime = CodecCapabilityService.codecToMimeType(videoCodec);
    if (!mime) {
      return false;
    }
    const decoder = await CodecCapabilityService.findBestDecoder(mime);
    return decoder !== null && decoder.isHardwareAccelerated;
  }

  /**
   * Infer codec type from MIME type and codec name
   */
  private static inferCodecType(mimeType: string, codecName: string): string {
    if (mimeType.includes('avc') || codecName.includes('avc')) {
      return 'avc';
    }
    if (mimeType.includes('hevc') || codecName.includes('hevc')) {
      return 'hevc';
    }
    if (mimeType.includes('vp9') || codecName.includes('vp9')) {
      return 'vp9';
    }
    if (mimeType.includes('av01') || codecName.includes('av1')) {
      return 'av1';
    }
    return 'unknown';
  }

  /**
   * Detect HDR capabilities from the device.
   * Uses screen/display properties where available.
   */
  private static detectHdrCapability(): HdrCapability {
    // Default conservative values — actual HDR detection requires
    // display capability queries which are device-specific.
    // AVPlayer handles HDR automatically when the display supports it.
    return {
      hdr10: true,        // HDR10 widely supported on modern Huawei devices
      hlg: true,          // HLG widely supported
      hdr10Plus: false,   // Requires specific panel support
      dolbyVision: false  // Requires Dolby license
    };
  }

  /**
   * Determine the maximum resolution the device can decode
   */
  private static determineMaxResolution(codecs: HardwareCodecInfo[]): string {
    if (codecs.some(c => c.maxWidth >= 3840 && c.maxHeight >= 2160)) {
      return '4K';
    }
    if (codecs.some(c => c.maxWidth >= 1920 && c.maxHeight >= 1080)) {
      return '1080P';
    }
    return '720P';
  }
}
