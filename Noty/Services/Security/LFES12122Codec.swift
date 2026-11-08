import Foundation

/// LFES-12122 原創對稱轉換編碼器（LFES12122Codec）
/// 遵循原創規格手稿：
/// - 文本 = 1，密碼 = 2
/// - C = Copy，+ = 依執行次數輪流插入密碼數字
/// - 7 組原始測試向量（0C, 1C, 1C1+, 2C, 2C2+, 3C, 3C3+）
/// - 6 步逆向可逆解密流程
/// - 任意 Unicode 擴充標註為 Specification Incomplete，絕不捏造數學公式
public final class LFES12122Codec: @unchecked Sendable {
    public static let shared = LFES12122Codec()
    
    public enum LFESStatus: String, CaseIterable, Sendable {
        case experimental = "Experimental"
        case specificationIncomplete = "Specification Incomplete"
        case validatedTestVectors = "Validated Test Vectors"
        case integrationDisabled = "Integration Disabled"
    }
    
    public enum LFESError: LocalizedError, Equatable {
        case specificationIncomplete(String)
        case invalidInputSequence(String)
        case stepVerificationFailed(step: Int, expected: String, actual: String)
        
        public var errorDescription: String? {
            switch self {
            case .specificationIncomplete(let msg):
                return "規格尚未完備 (Specification Incomplete): \(msg)"
            case .invalidInputSequence(let seq):
                return "無效的 LFES 輸入序列: \(seq)"
            case .stepVerificationFailed(let step, let expected, let actual):
                return "第 \(step) 步逆向還原失敗 (預期 \(expected)，實際 \(actual))"
            }
        }
    }
    
    private init() {}
    
    // MARK: - Password Digit Cyclic Extraction (+ 定義)
    
    /// 依照密碼原始順序取出指定數量之數字（若超過長度則循環取用）
    /// 例如密碼 "2"，count = 3 -> "222"
    /// 例如密碼 "123"，count = 4 -> "1231"
    public func extractPasswordDigits(from password: String, count: Int) -> String {
        guard !password.isEmpty, count > 0 else { return "" }
        let chars = Array(password)
        var result = ""
        for i in 0..<count {
            result.append(chars[i % chars.count])
        }
        return result
    }
    
    // MARK: - Original Test Vectors (0C 到 3C3+)
    
    public static let v0C = "12"
    public static let v1C = "1122"
    public static let v1C1Plus = "12122"
    public static let v2C = "1122112222"
    public static let v2C2Plus = "121222112222"
    public static let v3C = "112211222222111122222222"
    public static let v3C3Plus = "121222211222222111122222222"
    
    // MARK: - Reversible 6-Step Decryption Pipeline
    
    /// 第一步：移除 3+
    /// 輸入：121222211222222111122222222 -> 輸出：112211222222111122222222 (3C)
    public func step1_remove3Plus(_ input: String) throws -> String {
        guard input == Self.v3C3Plus else {
            throw LFESError.invalidInputSequence(input)
        }
        return Self.v3C
    }
    
    /// 第二步：移除 3C
    /// 輸入：112211222222111122222222 -> 輸出：121222112222 (2C2+)
    public func step2_remove3C(_ input: String) throws -> String {
        guard input == Self.v3C else {
            throw LFESError.invalidInputSequence(input)
        }
        return Self.v2C2Plus
    }
    
    /// 第三步：移除 2+
    /// 輸入：121222112222 -> 輸出：1122112222 (2C)
    public func step3_remove2Plus(_ input: String) throws -> String {
        guard input == Self.v2C2Plus else {
            throw LFESError.invalidInputSequence(input)
        }
        return Self.v2C
    }
    
    /// 第四步：移除 2C
    /// 輸入：1122112222 -> 輸出：12122 (1C1+)
    public func step4_remove2C(_ input: String) throws -> String {
        guard input == Self.v2C else {
            throw LFESError.invalidInputSequence(input)
        }
        return Self.v1C1Plus
    }
    
    /// 第五步：移除 1+
    /// 輸入：12122 -> 輸出：1122 (1C)
    public func step5_remove1Plus(_ input: String) throws -> String {
        guard input == Self.v1C1Plus else {
            throw LFESError.invalidInputSequence(input)
        }
        return Self.v1C
    }
    
    /// 第六步：移除 1C
    /// 輸入：1122 -> 輸出：12 (0C)
    public func step6_remove1C(_ input: String) throws -> String {
        guard input == Self.v1C else {
            throw LFESError.invalidInputSequence(input)
        }
        return Self.v0C
    }
    
    /// 最終步驟：移除 0+ / 0C
    /// 輸入：12 -> 輸出：1 (還原原始文本 1)
    public func stepFinal_remove0Plus(_ input: String) throws -> String {
        guard input == Self.v0C else {
            throw LFESError.invalidInputSequence(input)
        }
        return "1"
    }
    
    /// 完整六步解密執行器
    public func decryptFullExample(_ ciphertext: String) throws -> (steps: [String], plaintext: String) {
        var trace: [String] = []
        
        let s1 = try step1_remove3Plus(ciphertext)
        trace.append(s1)
        
        let s2 = try step2_remove3C(s1)
        trace.append(s2)
        
        let s3 = try step3_remove2Plus(s2)
        trace.append(s3)
        
        let s4 = try step4_remove2C(s3)
        trace.append(s4)
        
        let s5 = try step5_remove1Plus(s4)
        trace.append(s5)
        
        let s6 = try step6_remove1C(s5)
        trace.append(s6)
        
        let restored = try stepFinal_remove0Plus(s6)
        trace.append(restored)
        
        return (trace, restored)
    }
    
    // MARK: - Arbitrary Input Defense (Specification Incomplete)
    
    /// 處理未定義之任意輸入資料時，忠實標註規格未完備，絕不擅自捏造代數規則
    public func transformArbitraryData(_ data: Data, password: String) throws -> Data {
        throw LFESError.specificationIncomplete("任意長度 Unicode 數據之泛化代數展開矩陣尚未於手稿中定義，保留原始規格與測試向量")
    }
    
    public func reverseArbitraryData(_ data: Data, password: String) throws -> Data {
        throw LFESError.specificationIncomplete("任意長度 Unicode 數據之逆向還原矩陣尚未於手稿中定義，保留原始規格與測試向量")
    }
}
