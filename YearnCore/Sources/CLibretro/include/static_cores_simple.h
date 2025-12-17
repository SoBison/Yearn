//
//  static_cores_simple.h
//  YearnCore
//
//  Header file declaring standard libretro functions for a single statically linked core
//  This version does NOT use symbol prefixes - only one core can be linked at a time
//

#ifndef static_cores_simple_h
#define static_cores_simple_h

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include "libretro.h"

#ifdef __cplusplus
extern "C" {
#endif

// =============================================================================
// MARK: - Standard libretro API functions
// =============================================================================

// These are the standard libretro functions exported by any core
// When linking a single static core, these symbols will be resolved

void retro_init(void);
void retro_deinit(void);
unsigned retro_api_version(void);
void retro_get_system_info(struct retro_system_info *info);
void retro_get_system_av_info(struct retro_system_av_info *info);
void retro_set_environment(retro_environment_t);
void retro_set_video_refresh(retro_video_refresh_t);
void retro_set_audio_sample(retro_audio_sample_t);
void retro_set_audio_sample_batch(retro_audio_sample_batch_t);
void retro_set_input_poll(retro_input_poll_t);
void retro_set_input_state(retro_input_state_t);
void retro_reset(void);
void retro_run(void);
bool retro_load_game(const struct retro_game_info *game);
bool retro_load_game_special(unsigned game_type, const struct retro_game_info *info, size_t num_info);
void retro_unload_game(void);
size_t retro_serialize_size(void);
bool retro_serialize(void *data, size_t size);
bool retro_unserialize(const void *data, size_t size);
void *retro_get_memory_data(unsigned id);
size_t retro_get_memory_size(unsigned id);
unsigned retro_get_region(void);
void retro_cheat_reset(void);
void retro_cheat_set(unsigned index, bool enabled, const char *code);
void retro_set_controller_port_device(unsigned port, unsigned device);

#ifdef __cplusplus
}
#endif

#endif /* static_cores_simple_h */

