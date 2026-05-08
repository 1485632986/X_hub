/**
 * Emby API Data Models
 */

/** Login request body */
export interface LoginRequest {
  Username: string;
  Pw: string;
}

/** Login response from /Users/AuthenticateByName */
export interface LoginResponse {
  User: EmbyUser;
  AccessToken: string;
  ServerId: string;
}

/** Emby user info */
export interface EmbyUser {
  Id: string;
  Name: string;
  HasPassword: boolean;
  PrimaryImageTag?: string;
}

/** Emby API error response */
export interface EmbyError {
  error_code?: number;
  message?: string;
}

/** Response from /Users/{userId}/Items */
export interface ItemsResponse {
  Items: MediaItem[];
  TotalRecordCount: number;
  StartIndex: number;
}

/** A single media item */
export interface MediaItem {
  Id: string;
  Name: string;
  Type: string;           // "Movie", "Series", "Episode", "Video"
  MediaType: string;      // "Video", "Audio"
  IsFolder: boolean;
  Overview?: string;
  PremiereDate?: string;
  ProductionYear?: number;
  RunTimeTicks?: number;
  OfficialRating?: string;
  CommunityRating?: number;
  ImageTags?: {
    Primary?: string;
    Logo?: string;
    Thumb?: string;
  };
  BackdropImageTags?: string[];
  SeriesName?: string;
  SeasonName?: string;
  IndexNumber?: number;   // Episode number
  ParentIndexNumber?: number; // Season number
  MediaSources?: MediaSource[];
}

/**
 * Media source info from Emby — describes a playable version of a media item.
 * Contains codec info, bitrate, resolution, and available streams.
 */
export interface MediaSource {
  Id: string;                          // MediaSourceId — used for stream URL construction
  Name: string;                        // Display name (e.g. "DirectPlay")
  Path: string;                        // Server-side file path
  Container: string;                   // File container (e.g. "mkv", "mp4", "ts")
  Size: number;                        // File size in bytes
  Bitrate: number;                     // Overall bitrate in bps
  MediaStreams: MediaStream[];         // All streams (video, audio, subtitle)
  TranscodingUrl?: string;             // URL for transcoded stream (if available)
  TranscodingContainer?: string;       // Transcode target container
  TranscodingSubProtocol?: string;     // "hls" or "http"
  IsRemote: boolean;                   // Whether source is remote
  SupportsDirectPlay: boolean;         // Can this source be direct-played?
  SupportsDirectStream: boolean;       // Can this source be direct-streamed?
  SupportsTranscoding: boolean;        // Can this source be transcoded?
  VideoType?: string;                  // "VideoFile", "BluRay", "Dvd", etc.
}

/**
 * A single stream within a media source (video, audio, or subtitle track).
 */
export interface MediaStream {
  Type: string;                        // "Video", "Audio", "Subtitle"
  Index: number;                       // Stream index
  Codec: string;                       // Codec name (e.g. "hevc", "aac", "srt")
  Language?: string;                   // Language (e.g. "eng", "chi")
  Title?: string;                      // Display title
  DisplayTitle?: string;               // Formatted display title
  IsDefault: boolean;                  // Is this the default stream?
  IsExternal: boolean;                 // Is this an external stream?

  // Video-specific fields
  VideoCodec?: string;                 // Video codec (e.g. "h264", "hevc")
  Width?: number;                      // Video width in pixels
  Height?: number;                     // Video height in pixels
  BitRate?: number;                    // Stream bitrate
  FrameRate?: number;                  // Frame rate (e.g. 23.976, 29.97, 60)
  VideoRange?: string;                 // "SDR", "HDR", "HDR10", "HLG", "DOVI"
  VideoRangeType?: string;             // "SDR", "HDR10", "HLG", "DOVI"
  Profile?: string;                    // Codec profile (e.g. "Main 10", "High")
  Level?: number;                      // Codec level
  AspectRatio?: string;                // Display aspect ratio (e.g. "16:9")
  IsAVC?: boolean;                     // Is H.264 AVC
  IsAnamorphic?: boolean;              // Is anamorphic video
  BitDepth?: number;                   // Color bit depth (8, 10, 12)

  // Audio-specific fields
  AudioCodec?: string;                 // Audio codec (e.g. "aac", "ac3", "dts")
  ChannelLayout?: string;              // Channel layout (e.g. "stereo", "5.1", "7.1")
  Channels?: number;                   // Number of audio channels
  SampleRate?: number;                 // Sample rate in Hz

  // Subtitle-specific fields
  SubtitleCodec?: string;              // Subtitle codec (e.g. "srt", "ass")
}

/**
 * Stored session info for persistence
 */
export interface SessionInfo {
  serverUrl: string;
  accessToken: string;
  userId: string;
  userName: string;
}
