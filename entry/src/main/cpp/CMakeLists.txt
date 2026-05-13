cmake_minimum_required(VERSION 3.16)
project(embyplayer)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src)
set(INC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/include)

add_library(embyplayer SHARED
    ${SRC_DIR}/ts_demuxer.cpp
    ${SRC_DIR}/hw_video_decoder.cpp
    ${SRC_DIR}/audio_pipeline.cpp
    ${SRC_DIR}/player_engine.cpp
    ${SRC_DIR}/napi_init.cpp
)

target_include_directories(embyplayer PRIVATE
    ${INC_DIR}
)

target_link_libraries(embyplayer PUBLIC
    libace_napi.z.so
    libace_ndk.z.so
    libhilog_ndk.z.so
    libnative_window_manager.so
    libohaudio.so
    libOpenSLES.so
    libnative_media_vdec.so
    libnative_media_core.so
    libnative_media_codecbase.so
    libnative_drawing.so
    libnative_window.so
)
