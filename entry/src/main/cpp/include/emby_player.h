#ifndef EMBY_PLAYER_H
#define EMBY_PLAYER_H

#include <cstdint>
#include <string>
#include <vector>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <thread>
#include <atomic>
#include <functional>
#include <memory>
#include <map>

#include <multimedia/player_framework/native_avcodec_videodecoder.h>
#include <multimedia/player_framework/native_avcodec_audiodecoder.h>
#include <multimedia/player_framework/native_avcodec_base.h>
#include <multimedia/player_framework/native_avformat.h>
#include <multimedia/player_framework/native_avbuffer.h>
#include <ohaudio/native_audiorenderer.h>
#include <ohaudio/native_audiostreambuilder.h>
#include <native_window/external_window.h>
#include <hilog/log.h>

#undef LOG_TAG
#define LOG_TAG "EmbyPlayer"
#define LOGI(...) OH_LOG_Print(LOG_APP, LOG_INFO, 0xFF00, LOG_TAG, __VA_ARGS__)
#define LOGW(...) OH_LOG_Print(LOG_APP, LOG_WARN, 0xFF00, LOG_TAG, __VA_ARGS__)
#define LOGE(...) OH_LOG_Print(LOG_APP, LOG_ERROR, 0xFF00, LOG_TAG, __VA_ARGS__)

static constexpr int TS_PACKET_SIZE = 188;
static constexpr int TS_SYNC_BYTE = 0x47;
static constexpr int MAX_PES_PAYLOAD = 4 * 1024 * 1024;

enum class PlayerState {
    IDLE, INITIALIZED, PREPARING, PREPARED,
    PLAYING, PAUSED, STOPPED, ERROR
};

enum class MediaType { VIDEO, AUDIO, SUBTITLE, UNKNOWN };

struct VideoInfo {
    int width = 0;
    int height = 0;
    int codecId = 0;
    std::string codecName;
    double frameRate = 0;
    int64_t bitrate = 0;
};

struct AudioInfo {
    int sampleRate = 0;
    int channels = 0;
    int bitsPerSample = 16;
    int codecId = 0;
    std::string codecName;
};

struct AVPacket {
    std::vector<uint8_t> data;
    int64_t pts = 0;
    int64_t dts = 0;
    bool isKeyFrame = false;
    MediaType type = MediaType::UNKNOWN;
};

struct DemuxResult {
    std::vector<AVPacket> videoPackets;
    std::vector<AVPacket> audioPackets;
    VideoInfo videoInfo;
    AudioInfo audioInfo;
    bool hasVideo = false;
    bool hasAudio = false;
};

class TSDemuxer {
public:
    TSDemuxer();
    ~TSDemuxer();

    void feed(const uint8_t* data, size_t len);
    bool readPackets(DemuxResult& result);
    void reset();
    const VideoInfo& getVideoInfo() const { return videoInfo_; }
    const AudioInfo& getAudioInfo() const { return audioInfo_; }
    bool hasVideo() const { return hasVideo_; }
    bool hasAudio() const { return hasAudio_; }

private:
    void parseTSPacket(const uint8_t* packet);
    void parsePAT(const uint8_t* payload, int len);
    void parsePMT(const uint8_t* payload, int len);
    void parsePES(int pid, const uint8_t* payload, int len, bool payloadStart);
    void emitPacket(int pid, const std::vector<uint8_t>& data, bool isStart);
    int readBits(const uint8_t* buf, int& bitPos, int n);
    void parseSPS(const uint8_t* data, int len);

    std::vector<uint8_t> buffer_;
    std::map<int, std::vector<uint8_t>> pesBuffers_;
    std::map<int, bool> pesStartFlags_;
    std::map<int, int> continuityCounters_;
    int pmtPid_ = -1;
    int videoPid_ = -1;
    int audioPid_ = -1;
    int videoStreamType_ = -1;
    int audioStreamType_ = -1;
    VideoInfo videoInfo_;
    AudioInfo audioInfo_;
    bool hasVideo_ = false;
    bool hasAudio_ = false;
    DemuxResult pendingResult_;
    std::mutex mutex_;
};

class HWVideoDecoder {
public:
    HWVideoDecoder();
    ~HWVideoDecoder();

