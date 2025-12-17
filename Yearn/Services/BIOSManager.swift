//
//  BIOSManager.swift
//  Yearn
//
//  BIOS 文件管理服务
//  负责管理模拟器所需的 BIOS 文件，支持内置开源 BIOS 和用户导入的官方 BIOS
//

import Foundation
import CommonCrypto

/// BIOS 文件信息结构体
struct BIOSFileInfo: Identifiable {
    let id = UUID()
    let name: String
    let system: String
    let size: Int64
    let isInstalled: Bool
    let isRequired: Bool
    let description: String
    let md5Hash: String?
    
    /// 格式化的文件大小
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

/// PS1 BIOS 区域枚举
enum PS1BIOSRegion: String, CaseIterable {
    case japan = "scph5500.bin"
    case usa = "scph5501.bin"
    case europe = "scph5502.bin"
    case usaOld = "scph1001.bin"
    case psp = "psxonpsp660.bin"
    
    var displayName: String {
        switch self {
        case .japan: return "日本 (SCPH-5500)"
        case .usa: return "北美 (SCPH-5501)"
        case .europe: return "欧洲 (SCPH-5502)"
        case .usaOld: return "北美旧版 (SCPH-1001)"
        case .psp: return "PSP (PSXONPSP660) - 推荐"
        }
    }
    
    var md5Hash: String {
        switch self {
        case .japan: return "8dd7d5296a650fac7319bce665a6a53c"
        case .usa: return "490f666e1afb15b7362b406ed1cea246"
        case .europe: return "32736f17079d0b2b7024407c39bd3050"
        case .usaOld: return "924e392ed05558ffdb115408c263dccf"
        case .psp: return "c53ca5908936d412331790f4426c6c33"
        }
    }
    
    var expectedSize: Int64 {
        return 524288 // 512 KB
    }
}

/// BIOS 管理器
/// 管理模拟器所需的 BIOS 文件
final class BIOSManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = BIOSManager()
    
    private init() {}
    
    // MARK: - Published Properties
    
    /// PS1 BIOS 是否可用
    @Published var isPS1BIOSAvailable: Bool = false
    
    /// 已安装的 BIOS 文件列表
    @Published var installedFiles: [BIOSFileInfo] = []
    
    // MARK: - Properties
    
