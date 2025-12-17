//
//  static_cores.h
//  YearnCore
//
//  Header file declaring all statically linked libretro core functions
//  Each core exports functions with a unique prefix to avoid symbol conflicts
//
//  These declarations match the prefixed symbols created by build_prefixed_static_cores.sh
//

#ifndef static_cores_h
#define static_cores_h

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include "libretro.h"

#ifdef __cplusplus
extern "C" {
#endif

// =============================================================================
// MARK: - Macro to declare all libretro functions for a core
// =============================================================================

#define DECLARE_LIBRETRO_CORE(PREFIX) \
    void PREFIX##_retro_init(void); \
    void PREFIX##_retro_deinit(void); \
    unsigned PREFIX##_retro_api_version(void); \
    void PREFIX##_retro_get_system_info(struct retro_system_info *info); \
    void PREFIX##_retro_get_system_av_info(struct retro_system_av_info *info); \
    void PREFIX##_retro_set_environment(retro_environment_t); \
    void PREFIX##_retro_set_video_refresh(retro_video_refresh_t); \
    void PREFIX##_retro_set_audio_sample(retro_audio_sample_t); \
    void PREFIX##_retro_set_audio_sample_batch(retro_audio_sample_batch_t); \
    void PREFIX##_retro_set_input_poll(retro_input_poll_t); \
    void PREFIX##_retro_set_input_state(retro_input_state_t); \
    void PREFIX##_retro_reset(void); \
    void PREFIX##_retro_run(void); \
    bool PREFIX##_retro_load_game(const struct retro_game_info *game); \
    bool PREFIX##_retro_load_game_special(unsigned game_type, const struct retro_game_info *info, size_t num_info); \
    void PREFIX##_retro_unload_game(void); \
    size_t PREFIX##_retro_serialize_size(void); \
    bool PREFIX##_retro_serialize(void *data, size_t size); \
    bool PREFIX##_retro_unserialize(const void *data, size_t size); \
    void *PREFIX##_retro_get_memory_data(unsigned id); \
    size_t PREFIX##_retro_get_memory_size(unsigned id); \
    unsigned PREFIX##_retro_get_region(void); \
    void PREFIX##_retro_cheat_reset(void); \
    void PREFIX##_retro_cheat_set(unsigned index, bool enabled, const char *code); \
    void PREFIX##_retro_set_controller_port_device(unsigned port, unsigned device);

// =============================================================================
// MARK: - Core Declarations
// =============================================================================

// FCEUmm (NES)
DECLARE_LIBRETRO_CORE(fceumm)

// Gambatte (GB/GBC)
DECLARE_LIBRETRO_CORE(gambatte)

// mGBA (GBA)
DECLARE_LIBRETRO_CORE(mgba)

// ClownMDEmu (Genesis/Mega Drive) - AGPL v3 许可证
DECLARE_LIBRETRO_CORE(clownmdemu)

// melonDS (NDS)
DECLARE_LIBRETRO_CORE(melonds)

// Mupen64Plus-Next (N64)
DECLARE_LIBRETRO_CORE(mupen64plus_next)

// PCSX ReARMed (PS1)
DECLARE_LIBRETRO_CORE(pcsx_rearmed)

// bsnes (SNES) - GPL v3 许可证
// 高精度 SNES 模拟器，可替代 Snes9x
DECLARE_LIBRETRO_CORE(bsnes)

#ifdef __cplusplus
}
#endif

#endif /* static_cores_h */

