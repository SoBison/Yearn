//
//  StaticCoreRegistration.swift
//  YearnCore
//
//  注册静态链接的 libretro 核心
//  支持多核心系统，每个核心使用唯一的符号前缀避免冲突
//

import Foundation
import CLibretro

// MARK: - 核心注册

/// 注册所有可用的静态核心
/// 在应用启动时调用此函数
public func registerAllStaticCores() {
    print("📦 YearnCore: 正在注册核心...")
    
    // 首先尝试加载所有可用的动态 Framework 核心
    // 动态核心来自 RetroArch 等成熟项目，稳定性更好
    let dynamicCount = StaticCoreRegistry.shared.tryLoadAllDynamicCores()
    if dynamicCount > 0 {
        print("📦 YearnCore: 已加载 \(dynamicCount) 个动态 Framework 核心")
    }
    
    #if STATIC_CORES_ENABLED
    // 对于没有动态核心的系统，使用静态链接的核心作为后备
    print("📦 YearnCore: 正在注册静态核心（作为后备）...")
    
    // 检查并注册缺失的核心
    let registry = StaticCoreRegistry.shared
    
    // GB/GBC - 检查是否已有动态核心
    if registry.getCore(forExtension: "gb") == nil {
        registerGambatteCore()
    }
    
    // GBA
    if registry.getCore(forExtension: "gba") == nil {
        registerMGBACore()
    }
    
    // NES
    if registry.getCore(forExtension: "nes") == nil {
        registerFCEUmmCore()
    }
    
    // SNES - 优先使用 bsnes (GPL v3)，如果失败则使用 Snes9x (非商业)
    if registry.getCore(forExtension: "sfc") == nil {
        registerBsnesCore()
    }
    
    // Genesis/Mega Drive - 使用 ClownMDEmu (AGPL v3)
    if registry.getCore(forExtension: "md") == nil {
        registerClownMDEmuCore()
    }
    
    // NDS
    if registry.getCore(forExtension: "nds") == nil {
        registerMelonDSCore()
    }
    
    // N64
    if registry.getCore(forExtension: "n64") == nil {
        registerMupen64PlusCore()
    }
    
    // PS1 - 如果动态核心加载失败，使用静态核心
    if registry.getCore(forExtension: "cue") == nil {
        registerPCSXReARMedCore()
    }
    #endif
    
    print("📦 YearnCore: 已注册 \(StaticCoreRegistry.shared.allCores.count) 个核心")
}

// MARK: - Gambatte (GB/GBC)

private func registerGambatteCore() {
    let interface = LibretroCoreInterface(
        retro_init: gambatte_retro_init,
        retro_deinit: gambatte_retro_deinit,
        retro_api_version: gambatte_retro_api_version,
        retro_get_system_info: gambatte_retro_get_system_info,
        retro_get_system_av_info: gambatte_retro_get_system_av_info,
        retro_set_environment: gambatte_retro_set_environment,
        retro_set_video_refresh: gambatte_retro_set_video_refresh,
        retro_set_audio_sample: gambatte_retro_set_audio_sample,
        retro_set_audio_sample_batch: gambatte_retro_set_audio_sample_batch,
        retro_set_input_poll: gambatte_retro_set_input_poll,
        retro_set_input_state: gambatte_retro_set_input_state,
        retro_reset: gambatte_retro_reset,
        retro_run: gambatte_retro_run,
        retro_load_game: gambatte_retro_load_game,
        retro_unload_game: gambatte_retro_unload_game,
        retro_serialize_size: gambatte_retro_serialize_size,
        retro_serialize: gambatte_retro_serialize,
        retro_unserialize: gambatte_retro_unserialize,
        retro_get_memory_data: gambatte_retro_get_memory_data,
        retro_get_memory_size: gambatte_retro_get_memory_size,
        retro_cheat_reset: gambatte_retro_cheat_reset,
        retro_cheat_set: gambatte_retro_cheat_set
    )
    
    let core = StaticCoreInfo(
        identifier: "gambatte",
        name: "Gambatte",
        systemName: "GBC",
        supportedExtensions: ["gb", "gbc", "sgb"],
        coreInterface: interface
    )
    
    StaticCoreRegistry.shared.register(core)
}

// MARK: - mGBA (GBA)