    /// BIOS 目录路径
    var biosDirectory: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("BIOS", isDirectory: true)
    }
    
    /// 内置的 BIOS 文件列表
    /// 格式: (资源名称, 目标文件名, 系统)
    private let bundledBIOSFiles: [(resource: String, targetName: String, system: String)] = [
        // NDS FreeBIOS (BSD 许可证 - 开源替代品)
        ("bios7", "bios7.bin", "NDS"),
        ("bios9", "bios9.bin", "NDS"),
    ]
    
    /// PS1 所需的 BIOS 文件列表（任意一个即可运行）
    static let requiredPS1BIOSFiles: [String] = [
        "scph5500.bin",  // Japan (v3.0)
        "scph5501.bin",  // North America (v3.0)
        "scph5502.bin",  // Europe (v3.0)
        "scph1001.bin",  // North America (v2.0)
        "psxonpsp660.bin" // PSP version (High compatibility)
    ]
    
    // MARK: - Public Methods
    
    /// 初始化 BIOS 目录并复制内置 BIOS 文件
    /// 应在应用启动时调用
    func setupBIOS() {
        createBIOSDirectoryIfNeeded()
        copyBundledBIOSFiles()
        refreshBIOSStatus()
        
        print("📀 BIOSManager: BIOS 目录已初始化")
        print("📀 BIOSManager: 路径 = \(biosDirectory.path)")
    }
    
    /// 刷新 BIOS 状态
    func refreshBIOSStatus() {
        isPS1BIOSAvailable = checkPS1BIOSAvailable()
        installedFiles = getInstalledBIOSFiles()
    }
    
    /// 检查 PS1 BIOS 是否可用（至少有一个区域的 BIOS）
    func checkPS1BIOSAvailable() -> Bool {
        for biosFile in Self.requiredPS1BIOSFiles {
            let fileURL = biosDirectory.appendingPathComponent(biosFile)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return true
            }
        }
        return false
    }
    
    /// 检查指定系统的 BIOS 是否可用
    func isBIOSAvailable(for system: String) -> Bool {
        switch system {
        case "PS1":
            return checkPS1BIOSAvailable()
        case "NDS":
            let requiredFiles = bundledBIOSFiles.filter { $0.system == system }
            for file in requiredFiles {
                let fileURL = biosDirectory.appendingPathComponent(file.targetName)
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    return false
                }
            }
            return true
        default:
            return true // 其他系统不需要 BIOS
        }
    }
    
    /// 获取 BIOS 文件路径
    func biosPath(for fileName: String) -> URL {
        return biosDirectory.appendingPathComponent(fileName)
    }
    
    /// 获取所有已安装的 BIOS 文件信息
    func installedBIOSFiles() -> [(name: String, system: String, size: Int64)] {
        var files: [(name: String, system: String, size: Int64)] = []
        
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: biosDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ) else {
            return files
        }
        
        for fileURL in contents {
            let fileName = fileURL.lastPathComponent
            let system = systemForBIOSFile(fileName)
            
            if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let size = attributes[.size] as? Int64 {
                files.append((name: fileName, system: system, size: size))
            }
        }
        
        return files.sorted { $0.name < $1.name }
    }
    
    /// 获取已安装的 BIOS 文件详细信息
    func getInstalledBIOSFiles() -> [BIOSFileInfo] {
        var files: [BIOSFileInfo] = []
        
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: biosDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ) else {
            return files
        }
        
        for fileURL in contents {
            let fileName = fileURL.lastPathComponent
            let system = systemForBIOSFile(fileName)
            
            if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let size = attributes[.size] as? Int64 {
                
                let description = descriptionForBIOSFile(fileName)
                let md5 = md5HashForBIOSFile(fileName)
                
                files.append(BIOSFileInfo(
                    name: fileName,
                    system: system,
                    size: size,
                    isInstalled: true,
                    isRequired: isRequiredBIOS(fileName),
                    description: description,
                    md5Hash: md5
                ))
            }
        }
        
        return files.sorted { $0.name < $1.name }
    }
    
    /// 获取 PS1 BIOS 状态列表（包含已安装和未安装的）
    func getPS1BIOSStatus() -> [BIOSFileInfo] {
        var files: [BIOSFileInfo] = []
        
        for region in PS1BIOSRegion.allCases {
            let fileURL = biosDirectory.appendingPathComponent(region.rawValue)
            let isInstalled = FileManager.default.fileExists(atPath: fileURL.path)
            
            var size: Int64 = 0
            if isInstalled,
               let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let fileSize = attributes[.size] as? Int64 {
                size = fileSize
            }
            
            files.append(BIOSFileInfo(
                name: region.rawValue,
                system: "PS1",
                size: size,
                isInstalled: isInstalled,
                isRequired: false, // PS1 只需要任意一个区域的 BIOS
                description: region.displayName,
                md5Hash: region.md5Hash
            ))
        }
        
        return files
    }
    
    /// 导入 BIOS 文件
    /// - Parameter sourceURL: 源文件 URL
    /// - Returns: 导入结果（成功/失败原因）
    @discardableResult
    func importBIOSFile(from sourceURL: URL) -> Result<String, BIOSImportError> {
        let fileName = sourceURL.lastPathComponent.lowercased()
        
        // 验证文件名是否为已知的 BIOS 文件
        guard isValidBIOSFileName(fileName) else {
            return .failure(.unknownFile)
        }
        
        // 开始访问安全范围资源
        guard sourceURL.startAccessingSecurityScopedResource() else {
            return .failure(.accessDenied)
        }
        defer {
            sourceURL.stopAccessingSecurityScopedResource()
        }
        
        let targetURL = biosDirectory.appendingPathComponent(fileName)
        
        do {
            // 如果目标文件已存在，先删除
            if FileManager.default.fileExists(atPath: targetURL.path) {
                try FileManager.default.removeItem(at: targetURL)
            }
            
            // 复制文件
            try FileManager.default.copyItem(at: sourceURL, to: targetURL)
            
            // 刷新状态
            refreshBIOSStatus()
            
            print("📀 BIOSManager: 已导入 BIOS 文件 - \(fileName)")
            return .success(fileName)
            
        } catch {
            print("❌ BIOSManager: 导入 BIOS 文件失败 - \(error)")
            return .failure(.copyFailed(error.localizedDescription))
        }
    }
    
    /// 删除 BIOS 文件
    /// - Parameter fileName: 文件名
    /// - Returns: 是否成功删除
    @discardableResult
    func deleteBIOSFile(_ fileName: String) -> Bool {
        let fileURL = biosDirectory.appendingPathComponent(fileName)
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            refreshBIOSStatus()
            print("📀 BIOSManager: 已删除 BIOS 文件 - \(fileName)")
            return true
        } catch {
            print("❌ BIOSManager: 删除 BIOS 文件失败 - \(error)")
            return false
        }
    }
    
    /// 验证 BIOS 文件的 MD5 哈希值
    /// - Parameter fileName: 文件名
    /// - Returns: 验证结果
    func validateBIOSFile(_ fileName: String) -> BIOSValidationResult {
        let fileURL = biosDirectory.appendingPathComponent(fileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .notFound
        }
        
        guard let data = try? Data(contentsOf: fileURL) else {
            return .readError
        }
        
        let computedHash = md5Hash(data: data)
        
        // 检查是否为已知的 PS1 BIOS
        if let region = PS1BIOSRegion.allCases.first(where: { $0.rawValue.lowercased() == fileName.lowercased() }) {
            if computedHash == region.md5Hash {
                return .valid
            } else {
                return .hashMismatch(expected: region.md5Hash, actual: computedHash)
            }
        }
        
        // 其他 BIOS 文件，只要存在就认为有效
        return .valid
    }
    
    // MARK: - Private Methods
    
    /// 创建 BIOS 目录
    private func createBIOSDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: biosDirectory.path) {
            do {
                try FileManager.default.createDirectory(
                    at: biosDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                print("📀 BIOSManager: 已创建 BIOS 目录")
            } catch {
                print("❌ BIOSManager: 创建 BIOS 目录失败 - \(error)")
            }
        }
    }
    
    /// 复制内置的 BIOS 文件到 Documents/BIOS
    private func copyBundledBIOSFiles() {
        for biosFile in bundledBIOSFiles {
            let targetURL = biosDirectory.appendingPathComponent(biosFile.targetName)
            
            // 如果目标文件已存在，跳过
            if FileManager.default.fileExists(atPath: targetURL.path) {
                continue
            }
            
            // 从 Bundle 中查找资源文件
            guard let sourceURL = Bundle.main.url(
                forResource: biosFile.resource,
                withExtension: "bin",
                subdirectory: "BIOS"
            ) else {
                print("⚠️ BIOSManager: 未找到内置 BIOS 文件 - \(biosFile.resource).bin")
                continue
            }
            
            // 复制文件
            do {
                try FileManager.default.copyItem(at: sourceURL, to: targetURL)
                print("📀 BIOSManager: 已复制 \(biosFile.targetName) (\(biosFile.system))")
            } catch {
                print("❌ BIOSManager: 复制 \(biosFile.targetName) 失败 - \(error)")
            }
        }
    }
    
    /// 根据文件名判断所属系统
    private func systemForBIOSFile(_ fileName: String) -> String {
        let lowerName = fileName.lowercased()
        
        // NDS BIOS
        if lowerName.contains("bios7") || lowerName.contains("bios9") || lowerName.contains("firmware") {
            return "NDS"
        }
        
        // PS1 BIOS
        if lowerName.contains("scph") || lowerName.contains("psxonpsp") {
            return "PS1"
        }
        
        return "Unknown"
    }
    
    /// 获取 BIOS 文件描述
    private func descriptionForBIOSFile(_ fileName: String) -> String {
        let lowerName = fileName.lowercased()
        
        // PS1 BIOS
        if let region = PS1BIOSRegion.allCases.first(where: { $0.rawValue.lowercased() == lowerName }) {
            return region.displayName
        }
        
        // NDS BIOS
        if lowerName == "bios7.bin" {
            return "NDS ARM7 BIOS"
        }
        if lowerName == "bios9.bin" {
            return "NDS ARM9 BIOS"
        }
        if lowerName.contains("firmware") {
            return "NDS Firmware"
        }
        
        return fileName
    }
    
    /// 获取已知 BIOS 文件的 MD5 哈希值
    private func md5HashForBIOSFile(_ fileName: String) -> String? {
        let lowerName = fileName.lowercased()
        
        if let region = PS1BIOSRegion.allCases.first(where: { $0.rawValue.lowercased() == lowerName }) {
            return region.md5Hash
        }
        
        return nil
    }
    
    /// 检查是否为必需的 BIOS 文件
    private func isRequiredBIOS(_ fileName: String) -> Bool {
        let lowerName = fileName.lowercased()
        
        // NDS 需要所有 BIOS 文件
        if lowerName == "bios7.bin" || lowerName == "bios9.bin" {
            return true
        }
        
        return false
    }
    
    /// 验证文件名是否为已知的 BIOS 文件
    private func isValidBIOSFileName(_ fileName: String) -> Bool {
        let lowerName = fileName.lowercased()
        
        // PS1 BIOS
        let ps1Files = ["scph5500.bin", "scph5501.bin", "scph5502.bin", "scph1001.bin", 
                        "scph7001.bin", "scph7002.bin", "scph7003.bin", "psxonpsp660.bin"]
        if ps1Files.contains(lowerName) {
            return true
        }
        
        // NDS BIOS
        let ndsFiles = ["bios7.bin", "bios9.bin", "firmware.bin"]
        if ndsFiles.contains(lowerName) {
            return true
        }
        
        // 通用 SCPH 格式
        if lowerName.hasPrefix("scph") && lowerName.hasSuffix(".bin") {
            return true
        }
        
        return false
    }
    
    /// 计算数据的 MD5 哈希值
    private func md5Hash(data: Data) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        _ = data.withUnsafeBytes { buffer in
            CC_MD5(buffer.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

// MARK: - BIOS 导入错误

enum BIOSImportError: Error, LocalizedError {
    case unknownFile
    case accessDenied
    case copyFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .unknownFile:
            return "bios.error.unknownFile".localized
        case .accessDenied:
            return "bios.error.accessDenied".localized
        case .copyFailed(let reason):
            return String(format: "bios.error.copyFailed".localized, reason)
        }
    }
}

