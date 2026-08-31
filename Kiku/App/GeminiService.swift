import Foundation

/// The Gemini API key, read from the app's Info.plist (populated from Config/Secrets.local.xcconfig).
/// Empty by default so the repo ships no secret — see README to add your own key.
enum GeminiDefaults {
    static var seededKey: String {
        let key = (Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String) ?? ""
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Minimal Gemini REST client for generating the weekly study recap. See FRD §3.6.
struct GeminiService {
    enum GeminiError: LocalizedError {
        case missingKey
        case badResponse
        case empty

        var errorDescription: String? {
            switch self {
            case .missingKey: return "Add a Gemini API key to enable the weekly recap (see README)."
            case .badResponse: return "Couldn't reach Gemini. Check your connection and API key."
            case .empty: return "Gemini returned an empty response."
            }
        }
    }

    var apiKey: String
    /// Stable, budget-friendly GA model (see ai.google.dev/gemini-api/docs/models).
    var model: String = "gemini-2.5-flash-lite"

    func generate(prompt: String) async throws -> String {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw GeminiError.missingKey }

        guard var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            throw GeminiError.badResponse
        }
        components.queryItems = [URLQueryItem(name: "key", value: key)]
        guard let url = components.url else { throw GeminiError.badResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RequestBody(prompt: prompt))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GeminiError.badResponse
        }

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let text = decoded.candidates?.first?.content?.parts?.first?.text, !text.isEmpty else {
            throw GeminiError.empty
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Wire types

    private struct RequestBody: Encodable {
        let contents: [Content]
        init(prompt: String) { contents = [Content(parts: [Part(text: prompt)])] }
        struct Content: Encodable { let parts: [Part] }
        struct Part: Encodable { let text: String }
    }

    private struct ResponseBody: Decodable {
        let candidates: [Candidate]?
        struct Candidate: Decodable { let content: Content? }
        struct Content: Decodable { let parts: [Part]? }
        struct Part: Decodable { let text: String? }
    }
}

/// Builds the weekly recap prompt from the user's study data.
enum WeeklyRecap {
    static func buildPrompt(sessions: [StudySession], subjects: [Subject],
                            dailyTarget: Int, now: Date = .now) -> String {
        let calendar = Calendar.current
        let weekMinutes = StudyStats.minutesThisWeek(sessions, now: now)
        let weekSessions = StudyStats.sessionsThisWeek(sessions, now: now)
        let streak = StudyStats.currentStreak(sessions, now: now)
        let daysStudied = Set(sessions
            .filter { calendar.dateInterval(of: .weekOfYear, for: now)?.contains($0.startedAt) ?? false }
            .map { calendar.startOfDay(for: $0.startedAt) }).count

        var subjectLines: [String] = []
        for subject in subjects {
            let mins = sessions
                .filter { $0.subject?.id == subject.id }
                .filter { calendar.dateInterval(of: .weekOfYear, for: now)?.contains($0.startedAt) ?? false }
                .reduce(0) { $0 + $1.focusMinutes }
            if mins > 0 { subjectLines.append("- \(subject.name): \(mins) min") }
        }

        let notes = sessions
            .filter { calendar.dateInterval(of: .weekOfYear, for: now)?.contains($0.startedAt) ?? false }
            .compactMap { $0.note.isEmpty ? nil : "• \($0.note)" }
            .prefix(10)
            .joined(separator: "\n")

        return """
        You are Kiku, a warm, thoughtful study companion for a learner studying French. \
        Write a reflective weekly recap she can genuinely learn from — like a caring mentor writing in her journal. \
        Be specific and reflective (notice patterns, not just numbers), friendly, and quietly motivating. \
        Never shame her. Use exactly these four sections, each on its own block, in this order, \
        keeping the bold titles and leading emoji EXACTLY as written:

        **📊 Your week**
        2-3 sentences that reflect on how the week actually went — weave the numbers (days studied, total time, \
        sessions, streak) into a human story about her rhythm and effort, not a dry list.

        **🌟 Bright spots**
        2-3 sentences celebrating what went well — her strongest subject, a good habit, consistency, or effort. \
        Reference her own notes when they reveal something real. Make her feel genuinely seen.

        **🌱 Room to grow**
        2-3 gentle, honest sentences on what slipped and why it might have (missed days, a neglected subject, \
        short sessions). Frame it with warmth and curiosity, never guilt.

        **🎯 Next week**
        A short intro line, then 2-3 tiny, concrete, doable goals as a list, each on its own line starting with "• ". \
        Make them realistic and encouraging.

        Rules: 160-220 words. Warm, reflective, motivating tone. A few cute emojis are welcome. \
        Use **bold** only for the four section titles. Do not add other headings or a sign-off.

        This week's data:
        - Days studied: \(daysStudied)/7
        - Total focus: \(weekMinutes) minutes across \(weekSessions) sessions
        - Current streak: \(streak) days
        - Daily target: \(dailyTarget) minutes
        Time by subject:
        \(subjectLines.isEmpty ? "- (no sessions logged this week)" : subjectLines.joined(separator: "\n"))
        Notes she wrote:
        \(notes.isEmpty ? "(none)" : notes)
        """
    }
}