private func registerMGBACore() {
    let interface = LibretroCoreInterface(
        retro_init: mgba_retro_init,
        retro_deinit: mgba_retro_deinit,
        retro_api_version: mgba_retro_api_version,
        retro_get_system_info: mgba_retro_get_system_info,
        retro_get_system_av_info: mgba_retro_get_system_av_info,
        retro_set_environment: mgba_retro_set_environment,
        retro_set_video_refresh: mgba_retro_set_video_refresh,
        retro_set_audio_sample: mgba_retro_set_audio_sample,
        retro_set_audio_sample_batch: mgba_retro_set_audio_sample_batch,
        retro_set_input_poll: mgba_retro_set_input_poll,
        retro_set_input_state: mgba_retro_set_input_state,
        retro_reset: mgba_retro_reset,
        retro_run: mgba_retro_run,
        retro_load_game: mgba_retro_load_game,
        retro_unload_game: mgba_retro_unload_game,
        retro_serialize_size: mgba_retro_serialize_size,
        retro_serialize: mgba_retro_serialize,
        retro_unserialize: mgba_retro_unserialize,
        retro_get_memory_data: mgba_retro_get_memory_data,
        retro_get_memory_size: mgba_retro_get_memory_size,
        retro_cheat_reset: mgba_retro_cheat_reset,
        retro_cheat_set: mgba_retro_cheat_set
    )
    
    let core = StaticCoreInfo(
        identifier: "mgba",
        name: "mGBA",
        systemName: "GBA",
        supportedExtensions: ["gba", "agb"],
        coreInterface: interface
    )
    
    StaticCoreRegistry.shared.register(core)
}

// MARK: - FCEUmm (NES)

private func registerFCEUmmCore() {
    let interface = LibretroCoreInterface(
        retro_init: fceumm_retro_init,
        retro_deinit: fceumm_retro_deinit,
        retro_api_version: fceumm_retro_api_version,
        retro_get_system_info: fceumm_retro_get_system_info,
        retro_get_system_av_info: fceumm_retro_get_system_av_info,
        retro_set_environment: fceumm_retro_set_environment,
        retro_set_video_refresh: fceumm_retro_set_video_refresh,
        retro_set_audio_sample: fceumm_retro_set_audio_sample,
        retro_set_audio_sample_batch: fceumm_retro_set_audio_sample_batch,
        retro_set_input_poll: fceumm_retro_set_input_poll,
        retro_set_input_state: fceumm_retro_set_input_state,
        retro_reset: fceumm_retro_reset,
        retro_run: fceumm_retro_run,
        retro_load_game: fceumm_retro_load_game,
        retro_unload_game: fceumm_retro_unload_game,
        retro_serialize_size: fceumm_retro_serialize_size,
        retro_serialize: fceumm_retro_serialize,
        retro_unserialize: fceumm_retro_unserialize,
        retro_get_memory_data: fceumm_retro_get_memory_data,
        retro_get_memory_size: fceumm_retro_get_memory_size,
        retro_cheat_reset: fceumm_retro_cheat_reset,
        retro_cheat_set: fceumm_retro_cheat_set
    )
    
    let core = StaticCoreInfo(
        identifier: "fceumm",
        name: "FCEUmm",
        systemName: "NES",
        supportedExtensions: ["nes", "fds", "unf", "unif"],
        coreInterface: interface
    )
    
    StaticCoreRegistry.shared.register(core)
}

// MARK: - bsnes (SNES) - GPL v3 许可证
// 高精度 SNES 模拟器，可商业使用（需开源）

private func registerBsnesCore() {
    let interface = LibretroCoreInterface(
        retro_init: bsnes_retro_init,
        retro_deinit: bsnes_retro_deinit,
        retro_api_version: bsnes_retro_api_version,
        retro_get_system_info: bsnes_retro_get_system_info,
        retro_get_system_av_info: bsnes_retro_get_system_av_info,
        retro_set_environment: bsnes_retro_set_environment,
        retro_set_video_refresh: bsnes_retro_set_video_refresh,
        retro_set_audio_sample: bsnes_retro_set_audio_sample,
        retro_set_audio_sample_batch: bsnes_retro_set_audio_sample_batch,
        retro_set_input_poll: bsnes_retro_set_input_poll,
        retro_set_input_state: bsnes_retro_set_input_state,
        retro_reset: bsnes_retro_reset,
        retro_run: bsnes_retro_run,
        retro_load_game: bsnes_retro_load_game,
        retro_unload_game: bsnes_retro_unload_game,
        retro_serialize_size: bsnes_retro_serialize_size,
        retro_serialize: bsnes_retro_serialize,
        retro_unserialize: bsnes_retro_unserialize,
        retro_get_memory_data: bsnes_retro_get_memory_data,
        retro_get_memory_size: bsnes_retro_get_memory_size,
        retro_cheat_reset: bsnes_retro_cheat_reset,
        retro_cheat_set: bsnes_retro_cheat_set
    )
    
    let core = StaticCoreInfo(
        identifier: "bsnes",
        name: "bsnes",
        systemName: "SNES",
        supportedExtensions: ["sfc", "smc", "fig", "swc", "bs"],
        coreInterface: interface
    )
    
    StaticCoreRegistry.shared.register(core)
}

