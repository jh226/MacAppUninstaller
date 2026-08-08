import Foundation

class AppDescriptionFetcher {

    private let groqApiKey: String? = {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let key = dict["GROQ_API_KEY"] as? String else {
            return nil
        }
        return key
    }()

    private let cacheFileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("AppUninstaller")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("description_cache.csv")
    }()

    private var cache: [String: (description: String, date: String)] = [:]
    private let cacheLock = NSLock()

    init() {
        loadCache()
    }

    func fetchDescription(bundleId: String, appName: String, appPath: String) -> String? {
        if let cached = getCachedDescription(for: appName) {
            return cached
        }

        if let desc = fetchFromGroq(appName: appName) {
            saveToCacheAndWrite(appName: appName, description: desc)
            return desc
        }

        return nil
    }

    // MARK: - Cache

    private func loadCache() {
        guard let data = try? String(contentsOf: cacheFileURL, encoding: .utf8) else { return }
        let lines = data.components(separatedBy: "\n")
        for line in lines {
            let fields = parseCSVLine(line)
            guard fields.count >= 3 else { continue }
            cache[fields[0]] = (description: fields[1], date: fields[2])
        }
    }

    private func getCachedDescription(for appName: String) -> String? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cache[appName]?.description
    }

    private func saveToCacheAndWrite(appName: String, description: String) {
        let dateStr = ISO8601DateFormatter().string(from: Date())
        cacheLock.lock()
        cache[appName] = (description: description, date: dateStr)
        let lines = cache.map { name, value in
            "\(escapeCSV(name)),\(escapeCSV(value.description)),\(value.date)"
        }
        cacheLock.unlock()
        let content = lines.joined(separator: "\n")
        try? content.write(to: cacheFileURL, atomically: true, encoding: .utf8)
    }

    private func escapeCSV(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var chars = line.makeIterator()
        while let ch = chars.next() {
            if inQuotes {
                if ch == "\"" {
                    if let next = chars.next() {
                        if next == "\"" {
                            current.append("\"")
                        } else {
                            inQuotes = false
                            if next == "," {
                                fields.append(current)
                                current = ""
                            } else {
                                current.append(next)
                            }
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(ch)
                }
            } else {
                if ch == "\"" {
                    inQuotes = true
                } else if ch == "," {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(ch)
                }
            }
        }
        fields.append(current)
        return fields
    }

    // MARK: - Fetch

    private func fetchFromGroq(appName: String) -> String? {
        guard let apiKey = groqApiKey else { return nil }

        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else { return nil }

        let body: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": [
                ["role": "user", "content": "macOS 앱 중 \(appName)이 뭐하는 앱인지 한국어로 간단하게 설명해. 예를 들어 \"프로그래밍 앱\", \"문서 작성 앱\" 이런 식으로 답변해. 설명만 출력해."]
            ],
            "max_tokens": 60,
            "temperature": 0.1
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData

        let semaphore = DispatchSemaphore(value: 0)
        var result: String?

        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            defer { semaphore.signal() }
            guard error == nil, let data = data else { return }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let first = choices.first,
               let message = first["message"] as? [String: Any],
               let content = message["content"] as? String {
                let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty {
                    result = cleaned
                }
            }
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 10)

        return result
    }

}
