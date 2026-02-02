import Foundation
import CryptoKit

/// API 执行结果
struct APIResponse {
    var statusCode: Int
    var headers: [String: String]
    var data: Data
    var json: Any?
    var extractedVariables: [String: String]

    var jsonString: String {
        guard let json = json else {
            return String(data: data, encoding: .utf8) ?? ""
        }
        if let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            return String(data: prettyData, encoding: .utf8) ?? ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

/// API 执行器
@MainActor
class APIRunner: ObservableObject {
    @Published var isRunning = false
    @Published var response: APIResponse?
    @Published var error: String?
    @Published var currentStep = 0
    @Published var totalSteps = 0

    private var currentTask: Task<Void, Never>?

    /// 执行单个 API
    func run(
        endpoint: APIEndpoint,
        variables: [String: String] = [:]
    ) async throws -> APIResponse {
        isRunning = true
        error = nil
        defer { isRunning = false }

        // 构建 URL
        let urlString = replaceVariables(endpoint.url, with: variables)
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL(urlString)
        }

        // 构建请求
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.methodRaw
        request.timeoutInterval = 30

        // 添加 Headers
        var headers = endpoint.headers
        for (key, value) in headers {
            request.setValue(replaceVariables(value, with: variables), forHTTPHeaderField: key)
        }

        // 添加认证
        try applyAuth(to: &request, endpoint: endpoint, variables: variables)

        // 添加 Body
        if let bodyTemplate = endpoint.bodyTemplate, !bodyTemplate.isEmpty {
            let body = replaceVariables(bodyTemplate, with: variables)
            request.httpBody = body.data(using: .utf8)
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        // 发送请求
        let (data, urlResponse) = try await URLSession.shared.data(for: request)

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // 解析响应
        var responseHeaders: [String: String] = [:]
        for (key, value) in httpResponse.allHeaderFields {
            if let keyStr = key as? String, let valueStr = value as? String {
                responseHeaders[keyStr] = valueStr
            }
        }

        let json = try? JSONSerialization.jsonObject(with: data)

        // 提取变量
        var extractedVariables: [String: String] = [:]
        for extraction in endpoint.outputExtractions {
            if let value = extractValue(from: json, jsonPath: extraction.jsonPath) {
                extractedVariables[extraction.variableName] = value
            }
        }

        let apiResponse = APIResponse(
            statusCode: httpResponse.statusCode,
            headers: responseHeaders,
            data: data,
            json: json,
            extractedVariables: extractedVariables
        )

        self.response = apiResponse
        return apiResponse
    }

    /// 执行 API 组合
    func runPipeline(
        pipeline: APIPipeline,
        endpoints: [APIEndpoint],
        initialVariables: [String: String] = [:]
    ) async throws -> APIResponse {
        isRunning = true
        error = nil
        currentStep = 0
        totalSteps = pipeline.steps.count

        defer {
            isRunning = false
            currentStep = 0
            totalSteps = 0
        }

        var variables = initialVariables
        var lastResponse: APIResponse?

        for (index, step) in pipeline.steps.enumerated() {
            currentStep = index + 1

            guard let endpoint = endpoints.first(where: { $0.id == step.endpointId }) else {
                throw APIError.endpointNotFound(step.endpointId.uuidString)
            }

            // 合并输入映射到变量
            for (varName, mapping) in step.inputMappings {
                variables[varName] = replaceVariables(mapping, with: variables)
            }

            lastResponse = try await run(endpoint: endpoint, variables: variables)

            // 将提取的变量添加到变量池，加上步骤前缀
            for (key, value) in lastResponse?.extractedVariables ?? [:] {
                variables[key] = value
                variables["step\(index + 1).\(key)"] = value
            }
        }

        guard let finalResponse = lastResponse else {
            throw APIError.emptyPipeline
        }

        return finalResponse
    }

    /// 取消执行
    func cancel() {
        currentTask?.cancel()
        isRunning = false
    }

    // MARK: - Private Methods

    /// 替换变量占位符
    private func replaceVariables(_ text: String, with variables: [String: String]) -> String {
        var result = text

        // 替换时间戳
        result = result.replacingOccurrences(of: "{{timestamp}}", with: String(Int(Date().timeIntervalSince1970)))

        // 替换自定义变量
        for (key, value) in variables {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }

        return result
    }

    /// 应用认证
    private func applyAuth(to request: inout URLRequest, endpoint: APIEndpoint, variables: [String: String]) throws {
        let config = endpoint.authConfig

        switch endpoint.authType {
        case .none:
            break

        case .apiKey:
            // API Key 可以在 Header 或 Query 参数中
            if let key = config["key"], let value = config["value"] {
                let location = config["location"] ?? "header"
                if location == "query" {
                    // 添加到 URL query
                    if var urlComponents = URLComponents(url: request.url!, resolvingAgainstBaseURL: false) {
                        var queryItems = urlComponents.queryItems ?? []
                        queryItems.append(URLQueryItem(name: key, value: replaceVariables(value, with: variables)))
                        urlComponents.queryItems = queryItems
                        request.url = urlComponents.url
                    }
                } else {
                    request.setValue(replaceVariables(value, with: variables), forHTTPHeaderField: key)
                }
            }

        case .token:
            // 本地计算 Token（如 MD5(Key+Timestamp+Secret)）
            if let key = config["key"],
               let secret = config["secret"],
               let algorithm = config["algorithm"] {
                let timestamp = String(Int(Date().timeIntervalSince1970))
                let token = generateToken(key: key, timestamp: timestamp, secret: secret, algorithm: algorithm)

                // 添加到 Header
                if let headerName = config["headerName"] {
                    request.setValue(token, forHTTPHeaderField: headerName)
                }

                // 可能还需要添加 timestamp 和 key 到 Header
                if let keyHeader = config["keyHeader"] {
                    request.setValue(key, forHTTPHeaderField: keyHeader)
                }
                if let timestampHeader = config["timestampHeader"] {
                    request.setValue(timestamp, forHTTPHeaderField: timestampHeader)
                }
            }

        case .bearer:
            if let token = config["token"] {
                request.setValue("Bearer \(replaceVariables(token, with: variables))", forHTTPHeaderField: "Authorization")
            }

        case .custom:
            // 自定义认证：直接使用配置中的 headers
            for (key, value) in config {
                request.setValue(replaceVariables(value, with: variables), forHTTPHeaderField: key)
            }
        }
    }

    /// 生成 Token
    private func generateToken(key: String, timestamp: String, secret: String, algorithm: String) -> String {
        let input: String

        // 解析算法表达式（如 "MD5(Key+Timestamp+Secret)"）
        if algorithm.contains("Key+Timestamp+Secret") {
            input = key + timestamp + secret
        } else if algorithm.contains("Timestamp+Key+Secret") {
            input = timestamp + key + secret
        } else if algorithm.contains("Secret+Timestamp+Key") {
            input = secret + timestamp + key
        } else {
            input = key + timestamp + secret // 默认
        }

        if algorithm.uppercased().contains("MD5") {
            return md5(input)
        } else if algorithm.uppercased().contains("SHA256") {
            return sha256(input)
        } else {
            return input
        }
    }

    /// MD5 哈希
    private func md5(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined().uppercased()
    }

    /// SHA256 哈希
    private func sha256(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    /// 从 JSON 中提取值（简单的 JSONPath 实现）
    private func extractValue(from json: Any?, jsonPath: String) -> String? {
        guard let json = json else { return nil }

        // 解析 JSONPath（简单实现，支持 $.a.b.c 格式）
        var path = jsonPath
        if path.hasPrefix("$.") {
            path = String(path.dropFirst(2))
        } else if path.hasPrefix("$") {
            path = String(path.dropFirst(1))
        }

        let components = path.split(separator: ".").map(String.init)
        var current: Any = json

        for component in components {
            // 检查是否是数组索引（如 [0]）
            if component.contains("[") && component.contains("]") {
                let parts = component.split(separator: "[")
                let key = String(parts[0])
                let indexStr = String(parts[1].dropLast())

                if !key.isEmpty {
                    guard let dict = current as? [String: Any],
                          let next = dict[key] else {
                        return nil
                    }
                    current = next
                }

                guard let index = Int(indexStr),
                      let array = current as? [Any],
                      index >= 0 && index < array.count else {
                    return nil
                }
                current = array[index]
            } else {
                guard let dict = current as? [String: Any],
                      let next = dict[component] else {
                    return nil
                }
                current = next
            }
        }

        // 转换为字符串
        if let string = current as? String {
            return string
        } else if let number = current as? NSNumber {
            return number.stringValue
        } else if let bool = current as? Bool {
            return bool ? "true" : "false"
        } else {
            return nil
        }
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case endpointNotFound(String)
    case emptyPipeline
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "无效的 URL: \(url)"
        case .invalidResponse:
            return "无效的响应"
        case .endpointNotFound(let id):
            return "未找到 API 端点: \(id)"
        case .emptyPipeline:
            return "API 组合为空"
        case .requestFailed(let message):
            return "请求失败: \(message)"
        }
    }
}