// MARK: - ClownMDEmu (Genesis/Mega Drive) - AGPL v3 许可证

private func registerClownMDEmuCore() {
    let interface = LibretroCoreInterface(
        retro_init: clownmdemu_retro_init,
        retro_deinit: clownmdemu_retro_deinit,
        retro_api_version: clownmdemu_retro_api_version,
        retro_get_system_info: clownmdemu_retro_get_system_info,
        retro_get_system_av_info: clownmdemu_retro_get_system_av_info,
        retro_set_environment: clownmdemu_retro_set_environment,
        retro_set_video_refresh: clownmdemu_retro_set_video_refresh,
        retro_set_audio_sample: clownmdemu_retro_set_audio_sample,
        retro_set_audio_sample_batch: clownmdemu_retro_set_audio_sample_batch,
        retro_set_input_poll: clownmdemu_retro_set_input_poll,
        retro_set_input_state: clownmdemu_retro_set_input_state,
        retro_reset: clownmdemu_retro_reset,
        retro_run: clownmdemu_retro_run,
        retro_load_game: clownmdemu_retro_load_game,
        retro_unload_game: clownmdemu_retro_unload_game,
        retro_serialize_size: clownmdemu_retro_serialize_size,
        retro_serialize: clownmdemu_retro_serialize,
        retro_unserialize: clownmdemu_retro_unserialize,
        retro_get_memory_data: clownmdemu_retro_get_memory_data,
        retro_get_memory_size: clownmdemu_retro_get_memory_size,
        retro_cheat_reset: clownmdemu_retro_cheat_reset,
        retro_cheat_set: clownmdemu_retro_cheat_set
    )
    
    let core = StaticCoreInfo(
        identifier: "clownmdemu",
        name: "ClownMDEmu",
        systemName: "Genesis",
        supportedExtensions: ["md", "gen", "smd", "bin"],
        coreInterface: interface
    )
    
    StaticCoreRegistry.shared.register(core)
}

// MARK: - melonDS (NDS)

private func registerMelonDSCore() {
    let interface = LibretroCoreInterface(
        retro_init: melonds_retro_init,
        retro_deinit: melonds_retro_deinit,
        retro_api_version: melonds_retro_api_version,
        retro_get_system_info: melonds_retro_get_system_info,
        retro_get_system_av_info: melonds_retro_get_system_av_info,
        retro_set_environment: melonds_retro_set_environment,
        retro_set_video_refresh: melonds_retro_set_video_refresh,
        retro_set_audio_sample: melonds_retro_set_audio_sample,
        retro_set_audio_sample_batch: melonds_retro_set_audio_sample_batch,
        retro_set_input_poll: melonds_retro_set_input_poll,
        retro_set_input_state: melonds_retro_set_input_state,
        retro_reset: melonds_retro_reset,
        retro_run: melonds_retro_run,
        retro_load_game: melonds_retro_load_game,
        retro_unload_game: melonds_retro_unload_game,
        retro_serialize_size: melonds_retro_serialize_size,
        retro_serialize: melonds_retro_serialize,
        retro_unserialize: melonds_retro_unserialize,
        retro_get_memory_data: melonds_retro_get_memory_data,
        retro_get_memory_size: melonds_retro_get_memory_size,
        retro_cheat_reset: melonds_retro_cheat_reset,
        retro_cheat_set: melonds_retro_cheat_set
    )
    
    let core = StaticCoreInfo(
        identifier: "melonds",
        name: "melonDS",
        systemName: "NDS",
        supportedExtensions: ["nds", "dsi"],
        coreInterface: interface
    )
    
    StaticCoreRegistry.shared.register(core)
}

// MARK: - Mupen64Plus-Next (N64)

