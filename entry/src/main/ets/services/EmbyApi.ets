import { http } from '@kit.NetworkKit';
import { HttpClient } from './HttpClient';
import {
  LoginRequest,
  LoginResponse,
  ItemsResponse,
  MediaItem,
  MediaSource,
  SessionInfo
} from '../models/EmbyTypes';

/**
 * Device ID generated once and reused (in-memory for simplicity)
 */
let deviceId: string = 'harmonyos-' + Date.now().toString(36) + Math.random().toString(36).substring(2, 8);

/**
 * Build the X-Emby-Authorization header value
 */
function buildAuthHeader(token?: string): string {
  let auth = 'MediaBrowser Client="EmbyHarmonyOS", Device="HarmonyOS", DeviceId="' +
    deviceId + '", Version="1.0.0"';
  if (token) {
    auth += ', Token="' + token + '"';
  }
  return auth;
}

/**
 * Emby API Service
 */
export class EmbyApi {
  /**
   * Authenticate with Emby server using username and password.
   * Returns session info including accessToken and userId.
   *
   * @param serverUrl - Base URL, e.g. "http://192.168.1.100:8096"
   * @param username  - Emby username
   * @param password  - Emby password
   */
  static async login(
    serverUrl: string,
    username: string,
    password: string
  ): Promise<SessionInfo> {
    // Normalize server URL (remove trailing slash)
    const baseUrl = serverUrl.replace(/\/+$/, '');
    const url = `${baseUrl}/Users/AuthenticateByName`;

    const header: Record<string, string> = {
      'X-Emby-Authorization': buildAuthHeader(),
      'Content-Type': 'application/json'
    };

    const body: LoginRequest = {
      Username: username,
      Pw: password
    };

    const response = await HttpClient.post(url, body, header);

    if (response.statusCode !== 200) {
      let errorMsg = `HTTP ${response.statusCode}`;
      try {
        const errObj = JSON.parse(response.data);
        errorMsg = errObj.message || errObj.ErrorMessage || errorMsg;
      } catch (_e) {
        // ignore parse error
      }
      throw new Error(errorMsg);
    }

    const result: LoginResponse = JSON.parse(response.data);

    return {
      serverUrl: baseUrl,
      accessToken: result.AccessToken,
      userId: result.User.Id,
      userName: result.User.Name
    };
  }

  /**
   * Fetch video items for the authenticated user.
   * Includes MediaSources info for codec-aware stream selection.
   *
   * @param session - Active session info
   * @param startIndex - Pagination offset
   * @param limit - Max items to return
   */
  static async getVideoItems(
    session: SessionInfo,
    startIndex: number = 0,
    limit: number = 50
  ): Promise<ItemsResponse> {
    const url = `${session.serverUrl}/Users/${session.userId}/Items?` +
      `IncludeItemTypes=Movie,Video&` +
      `Recursive=true&` +
      `Filters=IsNotFolder&` +
      `Fields=Overview,PrimaryImageTag,CommunityRating,RunTimeTicks,PremiereDate,ProductionYear,MediaSources&` +
      `SortBy=SortName&` +
      `SortOrder=Ascending&` +
      `StartIndex=${startIndex}&` +
      `Limit=${limit}`;

    const header: Record<string, string> = {
      'X-Emby-Token': session.accessToken
    };

    const response = await HttpClient.get(url, header);

    if (response.statusCode !== 200) {
      throw new Error(`Failed to fetch items: HTTP ${response.statusCode}`);
    }

    return JSON.parse(response.data) as ItemsResponse;
  }