    bool create(const std::string& mimeType, int width, int height);
    void setSurface(OHNativeWindow* window);
    bool start();
    void stop();
    void release();
    bool feedData(const uint8_t* data, size_t size, int64_t pts, bool isKeyFrame);
    void setOnVideoSizeChanged(std::function<void(int, int)> callback);
    std::string getMimeTypeForCodec(int codecId);

private:
    static void OnError(OH_AVCodec* codec, int32_t errorCode, void* userData);
    static void OnStreamChanged(OH_AVCodec* codec, OH_AVFormat* format, void* userData);
    static void OnNeedInputData(OH_AVCodec* codec, uint32_t index, OH_AVMemory* buffer, void* userData);
    static void OnNewOutputData(OH_AVCodec* codec, uint32_t index, OH_AVMemory* buffer, OH_AVCodecBufferAttr* attr, void* userData);

    OH_AVCodec* codec_ = nullptr;
    OHNativeWindow* surface_ = nullptr;
    std::atomic<bool> isRunning_{false};
    int width_ = 0;
    int height_ = 0;
    std::function<void(int, int)> onVideoSizeChanged_;
    std::mutex mutex_;
};

class AudioPipeline {
public:
    AudioPipeline();
    ~AudioPipeline();

    bool create(int sampleRate, int channels, int bitsPerSample);
    bool start();
    void stop();
    void release();
    bool feedData(const uint8_t* data, size_t size, int64_t pts);

private:
    static int32_t AudioRendererOnWriteData(
        OH_AudioRenderer* renderer,
        void* userData,
        void* buffer,
        int32_t bufferLen);

    OH_AudioRenderer* audioRenderer_ = nullptr;
    OH_AudioStreamBuilder* builder_ = nullptr;
    std::mutex mutex_;
    std::queue<std::vector<uint8_t>> audioQueue_;
    std::atomic<bool> isRunning_{false};
    int sampleRate_ = 0;
    int channels_ = 0;
    int bitsPerSample_ = 0;
};

struct PlayerEngineConfig {
    std::string url;
    std::string surfaceId;
    std::function<void(const std::string&)> onStateChange;
    std::function<void(int64_t)> onTimeUpdate;
    std::function<void(int, const std::string&)> onError;
    std::function<void(int, int)> onVideoSizeChanged;
};

class PlayerEngine {
public:
    PlayerEngine();
    ~PlayerEngine();

    bool setDataSource(const std::string& url);
    bool setSurface(uint64_t surfaceId);
    bool prepare();
    bool start();
    bool pause();
    bool resume();
    bool seek(int64_t positionMs);
    bool setSpeed(float speed);
    void release();
    void feedData(const uint8_t* data, size_t len);
    PlayerState getState() const { return state_; }
    void setOnStateChange(std::function<void(const std::string&)> cb) { onStateChange_ = cb; }
    void setOnError(std::function<void(int, const std::string&)> cb) { onError_ = cb; }
    void setOnVideoSizeChanged(std::function<void(int, int)> cb) { onVideoSizeChanged_ = cb; }

private:
    void demuxLoop();
    void videoDecodeLoop();
    void notifyState(const std::string& state);
    void notifyError(int code, const std::string& msg);
    bool connectHTTP(const std::string& url);

    PlayerState state_ = PlayerState::IDLE;
    std::string url_;
    uint64_t surfaceId_ = 0;
    OHNativeWindow* nativeWindow_ = nullptr;

    std::unique_ptr<TSDemuxer> demuxer_;
    std::unique_ptr<HWVideoDecoder> videoDecoder_;
    std::unique_ptr<AudioPipeline> audioPipeline_;

    std::thread demuxThread_;
    std::atomic<bool> shouldStop_{false};
    std::atomic<bool> isPaused_{false};

    std::queue<AVPacket> videoQueue_;
    std::mutex videoQueueMutex_;
    std::condition_variable videoQueueCV_;

    std::queue<AVPacket> audioQueue_;
    std::mutex audioQueueMutex_;

    std::function<void(const std::string&)> onStateChange_;
    std::function<void(int64_t)> onTimeUpdate_;
    std::function<void(int, const std::string&)> onError_;
    std::function<void(int, int)> onVideoSizeChanged_;

    int socketFd_ = -1;
    std::mutex engineMutex_;
};

#endif // EMBY_PLAYER_H
