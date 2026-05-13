#include "emby_player.h"
#include <cstring>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <fcntl.h>

PlayerEngine::PlayerEngine()
    : demuxer_(std::make_unique<TSDemuxer>())
    , videoDecoder_(std::make_unique<HWVideoDecoder>())
    , audioPipeline_(std::make_unique<AudioPipeline>()) {}

PlayerEngine::~PlayerEngine() { release(); }

bool PlayerEngine::setDataSource(const std::string& url) {
    url_ = url;
    state_ = PlayerState::INITIALIZED;
    notifyState("initialized");
    LOGI("Data source set: %s", url.c_str());
    return true;
}

bool PlayerEngine::setSurface(uint64_t surfaceId) {
    surfaceId_ = surfaceId;
    OHNativeWindow* window = nullptr;
    int32_t ret = OH_NativeWindow_CreateNativeWindowFromSurfaceId(surfaceId, &window);
    nativeWindow_ = window;
    if (ret != 0 || !nativeWindow_) {
        LOGE("Failed to create native window from surface ID, ret=%d", ret);
        return false;
    }
    LOGI("Surface set, native window created");
    return true;
}

bool PlayerEngine::prepare() {
    state_ = PlayerState::PREPARING;
    notifyState("preparing");

    if (!videoDecoder_->create("video/avc", 1920, 1080)) {
        notifyError(-1, "Failed to create video decoder");
        return false;
    }

    if (nativeWindow_) {
        videoDecoder_->setSurface(nativeWindow_);
    }

    videoDecoder_->setOnVideoSizeChanged([this](int w, int h) {
        if (onVideoSizeChanged_) onVideoSizeChanged_(w, h);
    });

    if (!videoDecoder_->start()) {
        notifyError(-1, "Failed to start video decoder");
        return false;
    }

    state_ = PlayerState::PREPARED;
    notifyState("prepared");
    LOGI("Player prepared");
    return true;
}

bool PlayerEngine::start() {
    if (state_ != PlayerState::PREPARED && state_ != PlayerState::PAUSED) {
        return false;
    }

    shouldStop_ = false;
    isPaused_ = false;

    demuxThread_ = std::thread(&PlayerEngine::demuxLoop, this);

    state_ = PlayerState::PLAYING;
    notifyState("playing");
    LOGI("Player started");
    return true;
}

bool PlayerEngine::pause() {
    isPaused_ = true;
    state_ = PlayerState::PAUSED;
    notifyState("paused");
    return true;
}

bool PlayerEngine::resume() {
    isPaused_ = false;
    state_ = PlayerState::PLAYING;
    notifyState("playing");
    return true;
}

bool PlayerEngine::seek(int64_t positionMs) {
    LOGI("Seek to %lld ms", (long long)positionMs);
    return true;
}

bool PlayerEngine::setSpeed(float speed) {
    LOGI("Set speed: %.2f", speed);
    return true;
}

void PlayerEngine::release() {
    shouldStop_ = true;
    isPaused_ = false;

    if (demuxThread_.joinable()) {
        demuxThread_.join();
    }

    videoDecoder_->release();
    audioPipeline_->release();

    if (nativeWindow_) {
        OH_NativeWindow_DestroyNativeWindow(nativeWindow_);
        nativeWindow_ = nullptr;
    }

    if (socketFd_ >= 0) {
        close(socketFd_);
        socketFd_ = -1;
    }

    state_ = PlayerState::IDLE;
}

void PlayerEngine::notifyState(const std::string& state) {
    if (onStateChange_) onStateChange_(state);
}

void PlayerEngine::notifyError(int code, const std::string& msg) {
    LOGE("Error %d: %s", code, msg.c_str());
    state_ = PlayerState::ERROR;
    if (onError_) onError_(code, msg);
}

