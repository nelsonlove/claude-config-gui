import Foundation

/// Tests whether an MCP server can start and respond to an initialize handshake.
enum MCPConnectionTester {
    enum TestResult {
        case success(serverName: String, version: String?)
        case failure(String)
    }

    /// Test an MCP server connection with a 5-second timeout.
    static func test(_ server: MCPServer) async -> TestResult {
        switch server.transportType {
        case .stdio:
            return await testStdio(server)
        case .http:
            return await testHTTP(server)
        case .sse, .ws:
            return await testReachability(server)
        }
    }

    // MARK: - stdio

    private static func testStdio(_ server: MCPServer) async -> TestResult {
        guard let command = server.command, !command.isEmpty else {
            return .failure("No command configured")
        }

        let process = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        // Use the user's shell to resolve PATH for commands like npx, uvx
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        let fullCommand = ([command] + (server.args ?? [])).joined(separator: " ")
        process.arguments = ["-l", "-c", fullCommand]
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Set env vars if configured
        if let env = server.env, !env.isEmpty {
            var processEnv = ProcessInfo.processInfo.environment
            for (k, v) in env { processEnv[k] = v }
            process.environment = processEnv
        }

        do {
            try process.run()
        } catch {
            return .failure("Failed to launch: \(error.localizedDescription)")
        }

        // Send initialize request
        let request = """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"claude-config-gui","version":"0.1.0"}}}
        """
        let requestData = Data((request + "\n").utf8)
        stdinPipe.fileHandleForWriting.write(requestData)

        // Read response with timeout
        return await withTaskGroup(of: TestResult.self) { group in
            group.addTask {
                let handle = stdoutPipe.fileHandleForReading
                var buffer = Data()
                let deadline = Date().addingTimeInterval(5)

                while Date() < deadline {
                    let chunk = handle.availableData
                    if chunk.isEmpty {
                        try? await Task.sleep(for: .milliseconds(50))
                        continue
                    }
                    buffer.append(chunk)

                    // Try to parse a JSON-RPC response from the buffer
                    if let result = parseInitializeResponse(buffer) {
                        return result
                    }
                }

                // Check stderr for clues
                let stderrData = stderrPipe.fileHandleForReading.availableData
                if !stderrData.isEmpty,
                   let stderrText = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !stderrText.isEmpty {
                    return .failure("Timeout — stderr: \(String(stderrText.prefix(200)))")
                }
                return .failure("Timeout — no response within 5 seconds")
            }

            group.addTask {
                try? await Task.sleep(for: .seconds(6))
                return .failure("Timeout")
            }

            let result = await group.next()!
            group.cancelAll()

            // Clean up the process
            if process.isRunning {
                process.terminate()
            }

            return result
        }
    }

    private static func parseInitializeResponse(_ data: Data) -> TestResult? {
        // MCP can send multiple lines; look for a complete JSON object with "result"
        guard let text = String(data: data, encoding: .utf8) else { return nil }

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("{") else { continue }
            guard let lineData = trimmed.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }

            if let result = obj["result"] as? [String: Any] {
                let serverInfo = result["serverInfo"] as? [String: Any]
                let name = serverInfo?["name"] as? String ?? "unknown"
                let version = serverInfo?["version"] as? String
                return .success(serverName: name, version: version)
            }

            if let error = obj["error"] as? [String: Any] {
                let message = error["message"] as? String ?? "Unknown error"
                return .failure("Server error: \(message)")
            }
        }

        return nil
    }

    // MARK: - HTTP

    private static func testHTTP(_ server: MCPServer) async -> TestResult {
        guard let urlString = server.url, let url = URL(string: urlString) else {
            return .failure("No URL configured")
        }

        let request = """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"claude-config-gui","version":"0.1.0"}}}
        """

        var urlRequest = URLRequest(url: url, timeoutInterval: 5)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = Data(request.utf8)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let headers = server.headers {
            for (k, v) in headers {
                urlRequest.setValue(v, forHTTPHeaderField: k)
            }
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure("Not an HTTP response")
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                return .failure("HTTP \(httpResponse.statusCode)")
            }
            if let result = parseInitializeResponse(data) {
                return result
            }
            return .success(serverName: "server", version: nil)
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    // MARK: - Reachability (SSE/WS)

    private static func testReachability(_ server: MCPServer) async -> TestResult {
        guard let urlString = server.url, let url = URL(string: urlString) else {
            return .failure("No URL configured")
        }

        // Just do a HEAD request to check the endpoint is reachable
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = "HEAD"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure("Not an HTTP response")
            }
            if (200...499).contains(httpResponse.statusCode) {
                return .success(serverName: "server", version: nil)
            }
            return .failure("HTTP \(httpResponse.statusCode)")
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}
