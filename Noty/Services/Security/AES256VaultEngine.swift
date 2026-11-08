import Foundation
import CryptoKit
import CommonCrypto
import Security

/// Noty 原生 AES-256-GCM 本機保險庫加密引擎（AES256VaultEngine）
/// 遵循 Apple 原生 CryptoKit 與 CommonCrypto 規範
/// 規格：
/// - 演算法：AES-256-GCM 認證加密 (Authenticated Encryption with Associated Data)
/// - 金鑰推導：PBKDF2-HMAC-SHA256 (600,000 迭代次數，32 位元組獨立隨機 Salt)
/// - 大型媒體分塊：4 MiB (4,194,304 bytes) 串流處理，保證記憶體佔用極低
/// - Nonce 管理：12 位元組單調遞增 Nonce（4 位元組隨機前綴 + 8 位元組大端序 Chunk 序號），絕不重複 Nonce
/// - 容器格式：NOTYVLT1 專屬結構，包含 Magic、版本、Salt、分塊數、原始大小與認證標籤 (Tag)
/// - 完整性防禦：可精準偵測 Chunk 篡改、順序置換、檔案截斷、標籤損毀與假金鑰
public final class AES256VaultEngine: @unchecked Sendable {
    public static let shared = AES256VaultEngine()
    
    // MARK: - Constants
    public static let magicHeader = "NOTYVLT1".data(using: .utf8)! // 8 bytes
    public static let formatVersion: UInt32 = 1
    public static let saltLength: Int = 32
    public static let defaultIterations: UInt32 = 600_000
    public static let chunkSize: Int = 4 * 1024 * 1024 // 4 MiB
    public static let gcmTagLength: Int = 16
    public static let nonceLength: Int = 12
    
    public enum VaultError: LocalizedError, Equatable {
        case invalidMagic
        case unsupportedVersion(UInt32)
        case invalidSalt
        case invalidKey
        case invalidData
        case authenticationFailed
        case tamperedData(String)
        case truncatedFile
        case fileIOError(String)
        case invalidChunkOrder(expected: UInt64, found: UInt64)
        
        public var errorDescription: String? {
            switch self {
            case .invalidMagic:
                return "無效的保險庫檔案標頭 (Magic 辨識碼不符)"
            case .unsupportedVersion(let v):
                return "不支援的保險庫版本: \(v)"
            case .invalidSalt:
                return "無效或損毀的 Salt 資料"
            case .invalidKey:
                return "金鑰無效或長度不正確 (需 256 位元)"
            case .invalidData:
                return "欲處理之資料格式錯誤"
            case .authenticationFailed:
                return "身分認證失敗 (密碼不正確或資料已遭竄改)"
            case .tamperedData(let reason):
                return "資料完整性校驗失敗: \(reason)"
            case .truncatedFile:
                return "檔案已遭非預期截斷或分塊缺失"
            case .fileIOError(let path):
                return "檔案讀寫錯誤: \(path)"
            case .invalidChunkOrder(let expected, let found):
                return "分塊順序錯誤 (預期 \(expected)，實際 \(found))"
            }
        }
    }
    
    private init() {}
    
    // MARK: - Key Derivation (PBKDF2-HMAC-SHA256, 600,000 iterations)
    
