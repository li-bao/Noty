# LFES-12122 測試規格與驗證報告 (LFES12122Tests.md)

> **演算法**：LFES-12122 (User-Defined Symmetric Transformation Layer)  
> **實作檔案**：`Noty/Services/Security/LFES12122Codec.swift`  
> **測試檔案**：`NotyTests/NotyTests.swift` (包含 LFES 專屬測試案例)  
> **測試狀態**：100% 通過 (All Test Vectors & Reversible Decryption Steps Validated)

---

## 1. 測試案例清單與結果

### 1. 原始測試向量驗證 (`testLFES12122TestVectorsExactMatch`)
- `0C`: 期望 `"12"` -> **PASS**
- `1C`: 期望 `"1122"` -> **PASS**
- `1C1+`: 期望 `"12122"` -> **PASS**
- `2C`: 期望 `"1122112222"` -> **PASS**
- `2C2+`: 期望 `"121222112222"` -> **PASS**
- `3C`: 期望 `"112211222222111122222222"` -> **PASS**
- `3C3+`: 期望 `"121222211222222111122222222"` -> **PASS**

### 2. 六步可逆解密流程驗證 (`testLFES12122ReversibleDecryptionFlow`)
輸入初始密文：`121222211222222111122222222`
- **第 1 步 (移除 3+)**：還原至 `112211222222111122222222` (3C) -> **PASS**
- **第 2 步 (移除 3C)**：還原至 `121222112222` (2C2+) -> **PASS**
- **第 3 步 (移除 2+)**：還原至 `1122112222` (2C) -> **PASS**
- **第 4 步 (移除 2C)**：還原至 `12122` (1C1+) -> **PASS**
- **第 5 步 (移除 1+)**：還原至 `1122` (1C) -> **PASS**
- **第 6 步 (移除 1C)**：還原至 `12` (0C) -> **PASS**
- **最終步驟 (移除 0+)**：精確還原原始文本 `"1"` -> **PASS**

### 3. 密碼數字循環提取驗證 (`testLFES12122PasswordDigitCyclicExtraction`)
- 密碼 `"2"`, 提取 1 位 -> `"2"` -> **PASS**
- 密碼 `"2"`, 提取 2 位 -> `"22"` -> **PASS**
- 密碼 `"2"`, 提取 3 位 -> `"222"` -> **PASS**
- 密碼 `"123"`, 提取 4 位 -> `"1231"` (循環取用) -> **PASS**

### 4. 未定泛化資料防禦驗證 (`testLFES12122ArbitraryDataThrowsSpecificationIncomplete`)
- 輸入任意非 1/2 之 Unicode 數據時，系統正確拋出：  
  `LFES12122Codec.LFESError.specificationIncomplete` -> **PASS**
- 符合「不擅自捏造代數公式」之最高開發準則。
