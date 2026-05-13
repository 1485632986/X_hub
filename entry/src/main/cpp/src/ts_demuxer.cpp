#include "emby_player.h"
#include <cstring>

TSDemuxer::TSDemuxer() {}

TSDemuxer::~TSDemuxer() {}

void TSDemuxer::feed(const uint8_t* data, size_t len) {
    buffer_.insert(buffer_.end(), data, data + len);
}


void TSDemuxer::reset() {
    std::lock_guard<std::mutex> lock(mutex_);
    buffer_.clear();
    pesBuffers_.clear();
    pesStartFlags_.clear();
    continuityCounters_.clear();
    pmtPid_ = -1;
    videoPid_ = -1;
    audioPid_ = -1;
    hasVideo_ = false;
    hasAudio_ = false;
    pendingResult_ = DemuxResult();
}

int TSDemuxer::readBits(const uint8_t* buf, int& bitPos, int n) {
    int value = 0;
    for (int i = 0; i < n; i++) {
        int byteIndex = bitPos / 8;
        int bitIndex = 7 - (bitPos % 8);
        value = (value << 1) | ((buf[byteIndex] >> bitIndex) & 1);
        bitPos++;
    }
    return value;
}

void TSDemuxer::parseSPS(const uint8_t* data, int len) {
    if (len < 4) return;
    int bitPos = 0;
    readBits(data, bitPos, 8);
    int profileIdc = readBits(data, bitPos, 8);
    readBits(data, bitPos, 8);
    int levelIdc = readBits(data, bitPos, 8);
    videoInfo_.codecName = "h264";
    LOGI("SPS: profile=%d, level=%d", profileIdc, levelIdc);
}

void TSDemuxer::parseTSPacket(const uint8_t* packet) {
    if (packet[0] != TS_SYNC_BYTE) return;

    int pid = ((packet[1] & 0x1F) << 8) | packet[2];
    int adaptCtrl = (packet[3] >> 4) & 0x03;
    int payloadOffset = 4;

    if (adaptCtrl == 2) return;
    if (adaptCtrl == 3) {
        int adaptLen = packet[4];
        payloadOffset = 5 + adaptLen;
        if (payloadOffset >= TS_PACKET_SIZE) return;
    }

    const uint8_t* payload = packet + payloadOffset;
    int payloadLen = TS_PACKET_SIZE - payloadOffset;

    if (pid == 0) {
        parsePAT(payload, payloadLen);
    } else if (pid == pmtPid_) {
        parsePMT(payload, payloadLen);
    } else if (pid == videoPid_ || pid == audioPid_) {
        bool payloadStart = (packet[1] & 0x40) != 0;
        parsePES(pid, payload, payloadLen, payloadStart);
    }
}

void TSDemuxer::parsePAT(const uint8_t* payload, int len) {
    if (len < 8) return;
    int tableId = payload[0];
    if (tableId != 0x00) return;
    int sectionLen = ((payload[1] & 0x0F) << 8) | payload[2];
    int count = (sectionLen - 9) / 4;
    for (int i = 0; i < count && (8 + i * 4 + 4) <= len; i++) {
        int offset = 8 + i * 4;
        int progNum = (payload[offset] << 8) | payload[offset + 1];
        int pid = ((payload[offset + 2] & 0x1F) << 8) | payload[offset + 3];
        if (progNum != 0) {
            pmtPid_ = pid;
            LOGI("PAT: PMT PID=%d", pmtPid_);
            return;
        }
    }
}

