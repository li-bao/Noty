import Foundation

/// 全域專案常數與品牌識別常數
public enum AppConstants {
    /// 品牌法定名稱（不可更動）
    public static let appName = "Noty"
    
    /// 應用程式 Bundle Identifier
    public static let bundleIdentifier = "com.libao.noty"
    
    /// 應用程式版本
    public static let appVersion = "1.0.0"
    
    /// 本機 Ollama 預設端點（嚴格限制本機 localhost / 127.0.0.1）
    public static let defaultOllamaEndpoint = URL(string: "http://127.0.0.1:11434")!
    
    /// 預設支援的本地模型
    public static let defaultOllamaModel = "llama3.2"
    
    /// 沙盒內媒體儲存子目錄名稱
    public static let mediaDirectoryName = "Media"
    public static let originalsDirectoryName = "Originals"
    public static let thumbnailsDirectoryName = "Thumbnails"
}