private func registerMupen64PlusCore() {
    let interface = LibretroCoreInterface(
        retro_init: mupen64plus_next_retro_init,
        retro_deinit: mupen64plus_next_retro_deinit,
        retro_api_version: mupen64plus_next_retro_api_version,
        retro_get_system_info: mupen64plus_next_retro_get_system_info,
        retro_get_system_av_info: mupen64plus_next_retro_get_system_av_info,
        retro_set_environment: mupen64plus_next_retro_set_environment,
        retro_set_video_refresh: mupen64plus_next_retro_set_video_refresh,
        retro_set_audio_sample: mupen64plus_next_retro_set_audio_sample,
        retro_set_audio_sample_batch: mupen64plus_next_retro_set_audio_sample_batch,
        retro_set_input_poll: mupen64plus_next_retro_set_input_poll,
        retro_set_input_state: mupen64plus_next_retro_set_input_state,
        retro_reset: mupen64plus_next_retro_reset,
        retro_run: mupen64plus_next_retro_run,
        retro_load_game: mupen64plus_next_retro_load_game,
        retro_unload_game: mupen64plus_next_retro_unload_game,
        retro_serialize_size: mupen64plus_next_retro_serialize_size,
        retro_serialize: mupen64plus_next_retro_serialize,
        retro_unserialize: mupen64plus_next_retro_unserialize,
        retro_get_memory_data: mupen64plus_next_retro_get_memory_data,
        retro_get_memory_size: mupen64plus_next_retro_get_memory_size,
        retro_cheat_reset: mupen64plus_next_retro_cheat_reset,
        retro_cheat_set: mupen64plus_next_retro_cheat_set
    )
    
    let core = StaticCoreInfo(
        identifier: "mupen64plus_next",
        name: "Mupen64Plus-Next",
        systemName: "N64",
        supportedExtensions: ["n64", "v64", "z64", "bin", "u1"],
        coreInterface: interface
    )
    
    StaticCoreRegistry.shared.register(core)
}

// MARK: - PCSX ReARMed (PS1)
// 注意: PS1 核心现在使用动态 Framework 加载
// 静态库已被移除以避免与动态 Framework 冲突
// 如果需要恢复静态库支持，请取消下面的注释并在 Xcode 中重新链接静态库

#if STATIC_PCSX_ENABLED
private func registerPCSXReARMedCore() {
    let interface = LibretroCoreInterface(
        retro_init: pcsx_rearmed_retro_init,
        retro_deinit: pcsx_rearmed_retro_deinit,
        retro_api_version: pcsx_rearmed_retro_api_version,
        retro_get_system_info: pcsx_rearmed_retro_get_system_info,
        retro_get_system_av_info: pcsx_rearmed_retro_get_system_av_info,
        retro_set_environment: pcsx_rearmed_retro_set_environment,
        retro_set_video_refresh: pcsx_rearmed_retro_set_video_refresh,
        retro_set_audio_sample: pcsx_rearmed_retro_set_audio_sample,
        retro_set_audio_sample_batch: pcsx_rearmed_retro_set_audio_sample_batch,
        retro_set_input_poll: pcsx_rearmed_retro_set_input_poll,
        retro_set_input_state: pcsx_rearmed_retro_set_input_state,
        retro_reset: pcsx_rearmed_retro_reset,
        retro_run: pcsx_rearmed_retro_run,
        retro_load_game: pcsx_rearmed_retro_load_game,
        retro_unload_game: pcsx_rearmed_retro_unload_game,
        retro_serialize_size: pcsx_rearmed_retro_serialize_size,
        retro_serialize: pcsx_rearmed_retro_serialize,
        retro_unserialize: pcsx_rearmed_retro_unserialize,
        retro_get_memory_data: pcsx_rearmed_retro_get_memory_data,
        retro_get_memory_size: pcsx_rearmed_retro_get_memory_size,
        retro_cheat_reset: pcsx_rearmed_retro_cheat_reset,
        retro_cheat_set: pcsx_rearmed_retro_cheat_set
    )
    
    let core = StaticCoreInfo(
        identifier: "pcsx_rearmed",
        name: "PCSX ReARMed",
        systemName: "PS1",
        supportedExtensions: ["cue", "bin", "img", "mdf", "pbp", "chd"],
        coreInterface: interface
    )
    
    StaticCoreRegistry.shared.register(core)
}
#else
// PS1 使用动态 Framework，不需要静态注册
private func registerPCSXReARMedCore() {
    // 动态核心由 tryLoadAllDynamicCores() 加载
    print("⚠️ PCSX ReARMed 静态核心已禁用，使用动态 Framework")
}
#endif
