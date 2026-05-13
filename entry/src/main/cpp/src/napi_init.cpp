#include <napi/native_api.h>
#include <hilog/log.h>
#include "emby_player.h"
#include <memory>
#include <map>

static std::map<int, std::shared_ptr<PlayerEngine>> g_engines;
static int g_engineId = 0;
static napi_env g_env = nullptr;

static napi_value CreateEngine(napi_env env, napi_callback_info info) {
    auto engine = std::make_shared<PlayerEngine>();
    int id = ++g_engineId;
    g_engines[id] = engine;
    g_env = env;

    napi_value result;
    napi_create_int32(env, id, &result);
    return result;
}

static napi_value SetDataSource(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int engineId = 0;
    napi_get_value_int32(env, args[0], &engineId);

    char urlBuf[2048];
    size_t urlLen = 0;
    napi_get_value_string_utf8(env, args[1], urlBuf, sizeof(urlBuf), &urlLen);

    auto it = g_engines.find(engineId);
    if (it != g_engines.end()) {
        it->second->setDataSource(std::string(urlBuf, urlLen));
    }

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

static napi_value SetSurface(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int engineId = 0;
    napi_get_value_int32(env, args[0], &engineId);

    int64_t surfaceId = 0;
    napi_get_value_int64(env, args[1], &surfaceId);

    auto it = g_engines.find(engineId);
    if (it != g_engines.end()) {
        it->second->setSurface(static_cast<uint64_t>(surfaceId));
    }

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

static napi_value Prepare(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int engineId = 0;
    napi_get_value_int32(env, args[0], &engineId);

    bool success = false;
    auto it = g_engines.find(engineId);
    if (it != g_engines.end()) {
        it->second->setOnStateChange([env](const std::string& state) {
            LOGI("State: %s", state.c_str());
        });
        it->second->setOnError([env](int code, const std::string& msg) {
            LOGE("Error %d: %s", code, msg.c_str());
        });
        success = it->second->prepare();
    }

    napi_value result;
    napi_get_boolean(env, success, &result);
    return result;
}

static napi_value Start(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int engineId = 0;
    napi_get_value_int32(env, args[0], &engineId);

    bool success = false;
    auto it = g_engines.find(engineId);
    if (it != g_engines.end()) {
        success = it->second->start();
    }

    napi_value result;
    napi_get_boolean(env, success, &result);
    return result;
}

static napi_value Pause(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int engineId = 0;
    napi_get_value_int32(env, args[0], &engineId);

    auto it = g_engines.find(engineId);
    if (it != g_engines.end()) {
        it->second->pause();
    }

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

static napi_value Resume(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int engineId = 0;
    napi_get_value_int32(env, args[0], &engineId);

    auto it = g_engines.find(engineId);
    if (it != g_engines.end()) {
        it->second->resume();
    }

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

static napi_value ReleaseEngine(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int engineId = 0;
    napi_get_value_int32(env, args[0], &engineId);

    g_engines.erase(engineId);

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

static napi_value FeedData(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int engineId = 0;
    napi_get_value_int32(env, args[0], &engineId);

    uint8_t* data = nullptr;
    size_t dataLen = 0;
    napi_get_arraybuffer_info(env, args[1], (void**)&data, &dataLen);

    auto it = g_engines.find(engineId);
    if (it != g_engines.end() && data && dataLen > 0) {
        it->second->feedData(data, dataLen);
    }

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"createEngine", nullptr, CreateEngine, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setDataSource", nullptr, SetDataSource, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setSurface", nullptr, SetSurface, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"prepare", nullptr, Prepare, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"start", nullptr, Start, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"pause", nullptr, Pause, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"resume", nullptr, Resume, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"release", nullptr, ReleaseEngine, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"feedData", nullptr, FeedData, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}

EXTERN_C_START
static napi_module g_module = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "embyplayer",
    .nm_priv = nullptr,
    .reserved = {0},
};

__attribute__((constructor)) void RegisterModule(void) {
    napi_module_register(&g_module);
}
EXTERN_C_END