void TSDemuxer::parsePMT(const uint8_t* payload, int len) {
    if (len < 12) return;
    int tableId = payload[0];
    if (tableId != 0x02) return;
    int sectionLen = ((payload[1] & 0x0F) << 8) | payload[2];
    int pcrPid = ((payload[8] & 0x1F) << 8) | payload[9];
    int infoLen = ((payload[10] & 0x0F) << 8) | payload[11];
    int offset = 12 + infoLen;
    int end = 3 + sectionLen - 4;

    while (offset + 5 <= end && offset + 5 <= len) {
        int streamType = payload[offset];
        int elemPid = ((payload[offset + 1] & 0x1F) << 8) | payload[offset + 2];
        int esInfoLen = ((payload[offset + 3] & 0x0F) << 8) | payload[offset + 4];

        if (streamType == 0x1B || streamType == 0x24) {
            videoPid_ = elemPid;
            videoStreamType_ = streamType;
            hasVideo_ = true;
            videoInfo_.codecName = (streamType == 0x1B) ? "h264" : "h265";
            videoInfo_.codecId = streamType;
            LOGI("PMT: Video PID=%d type=0x%02X (%s)", elemPid, streamType, videoInfo_.codecName.c_str());
        } else if (streamType == 0x0F || streamType == 0x81) {
            audioPid_ = elemPid;
            audioStreamType_ = streamType;
            hasAudio_ = true;
            audioInfo_.codecName = (streamType == 0x0F) ? "aac" : "ac3";
            audioInfo_.codecId = streamType;
            audioInfo_.sampleRate = 48000;
            audioInfo_.channels = 2;
            audioInfo_.bitsPerSample = 16;
            LOGI("PMT: Audio PID=%d type=0x%02X (%s)", elemPid, streamType, audioInfo_.codecName.c_str());
        }
        offset += 5 + esInfoLen;
    }
}

void TSDemuxer::parsePES(int pid, const uint8_t* payload, int len, bool payloadStart) {
    if (payloadStart) {
        if (pesBuffers_.count(pid) && !pesBuffers_[pid].empty()) {
            emitPacket(pid, pesBuffers_[pid], true);
        }
        pesBuffers_[pid].clear();
        pesStartFlags_[pid] = true;

        if (len >= 9) {
            int headerLen = payload[8];
            int dataStart = 9 + headerLen;
            if (dataStart < len) {
                pesBuffers_[pid].insert(pesBuffers_[pid].end(),
                    payload + dataStart, payload + len);
            }
        }
    } else {
        pesBuffers_[pid].insert(pesBuffers_[pid].end(), payload, payload + len);
    }

    if (pesBuffers_[pid].size() > MAX_PES_PAYLOAD) {
        pesBuffers_[pid].clear();
    }
}

void TSDemuxer::emitPacket(int pid, const std::vector<uint8_t>& data, bool isStart) {
    std::lock_guard<std::mutex> lock(mutex_);
    AVPacket pkt;
    pkt.data = data;
    pkt.pts = 0;
    pkt.dts = 0;

    if (pid == videoPid_ && !data.empty()) {
        pkt.type = MediaType::VIDEO;
        pkt.isKeyFrame = (data.size() > 4 &&
            (data[4] & 0x1F) == 5);
        pendingResult_.videoPackets.push_back(std::move(pkt));
        pendingResult_.hasVideo = true;
        if (videoInfo_.width == 0 && data.size() > 5) {
            for (size_t i = 0; i + 4 < data.size(); i++) {
                if (data[i] == 0 && data[i+1] == 0 && data[i+2] == 0 && data[i+3] == 1) {
                    int naluType = data[i+4] & 0x1F;
                    if (naluType == 7) {
                        parseSPS(data.data() + i + 4, (int)(data.size() - i - 4));
                        break;
                    }
                }
            }
        }
    } else if (pid == audioPid_ && !data.empty()) {
        pkt.type = MediaType::AUDIO;
        pkt.isKeyFrame = true;
        pendingResult_.audioPackets.push_back(std::move(pkt));
        pendingResult_.hasAudio = true;
    }
}

bool TSDemuxer::readPackets(DemuxResult& result) {
    size_t offset = 0;
    while (offset + TS_PACKET_SIZE <= buffer_.size()) {
        int syncPos = -1;
        for (size_t i = offset; i < buffer_.size(); i++) {
            if (buffer_[i] == TS_SYNC_BYTE) {
                syncPos = (int)i;
                break;
            }
        }
        if (syncPos < 0) {
            buffer_.clear();
            break;
        }
        if (syncPos > 0) {
            buffer_.erase(buffer_.begin(), buffer_.begin() + syncPos);
        }
        if (buffer_.size() < TS_PACKET_SIZE) break;

        parseTSPacket(buffer_.data());
        buffer_.erase(buffer_.begin(), buffer_.begin() + TS_PACKET_SIZE);
    }

    std::lock_guard<std::mutex> lock(mutex_);
    result = std::move(pendingResult_);
    pendingResult_ = DemuxResult();
    return result.hasVideo || result.hasAudio;
}