// MARK: - BIOS 验证结果

enum BIOSValidationResult {
    case valid
    case notFound
    case readError
    case hashMismatch(expected: String, actual: String)
    
    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
}

// MARK: - BIOS 许可证信息

extension BIOSManager {
    
    /// 内置 BIOS 的许可证信息
    struct BIOSLicense {
        let name: String
        let author: String
        let license: String
        let copyright: String
        let fullText: String
    }
    
    /// 获取所有内置 BIOS 的许可证信息
    static var bundledBIOSLicenses: [BIOSLicense] {
        return [
            BIOSLicense(
                name: "DraStic FreeBIOS (NDS)",
                author: "Gilead Kutnick",
                license: "BSD 2-Clause License",
                copyright: "Copyright (c) 2013, Gilead Kutnick",
                fullText: """
                Custom NDS ARM7/ARM9 BIOS replacement
                Copyright (c) 2013, Gilead Kutnick
                All rights reserved.
                
                Redistribution and use in source and binary forms, with or without
                modification, are permitted provided that the following conditions are met:
                
                1) Redistributions of source code must retain the above copyright notice,
                   this list of conditions and the following disclaimer.
                2) Redistributions in binary form must reproduce the above copyright notice,
                   this list of conditions and the following disclaimer in the documentation
                   and/or other materials provided with the distribution.
                
                THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
                AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
                IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
                ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
                LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
                CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
                SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
                INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
                CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
                ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
                POSSIBILITY OF SUCH DAMAGE.
                """
            )
        ]
    }
}

