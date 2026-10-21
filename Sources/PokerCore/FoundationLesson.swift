import Foundation

public enum FoundationPurpose: String, Codable, CaseIterable, Sendable {
    case concept, transfer, boundary
    public var title: String {
        switch self { case .concept: "Понятие"; case .transfer: "Изменённые условия"; case .boundary: "Граница применения" }
    }
}

public enum FoundationResponse: Codable, Equatable, Sendable {
    case number(Double), choice(Int)
    public var isValid: Bool {
        switch self { case .number(let n): n.isFinite; case .choice(let n): n >= 0 }
    }
}

public enum FoundationAnswer: Sendable {
    case number(value: Double, tolerance: Double)
    case choice(options: [String], correct: Int)
    public var correctResponse: FoundationResponse {
        switch self { case .number(let value, _): .number(value); case .choice(_, let index): .choice(index) }
    }
    public var tolerance: Double {
        switch self { case .number(_, let value): value; case .choice: 0 }
    }
    public func accepts(_ response: FoundationResponse) -> Bool {
        switch (self, response) {
        case (.number(let expected, let tolerance), .number(let value)): value.isFinite && abs(value - expected) <= tolerance
        case (.choice(let options, let expected), .choice(let index)): options.indices.contains(index) && index == expected
        default: false
        }
    }
}

public struct FoundationDiagramRow: Sendable {
    public let label: String
    public let value: String
    public init(_ label: String, _ value: String) { self.label = label; self.value = value }
}

/// Original teaching content plus typed Swift grading; text is never evaluated.
public struct FoundationExercise: Identifiable, Sendable {
    public let id: CatalogExerciseID
    public let contentVersion: Int = 1
    public let topicID: CourseTopicID
    public let title: String
    public let purpose: FoundationPurpose
    public let context: [String]
    public let question: String
    public let answer: FoundationAnswer
    public let explanation: [String]
    public let typicalError: String
    public let term: String
    public let definition: String
    public let example: String
    public let method: String
    public let assumptions: String
    public let resultKind: LessonResultKind
    public let diagram: [FoundationDiagramRow]
    public let chart: [FoundationDiagramRow]
    public let cards: [Card]
    public let simulation: CourseMonteCarloReport?
    public let researchAnchor: String
    public init(id: String, topicID: CourseTopicID, title: String, purpose: FoundationPurpose,
                context: [String], question: String, answer: FoundationAnswer, explanation: [String],
                typicalError: String, term: String, definition: String, example: String,
                method: String, assumptions: String, resultKind: LessonResultKind = .exact,
                diagram: [FoundationDiagramRow] = [], chart: [FoundationDiagramRow] = [], cards: [Card] = [], simulation: CourseMonteCarloReport? = nil, researchAnchor: String) {
        self.id = .init(rawValue: id); self.topicID = topicID; self.title = title; self.purpose = purpose
        self.context = context; self.question = question; self.answer = answer; self.explanation = explanation
        self.typicalError = typicalError; self.term = term; self.definition = definition; self.example = example
        self.method = method; self.assumptions = assumptions; self.resultKind = resultKind
        self.diagram = diagram; self.chart = chart; self.cards = cards; self.simulation = simulation; self.researchAnchor = researchAnchor
    }
}

public enum FoundationLesson {
    /// Frozen revision-2 content remains available to compatibility checks.
    public static let v2Exercises: [FoundationExercise] = rulesExercises + remainingExercises
    public static let intermediateExercises: [FoundationExercise] = estimationExercises + preflopExercises + rangesPostflopExercises
    public static let exercises: [FoundationExercise] = v2Exercises + intermediateExercises
    public static func exercise(_ id: CatalogExerciseID) -> FoundationExercise? {
        exercises.first { $0.id == id }
    }
}

public struct FoundationAttempt: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let exerciseID: CatalogExerciseID
    public let contentVersion: Int
    public let response: FoundationResponse
    public let expected: FoundationResponse
    public let tolerance: Double
    public let isCorrect: Bool
    public init(exercise: FoundationExercise, response: FoundationResponse, id: UUID = UUID(), date: Date = Date()) {
        self.id = id; self.date = date; exerciseID = exercise.id; contentVersion = exercise.contentVersion
        self.response = response; expected = exercise.answer.correctResponse; tolerance = exercise.answer.tolerance
        isCorrect = exercise.answer.accepts(response)
    }
    public var isValid: Bool {
        guard !exerciseID.rawValue.isEmpty, contentVersion > 0, date.timeIntervalSinceReferenceDate.isFinite,
              response.isValid, expected.isValid, tolerance.isFinite, tolerance >= 0 else { return false }
        // Known revisions have a frozen typed key. Unknown revisions stay in the
        // archive, and the catalog quarantines them from current coverage.
        if let exercise = FoundationLesson.exercise(exerciseID), exercise.contentVersion == contentVersion {
            guard expected == exercise.answer.correctResponse, tolerance == exercise.answer.tolerance else { return false }
            switch (exercise.answer, response) {
            case (.number, .number): break
            case (.choice(let options, _), .choice(let index)):
                guard options.indices.contains(index) else { return false }
            default: return false
            }
        }
        switch (response, expected) {
        case (.number(let actual), .number(let correct)): return isCorrect == (abs(actual - correct) <= tolerance)
        case (.choice(let actual), .choice(let correct)): return tolerance == 0 && isCorrect == (actual == correct)
        default: return false
        }
    }
}