bool PlayerEngine::connectHTTP(const std::string& url) {
    std::string host, path;
    int port = 80;

    size_t schemeEnd = url.find("://");
    if (schemeEnd == std::string::npos) return false;
    size_t hostStart = schemeEnd + 3;
    size_t pathStart = url.find('/', hostStart);
    std::string hostPort;
    if (pathStart != std::string::npos) {
        hostPort = url.substr(hostStart, pathStart - hostStart);
        path = url.substr(pathStart);
    } else {
        hostPort = url.substr(hostStart);
        path = "/";
    }
    size_t colonPos = hostPort.find(':');
    if (colonPos != std::string::npos) {
        host = hostPort.substr(0, colonPos);
        port = std::stoi(hostPort.substr(colonPos + 1));
    } else {
        host = hostPort;
    }

    struct hostent* server = gethostbyname(host.c_str());
    if (!server) {
        LOGE("Failed to resolve host: %s", host.c_str());
        return false;
    }

    socketFd_ = socket(AF_INET, SOCK_STREAM, 0);
    if (socketFd_ < 0) return false;

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    memcpy(&addr.sin_addr.s_addr, server->h_addr, server->h_length);

    if (connect(socketFd_, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(socketFd_);
        socketFd_ = -1;
        return false;
    }

    std::string request = "GET " + path + " HTTP/1.1\r\n"
        "Host: " + host + "\r\n"
        "Connection: close\r\n"
        "\r\n";

    send(socketFd_, request.c_str(), request.size(), 0);

    char buf[4096];
    bool headersDone = false;
    std::string headerBuf;
    while (!headersDone) {
        int n = recv(socketFd_, buf, sizeof(buf), 0);
        if (n <= 0) return false;
        headerBuf.append(buf, n);
        size_t pos = headerBuf.find("\r\n\r\n");
        if (pos != std::string::npos) {
            headersDone = true;
            size_t bodyStart = pos + 4;
            if (bodyStart < headerBuf.size()) {
                size_t bodyLen = headerBuf.size() - bodyStart;
                demuxer_->feed((const uint8_t*)headerBuf.c_str() + bodyStart, bodyLen);
            }
        }
    }

    LOGI("HTTP connected to %s:%d%s", host.c_str(), port, path.c_str());
    return true;
}

void PlayerEngine::demuxLoop() {
    if (!connectHTTP(url_)) {
        notifyError(-2, "Failed to connect to stream URL");
        return;
    }

    uint8_t buf[65536];
    while (!shouldStop_) {
        if (isPaused_) {
            std::this_thread::sleep_for(std::chrono::milliseconds(50));
            continue;
        }

        int n = recv(socketFd_, buf, sizeof(buf), 0);
        if (n <= 0) {
            LOGI("Stream ended or error (n=%d)", n);
            break;
        }

        demuxer_->feed(buf, n);

        DemuxResult result;
        if (demuxer_->readPackets(result)) {
            for (auto& pkt : result.videoPackets) {
                if (pkt.type == MediaType::VIDEO && videoDecoder_) {
                    videoDecoder_->feedData(
                        pkt.data.data(), pkt.data.size(), pkt.pts, pkt.isKeyFrame);
                }
            }
            for (auto& pkt : result.audioPackets) {
                if (pkt.type == MediaType::AUDIO && audioPipeline_) {
                    audioPipeline_->feedData(
                        pkt.data.data(), pkt.data.size(), pkt.pts);
                }
            }
        }
    }

    if (socketFd_ >= 0) {
        close(socketFd_);
        socketFd_ = -1;
    }
    LOGI("Demux loop ended");
}

void PlayerEngine::feedData(const uint8_t* data, size_t len) {
    if (state_ != PlayerState::PLAYING && state_ != PlayerState::PREPARED) return;
    demuxer_->feed(data, len);

    DemuxResult result;
    if (demuxer_->readPackets(result)) {
        for (auto& pkt : result.videoPackets) {
            if (pkt.type == MediaType::VIDEO && videoDecoder_) {
                videoDecoder_->feedData(
                    pkt.data.data(), pkt.data.size(), pkt.pts, pkt.isKeyFrame);
            }
        }
        for (auto& pkt : result.audioPackets) {
            if (pkt.type == MediaType::AUDIO && audioPipeline_) {
                audioPipeline_->feedData(
                    pkt.data.data(), pkt.data.size(), pkt.pts);
            }
        }
    }
}
