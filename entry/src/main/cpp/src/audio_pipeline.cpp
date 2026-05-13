#include "emby_player.h"
#include <cstring>

AudioPipeline::AudioPipeline() {}

AudioPipeline::~AudioPipeline() { release(); }

bool AudioPipeline::create(int sampleRate, int channels, int bitsPerSample) {
    sampleRate_ = sampleRate > 0 ? sampleRate : 48000;
    channels_ = channels > 0 ? channels : 2;
    bitsPerSample_ = bitsPerSample > 0 ? bitsPerSample : 16;

    builder_ = nullptr;
    OH_AudioStreamBuilder* builder = nullptr;
    OH_AudioStream_Result ret = OH_AudioStreamBuilder_Create(&builder, AUDIOSTREAM_TYPE_RENDERER);
    if (ret != AUDIOSTREAM_SUCCESS || !builder) {
        LOGE("Failed to create audio stream builder: %d", ret);
        return false;
    }
    builder_ = builder;

    OH_AudioStreamBuilder_SetSamplingRate(builder_, sampleRate_);
    OH_AudioStreamBuilder_SetChannelCount(builder_, channels_);
    OH_AudioStreamBuilder_SetSampleFormat(builder_, AUDIOSTREAM_SAMPLE_S16LE);
    OH_AudioStreamBuilder_SetEncodingType(builder_, AUDIOSTREAM_ENCODING_TYPE_RAW);
    OH_AudioStreamBuilder_SetLatencyMode(builder_, AUDIOSTREAM_LATENCY_MODE_FAST);
    OH_AudioRenderer_Callbacks callbacks;
    memset(&callbacks, 0, sizeof(callbacks));
    callbacks.OH_AudioRenderer_OnWriteData = AudioRendererOnWriteData;
    OH_AudioStreamBuilder_SetRendererCallback(builder_, callbacks, this);

    OH_AudioRenderer* renderer = nullptr;
    OH_AudioStream_Result genRet = OH_AudioStreamBuilder_GenerateRenderer(builder_, &renderer);
    if (genRet != AUDIOSTREAM_SUCCESS || !renderer) {
        LOGE("Failed to generate audio renderer: %d", genRet);
        return false;
    }
    audioRenderer_ = renderer;

    LOGI("Audio pipeline created: %dHz %dch %dbit", sampleRate_, channels_, bitsPerSample_);
    return true;
}

bool AudioPipeline::start() {
    if (!audioRenderer_) return false;
    int ret = OH_AudioRenderer_Start(audioRenderer_);
    if (ret != AUDIOSTREAM_SUCCESS) {
        LOGE("Audio renderer start failed: %d", ret);
        return false;
    }
    isRunning_ = true;
    LOGI("Audio renderer started");
    return true;
}

void AudioPipeline::stop() {
    isRunning_ = false;
    if (audioRenderer_) {
        OH_AudioRenderer_Stop(audioRenderer_);
    }
}

void AudioPipeline::release() {
    stop();
    if (audioRenderer_) {
        OH_AudioRenderer_Release(audioRenderer_);
        audioRenderer_ = nullptr;
    }
    if (builder_) {
        OH_AudioStreamBuilder_Destroy(builder_);
        builder_ = nullptr;
    }
}

bool AudioPipeline::feedData(const uint8_t* data, size_t size, int64_t pts) {
    if (!isRunning_) return false;
    std::lock_guard<std::mutex> lock(mutex_);
    std::vector<uint8_t> buf(data, data + size);
    audioQueue_.push(std::move(buf));
    if (audioQueue_.size() > 100) {
        audioQueue_.pop();
    }
    return true;
}

int32_t AudioPipeline::
AudioRendererOnWriteData(
    OH_AudioRenderer* renderer,
    void* userData,
    void* buffer,
    int32_t bufferLen) {
    auto* self = static_cast<AudioPipeline*>(userData);
    if (!self || !self->isRunning_) {
        memset(buffer, 0, bufferLen);
        return AUDIOSTREAM_SUCCESS;
    }

    std::lock_guard<std::mutex> lock(self->mutex_);
    if (self->audioQueue_.empty()) {
        memset(buffer, 0, bufferLen);
        return AUDIOSTREAM_SUCCESS;
    }

    auto& front = self->audioQueue_.front();
    int copyLen = std::min((int)front.size(), bufferLen);
    memcpy(buffer, front.data(), copyLen);
    if (copyLen < bufferLen) {
        memset((uint8_t*)buffer + copyLen, 0, bufferLen - copyLen);
    }
    self->audioQueue_.pop();
    return AUDIOSTREAM_SUCCESS;
}