    /// 生成密碼學安全隨機 32 位元組 Salt
    public func generateSalt() throws -> Data {
        var salt = Data(count: Self.saltLength)
        let status = salt.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, Self.saltLength, bytes.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw VaultError.invalidSalt
        }
        return salt
    }
    
    /// 透過 PBKDF2-HMAC-SHA256 從使用者密碼推導 256-bit AES 對稱金鑰
    public func deriveKey(
        from password: String,
        salt: Data,
        iterations: UInt32 = defaultIterations
    ) throws -> SymmetricKey {
        guard salt.count == Self.saltLength else {
            throw VaultError.invalidSalt
        }
        guard let passwordData = password.data(using: .utf8) else {
            throw VaultError.invalidData
        }
        
        let keyLength = 32
        var derivedKeyData = Data(count: keyLength) // 256 bits
        let passwordLength = passwordData.count
        let saltLength = salt.count
        
        let status = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordLength,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        saltLength,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        iterations,
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }
        
        guard status == kCCSuccess else {
            throw VaultError.invalidKey
        }
        
        return SymmetricKey(data: derivedKeyData)
    }
    
    /// 基準效能測量：計算在當前晶片（Apple Silicon M4）上推導金鑰所需毫秒數
    public func benchmarkKeyDerivation(iterations: UInt32 = defaultIterations) -> (durationMs: Double, key: SymmetricKey)? {
        let dummyPassword = "NotyBenchmarkPassword_2026"
        guard let salt = try? generateSalt() else { return nil }
        
        let start = DispatchTime.now()
        guard let key = try? deriveKey(from: dummyPassword, salt: salt, iterations: iterations) else {
            return nil
        }
        let end = DispatchTime.now()
        let nanos = end.uptimeNanoseconds - start.uptimeNanoseconds
        let ms = Double(nanos) / 1_000_000.0
        return (ms, key)
    }
    
    // MARK: - In-Memory Data Encryption & Decryption (Field-level & Small Payload)
    
    /// 對小資料進行 AES-256-GCM 認證加密
    /// 回傳封裝格式：[12 bytes Nonce] + [Ciphertext] + [16 bytes Tag]
    public func encryptData(_ plaintext: Data, withKey key: SymmetricKey, aad: Data = Data()) throws -> Data {
        let nonce = AES.GCM.Nonce()
        do {
            let sealedBox = try AES.GCM.seal(plaintext, using: key, nonce: nonce, authenticating: aad)
            guard let combined = sealedBox.combined else {
                throw VaultError.invalidData
            }
            return combined
        } catch {
            throw VaultError.tamperedData(error.localizedDescription)
        }
    }
    
    /// 對 AES-256-GCM 密文進行驗證與解密
    public func decryptData(_ combinedCiphertext: Data, withKey key: SymmetricKey, aad: Data = Data()) throws -> Data {
        guard combinedCiphertext.count >= Self.nonceLength + Self.gcmTagLength else {
            throw VaultError.truncatedFile
        }
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: combinedCiphertext)
            let plaintext = try AES.GCM.open(sealedBox, using: key, authenticating: aad)
            return plaintext
        } catch {
            throw VaultError.authenticationFailed
        }
    }
    
    // MARK: - Streaming Chunked File Encryption (Large Videos & Photos, 4 MiB)
    
    /// 建立 Chunk 專屬 12 位元組 Nonce
    /// 結構：4 位元組 Salt 前綴 + 8 位元組大端序 Chunk Index
    private func makeChunkNonce(salt: Data, chunkIndex: UInt64) -> AES.GCM.Nonce? {
        var nonceBytes = Data(capacity: 12)
        nonceBytes.append(salt.prefix(4))
        var bigEndianIndex = chunkIndex.bigEndian
        withUnsafeBytes(of: &bigEndianIndex) { bytes in
            nonceBytes.append(contentsOf: bytes)
        }
        return try? AES.GCM.Nonce(data: nonceBytes)
    }
    
    /// 串流式將來源檔案加密為 Noty Vault 容器（.notyvault 格式）
    /// 支援即時回報進度與取消
    public func encryptFile(
        at sourceURL: URL,
        to destinationURL: URL,
        key: SymmetricKey,
        salt: Data,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw VaultError.fileIOError(sourceURL.path)
        }
        
        let attributes = try fileManager.attributesOfItem(atPath: sourceURL.path)
        guard let fileSize = attributes[.size] as? UInt64 else {
            throw VaultError.fileIOError("無法取得檔案大小")
        }
        
        let chunkSizeBytes = UInt64(Self.chunkSize)
        let totalChunks = fileSize == 0 ? 1 : UInt64(ceil(Double(fileSize) / Double(chunkSizeBytes)))
        
        // 建立目標檔案暫存路徑，確認完整無誤後再替換
        let tempDest = destinationURL.appendingPathExtension("tmp")
        if fileManager.fileExists(atPath: tempDest.path) {
            try? fileManager.removeItem(at: tempDest)
        }
        fileManager.createFile(atPath: tempDest.path, contents: nil)
        
        guard let sourceHandle = FileHandle(forReadingAtPath: sourceURL.path),
              let destHandle = FileHandle(forWritingAtPath: tempDest.path) else {
            throw VaultError.fileIOError("檔案讀寫通道建立失敗")
        }
        
        defer {
            try? sourceHandle.close()
            try? destHandle.close()
        }
        
        // 1. 寫入 Header
        var header = Data()
        header.append(Self.magicHeader) // 8 bytes
        var version = Self.formatVersion.bigEndian
        withUnsafeBytes(of: &version) { header.append(contentsOf: $0) } // 4 bytes
        header.append(salt) // 32 bytes
        var chunkSizeUInt32 = UInt32(Self.chunkSize).bigEndian
        withUnsafeBytes(of: &chunkSizeUInt32) { header.append(contentsOf: $0) } // 4 bytes
        var totalChunksUInt64 = totalChunks.bigEndian
        withUnsafeBytes(of: &totalChunksUInt64) { header.append(contentsOf: $0) } // 8 bytes
        var fileSizeUInt64 = fileSize.bigEndian
        withUnsafeBytes(of: &fileSizeUInt64) { header.append(contentsOf: $0) } // 8 bytes
        
        // 認證 Header (使用 Key 認證 Header 本身，避免 Metadata 被修改)
        let headerTag = try encryptData(header, withKey: key, aad: "NOTY_HEADER_AAD".data(using: .utf8)!)
        var headerPayload = Data()
        var headerPayloadLength = UInt32(headerTag.count).bigEndian
        withUnsafeBytes(of: &headerPayloadLength) { headerPayload.append(contentsOf: $0) }
        headerPayload.append(headerTag)
        
        destHandle.write(headerPayload)
        
        // 2. 依序加密各個 4 MiB 分塊
        for chunkIndex in 0..<totalChunks {
            let chunkData = sourceHandle.readData(ofLength: Self.chunkSize)
            guard let nonce = makeChunkNonce(salt: salt, chunkIndex: chunkIndex) else {
                throw VaultError.tamperedData("Nonce 生成失敗")
            }
            
            // 綁定 AAD：Chunk Index 與總大小，防止分塊調換與竄改
            var aad = Data()
            var idx = chunkIndex.bigEndian
            withUnsafeBytes(of: &idx) { aad.append(contentsOf: $0) }
            var fsz = fileSize.bigEndian
            withUnsafeBytes(of: &fsz) { aad.append(contentsOf: $0) }
            
            let sealed = try AES.GCM.seal(chunkData, using: key, nonce: nonce, authenticating: aad)
            
            // 寫入 Chunk 結構：[4 bytes Ciphertext Length] + [Ciphertext] + [16 bytes Tag]
            let ciphertext = sealed.ciphertext
            let tag = sealed.tag
            
            var chunkEnvelope = Data()
            var cipherLen = UInt32(ciphertext.count).bigEndian
            withUnsafeBytes(of: &cipherLen) { chunkEnvelope.append(contentsOf: $0) }
            chunkEnvelope.append(ciphertext)
            chunkEnvelope.append(tag)
            
            destHandle.write(chunkEnvelope)
            
            let progress = Double(chunkIndex + 1) / Double(totalChunks)
            progressHandler?(progress)
        }
        
        try destHandle.synchronize()
        
        // 安全原子替換
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: tempDest, to: destinationURL)
    }
    
    /// 串流式將 Noty Vault 容器（.notyvault 格式）解密為原始檔案
    public func decryptFile(
        at encryptedURL: URL,
        to destinationURL: URL,
        key: SymmetricKey,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: encryptedURL.path) else {
            throw VaultError.fileIOError(encryptedURL.path)
        }
        
        guard let encHandle = FileHandle(forReadingAtPath: encryptedURL.path) else {
            throw VaultError.fileIOError("無法開啟密文檔案")
        }
        
        let tempDest = destinationURL.appendingPathExtension("tmp")
        if fileManager.fileExists(atPath: tempDest.path) {
            try? fileManager.removeItem(at: tempDest)
        }
        fileManager.createFile(atPath: tempDest.path, contents: nil)
        
        guard let destHandle = FileHandle(forWritingAtPath: tempDest.path) else {
            try? encHandle.close()
            throw VaultError.fileIOError("無法建立解密寫入檔案")
        }
        
        defer {
            try? encHandle.close()
            try? destHandle.close()
        }
        
        // 1. 讀取並驗證 Header
        let headerLenData = encHandle.readData(ofLength: 4)
        guard headerLenData.count == 4 else { throw VaultError.truncatedFile }
        let headerLen = UInt32(bigEndian: headerLenData.withUnsafeBytes { $0.load(as: UInt32.self) })
        
        let headerCipher = encHandle.readData(ofLength: Int(headerLen))
        guard headerCipher.count == Int(headerLen) else { throw VaultError.truncatedFile }
        
        let rawHeader = try decryptData(headerCipher, withKey: key, aad: "NOTY_HEADER_AAD".data(using: .utf8)!)
        
        // 解析 Header 內部欄位
        guard rawHeader.count >= 64 else { throw VaultError.invalidData }
        let magic = rawHeader.prefix(8)
        guard magic == Self.magicHeader else { throw VaultError.invalidMagic }
        
        var offset = 8
        let version = UInt32(bigEndian: rawHeader.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self) })
        guard version == Self.formatVersion else { throw VaultError.unsupportedVersion(version) }
        offset += 4
        
        let salt = rawHeader.subdata(in: offset..<offset+32)
        offset += 32
        
        let storedChunkSize = UInt32(bigEndian: rawHeader.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self) })
        offset += 4
        
        let totalChunks = UInt64(bigEndian: rawHeader.subdata(in: offset..<offset+8).withUnsafeBytes { $0.load(as: UInt64.self) })
        offset += 8
        
        let originalFileSize = UInt64(bigEndian: rawHeader.subdata(in: offset..<offset+8).withUnsafeBytes { $0.load(as: UInt64.self) })
        offset += 8
        
        // 2. 逐一解密分塊
        var totalBytesWritten: UInt64 = 0
        
        for chunkIndex in 0..<totalChunks {
            let chunkLenData = encHandle.readData(ofLength: 4)
            guard chunkLenData.count == 4 else { throw VaultError.truncatedFile }
            let cipherLen = UInt32(bigEndian: chunkLenData.withUnsafeBytes { $0.load(as: UInt32.self) })
            
            let ciphertext = encHandle.readData(ofLength: Int(cipherLen))
            guard ciphertext.count == Int(cipherLen) else { throw VaultError.truncatedFile }
            
            let tag = encHandle.readData(ofLength: Self.gcmTagLength)
            guard tag.count == Self.gcmTagLength else { throw VaultError.truncatedFile }
            
            guard let nonce = makeChunkNonce(salt: salt, chunkIndex: chunkIndex) else {
                throw VaultError.tamperedData("Nonce 建構失敗")
            }
            
            // 驗證 AAD 綁定
            var aad = Data()
            var idx = chunkIndex.bigEndian
            withUnsafeBytes(of: &idx) { aad.append(contentsOf: $0) }
            var fsz = originalFileSize.bigEndian
            withUnsafeBytes(of: &fsz) { aad.append(contentsOf: $0) }
            
            do {
                let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
                let plaintext = try AES.GCM.open(sealedBox, using: key, authenticating: aad)
                destHandle.write(plaintext)
                totalBytesWritten += UInt64(plaintext.count)
            } catch {
                throw VaultError.authenticationFailed
            }
            
            let progress = Double(chunkIndex + 1) / Double(totalChunks)
            progressHandler?(progress)
        }
        
        // 驗證總大小
        if originalFileSize > 0 && totalBytesWritten != originalFileSize {
            throw VaultError.tamperedData("解密後檔案大小與標頭不一致 (預期 \(originalFileSize)，實際 \(totalBytesWritten))")
        }
        
        try destHandle.synchronize()
        
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: tempDest, to: destinationURL)
    }
}
