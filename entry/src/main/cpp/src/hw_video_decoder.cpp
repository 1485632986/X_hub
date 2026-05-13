#include "emby_player.h"
#include <cstring>

HWVideoDecoder::HWVideoDecoder() {}

HWVideoDecoder::~HWVideoDecoder() { release(); }

std::string HWVideoDecoder::getMimeTypeForCodec(int codecId) {
    if (codecId == 0x1B) return "video/avc";
    if (codecId == 0x24) return "video/hevc";
    return "video/avc";
}

bool HWVideoDecoder::create(const std::string& mimeType, int width, int height) {
    width_ = width > 0 ? width : 1920;
    height_ = height > 0 ? height : 1080;

    codec_ = OH_VideoDecoder_CreateByMime(mimeType.c_str());
    if (!codec_) {
        LOGE("Failed to create video decoder for %s", mimeType.c_str());
        return false;
    }

    OH_AVFormat* format = OH_AVFormat_Create();
    OH_AVFormat_SetIntValue(format, OH_MD_KEY_WIDTH, width_);
    OH_AVFormat_SetIntValue(format, OH_MD_KEY_HEIGHT, height_);
    int ret = OH_VideoDecoder_Configure(codec_, format);
    OH_AVFormat_Destroy(format);

    if (ret != AV_ERR_OK) {
        LOGE("Failed to configure video decoder: %d", ret);
        OH_VideoDecoder_Destroy(codec_);
        codec_ = nullptr;
        return false;
    }

    LOGI("Video decoder created: %s %dx%d", mimeType.c_str(), width_, height_);
    return true;
}

void HWVideoDecoder::setSurface(OHNativeWindow* window) {
    surface_ = window;
    if (codec_ && surface_) {
        int ret = OH_VideoDecoder_SetSurface(codec_, surface_);
        LOGI("Set surface result: %d", ret);
    }
}

bool HWVideoDecoder::start() {
    if (!codec_) return false;
    OH_AVCodecAsyncCallback callback;
    callback.onError = OnError;
    callback.onStreamChanged = OnStreamChanged;
    callback.onNeedInputData = OnNeedInputData;
    callback.onNeedOutputData = OnNewOutputData;
    OH_VideoDecoder_SetCallback(codec_, callback, this);

    int ret = OH_VideoDecoder_Prepare(codec_);
    if (ret != AV_ERR_OK) {
        LOGE("Video decoder prepare failed: %d", ret);
        return false;
    }

    ret = OH_VideoDecoder_Start(codec_);
    if (ret != AV_ERR_OK) {
        LOGE("Video decoder start failed: %d", ret);
        return false;
    }

    isRunning_ = true;
    LOGI("Video decoder started");
    return true;
}

void HWVideoDecoder::stop() {
    isRunning_ = false;
    if (codec_) {
        OH_VideoDecoder_Stop(codec_);
    }
}

void HWVideoDecoder::release() {
    stop();
    if (codec_) {
        OH_VideoDecoder_Destroy(codec_);
        codec_ = nullptr;
    }
    surface_ = nullptr;
}

bool HWVideoDecoder::feedData(const uint8_t* data, size_t size, int64_t pts, bool isKeyFrame) {
    if (!codec_ || !isRunning_) return false;
    return true;
}

void HWVideoDecoder::OnError(OH_AVCodec* codec, int32_t errorCode, void* userData) {
    LOGE("Video decoder error: %d", errorCode);
}

void HWVideoDecoder::OnStreamChanged(OH_AVCodec* codec, OH_AVFormat* format, void* userData) {
    auto* self = static_cast<HWVideoDecoder*>(userData);
    int width = 0, height = 0;
    OH_AVFormat_GetIntValue(format, OH_MD_KEY_WIDTH, &width);
    OH_AVFormat_GetIntValue(format, OH_MD_KEY_HEIGHT, &height);
    if (width > 0 && height > 0 && self->onVideoSizeChanged_) {
        self->onVideoSizeChanged_(width, height);
    }
}

void HWVideoDecoder::
OnNeedInputData(OH_AVCodec* codec, uint32_t index, OH_AVMemory* buffer, void* userData) {
}
void HWVideoDecoder::
OnNewOutputData(OH_AVCodec* codec, uint32_t index, OH_AVMemory* buffer, OH_AVCodecBufferAttr* attr, void* userData) {
    if (codec) {
        OH_VideoDecoder_FreeOutputData(codec, index);
    }
}

void HWVideoDecoder::setOnVideoSizeChanged(std::function<void(int, int)> callback) {
    onVideoSizeChanged_ = callback;
}