  /**
   * Fetch a single item with full MediaSource details.
   * Use this to get complete MediaStreams info for playback.
   *
   * @param session - Active session info
   * @param itemId  - Media item ID
   */
  static async getItemDetail(
    session: SessionInfo,
    itemId: string
  ): Promise<MediaItem> {
    const url = `${session.serverUrl}/Items/${itemId}?` +
      `Fields=Overview,MediaSources,MediaStreams,Chapters,Path`;

    const header: Record<string, string> = {
      'X-Emby-Token': session.accessToken
    };

    const response = await HttpClient.get(url, header);

    if (response.statusCode !== 200) {
      throw new Error(`Failed to fetch item detail: HTTP ${response.statusCode}`);
    }

    return JSON.parse(response.data) as MediaItem;
  }

  /**
   * Build a direct play stream URL for a video item.
   * Uses static=true for direct streaming (no server-side transcoding).
   *
   * @param session       - Active session info
   * @param itemId        - Media item ID
   * @param mediaSourceId - (Optional) Specific MediaSource ID to play
   */
  static getStreamUrl(session: SessionInfo, itemId: string, mediaSourceId?: string): string {
    let url = `${session.serverUrl}/Videos/${itemId}/stream?static=true&api_key=${session.accessToken}`;
    if (mediaSourceId) {
      url += `&MediaSourceId=${mediaSourceId}`;
    }
    return url;
  }

  /**
   * Build a transcoded stream URL (HLS/M3U8) for a video item.
   * Use this as fallback when direct play fails or codec is unsupported.
   *
   * @param session       - Active session info
   * @param itemId        - Media item ID
   * @param mediaSourceId - MediaSource ID
   * @param videoCodec    - Target video codec (e.g. "h264", "h265")
   * @param audioCodec    - Target audio codec (e.g. "aac", "ac3")
   * @param maxWidth      - Max video width
   */
  static getTranscodeStreamUrl(
    session: SessionInfo,
    itemId: string,
    mediaSourceId: string,
    videoCodec: string = 'h264',
    audioCodec: string = 'aac',
    maxWidth: number = 1920
  ): string {
    return `${session.serverUrl}/Videos/${itemId}/master.m3u8?` +
      `api_key=${session.accessToken}` +
      `&MediaSourceId=${mediaSourceId}` +
      `&VideoCodec=${videoCodec}` +
      `&AudioCodec=${audioCodec}` +
      `&MaxWidth=${maxWidth}` +
      `&VideoBitrate=8000000` +
      `&AudioBitrate=192000` +
      `&TranscodingMaxAudioChannels=6`;
  }

  /**
   * Build the image URL for a media item's primary image.
   *
   * @param session - Active session info
   * @param itemId  - Media item ID
   * @param tag     - Image tag (from ImageTags.Primary)
   * @param maxWidth - Max image width
   */
  static getImageUrl(session: SessionInfo, itemId: string, tag: string, maxWidth: number = 200): string {
    return `${session.serverUrl}/Items/${itemId}/Images/Primary?` +
      `maxWidth=${maxWidth}&tag=${tag}&quality=90`;
  }

  /**
   * Extract the primary video stream info from a MediaSource.
   *
   * @param mediaSource - The media source to inspect
   * @returns The primary video MediaStream, or undefined
   */
  static getVideoStream(mediaSource: MediaSource): import('../models/EmbyTypes').MediaStream | undefined {
    return mediaSource.MediaStreams?.find(s => s.Type === 'Video');
  }

  /**
   * Extract audio streams from a MediaSource.
   *
   * @param mediaSource - The media source to inspect
   * @returns Array of audio MediaStreams
   */
  static getAudioStreams(mediaSource: MediaSource): import('../models/EmbyTypes').MediaStream[] {
    return mediaSource.MediaStreams?.filter(s => s.Type === 'Audio') || [];
  }

  /**
   * Extract subtitle streams from a MediaSource.
   *
   * @param mediaSource - The media source to inspect
   * @returns Array of subtitle MediaStreams
   */
  static getSubtitleStreams(mediaSource: MediaSource): import('../models/EmbyTypes').MediaStream[] {
    return mediaSource.MediaStreams?.filter(s => s.Type === 'Subtitle') || [];
  }
}
