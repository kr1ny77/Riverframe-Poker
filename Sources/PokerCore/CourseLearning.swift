import Foundation

/// Категория задания, возможная причина ошибки. Это учебная классификация ответа,
/// а не вывод о когнитивной причине ученика.
public enum LearningErrorKind: String, Codable, CaseIterable, Sendable {
    case rules
    case arithmetic
    case rangeModel
    case modelBoundary
    case attention
    case unspecified

    public var title: String {
        switch self {
        case .rules: "Правила и определения"
        case .arithmetic: "Арифметика и единицы"
        case .rangeModel: "Диапазон и условная модель"
        case .modelBoundary: "Граница применимости модели"
        case .attention: "Внимание к условию"
        case .unspecified: "Неуточнённая категория"
        }
    }

    public var inferredLabel: String {
        "\(title): категория задания, возможная причина"
    }
}

/// Сохранённая учебная пометка для конкретной попытки. UUID принадлежит исходной попытке,
/// поэтому повторная запись не создаёт вторую диагностику.
public struct LearningDiagnostic: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let exerciseID: CatalogExerciseID
    public let date: Date
    public let kind: LearningErrorKind

    public init(sourceAttemptID: UUID, exerciseID: CatalogExerciseID, date: Date, kind: LearningErrorKind) {
        id = sourceAttemptID
        self.exerciseID = exerciseID
        self.date = date
        self.kind = kind
    }

    public init(id: UUID, exerciseID: CatalogExerciseID, date: Date, kind: LearningErrorKind) {
        self.init(sourceAttemptID: id, exerciseID: exerciseID, date: date, kind: kind)
    }

    public var isValid: Bool {
        !exerciseID.rawValue.isEmpty && date.timeIntervalSinceReferenceDate.isFinite
    }
}

/// Метрики опираются на первые ответы каждого E-ID. Повтор одного задания повышает число
/// попыток, но не имитирует перенос навыка на новый шаблон.
public struct LearningMetrics: Sendable {
    public let attempts: Int
    public let distinctTemplates: Int
    public let firstTemplateAttempts: Int
    public let firstTemplateCorrect: Int
    public let firstTemplateAccuracy: Double?
    public let lastChecked: Date?
    public let smallSample: Bool

    public init(progress: CatalogTopicProgress) {
        let ordered = Self.ordered(progress.observations)
        let firstAttempts = Dictionary(grouping: ordered, by: \.exerciseID).values.compactMap(\.first)
        attempts = ordered.count
        distinctTemplates = Set(ordered.map(\.exerciseID)).count
        firstTemplateAttempts = firstAttempts.count
        firstTemplateCorrect = firstAttempts.filter(\.isCorrect).count
        firstTemplateAccuracy = firstAttempts.isEmpty ? nil : Double(firstTemplateCorrect) / Double(firstAttempts.count)
        lastChecked = ordered.last?.date
        smallSample = firstTemplateAttempts < 20
    }

    /// Полный проектный критерий: ≥90 % на 20 новых заданиях, ноль критических ошибок
    /// в последних пяти и ≥80 % на 10 новых заданиях через семь дней.
    public static let projectCriterion = "Проектный критерий курса: ≥90 % на 20 новых заданиях, ноль критических ошибок в последних пяти задачах и ≥80 % на 10 новых заданиях через 7 дней. Он описывает дизайн оценки и требует педагогической проверки; профессиональный уровень им не подтверждается."

    /// В имеющейся локальной истории отсутствует экспертная оценка критичности и отдельный
    /// контрольный набор через семь дней, поэтому показатель остаётся учебной подсказкой.
    public var projectCriterionStatus: String {
        guard firstTemplateAttempts >= 20 else {
            return "Проектный критерий пока не измерен: есть \(firstTemplateAttempts) новых шаблонов из 20."
        }
        return "Проверен только первичный компонент; отложенная и экспертная проверка предстоит."
    }

    private static func ordered(_ observations: [CatalogObservation]) -> [CatalogObservation] {
        observations.sorted { lhs, rhs in
            lhs.date == rhs.date ? lhs.id.uuidString < rhs.id.uuidString : lhs.date < rhs.date
        }
    }
}

public struct CourseReviewItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let topicID: CourseTopicID
    public let kind: LearningErrorKind
    public let dueDate: Date
    /// 0, 1, 2 and 3 correspond to waits of 1, 3, 7 and 21 days.
    public let stage: Int
    /// Suggested different E-ID. It is nil only when this topic has no alternative task.
    public let exerciseID: CatalogExerciseID?
    public let sourceAttemptID: UUID
}

public enum CourseLearning {
    /// Exact elapsed durations make replay independent of the local calendar and DST.
    public static let reviewIntervals: [TimeInterval] = [1, 3, 7, 21].map { Double($0 * 86_400) }

    /// Produces a conservative category from typed exercise metadata. The label names a
    /// task category and a possible cause; it never diagnoses the learner.
    public static func inferredDiagnostics(catalog: CourseCatalogSnapshot) -> [LearningDiagnostic] {
        catalog.observations.compactMap { observation in
            guard !observation.isCorrect else { return nil }
            return LearningDiagnostic(
                sourceAttemptID: observation.id,
                exerciseID: observation.exerciseID,
                date: observation.date,
                kind: inferredKind(for: observation.exerciseID)
            )
        }
    }

    public static func inferredKind(for exerciseID: CatalogExerciseID) -> LearningErrorKind {
        if let exercise = FoundationLesson.exercise(exerciseID) {
            if exercise.purpose == .boundary { return .modelBoundary }
            if exercise.topicID == .t55 || exercise.topicID == .t59 { return .attention }
            switch exercise.resultKind {
            case .exact, .monteCarlo: return .arithmetic
            case .conditionalModel, .verifiedTable: return .rangeModel
            case .definitions: return .rules
            }
        }
        guard let exercise = CourseCatalog.exercises.first(where: { $0.id == exerciseID }) else {
            return .unspecified
        }
        switch exercise.calculation {
        case .exactArithmetic, .exactEnumeration: return .arithmetic
        case .conditionalModel: return .rangeModel
        case .definitions: return .rules
        }
    }
}

/// Pure projection over saved attempts. It has no store, chip balance or UI dependency.
public struct CourseLearningSnapshot: Sendable {
    public let catalog: CourseCatalogSnapshot
    public let diagnostics: [LearningDiagnostic]
    public let now: Date
    public let reviews: [CourseReviewItem]

    private let reviewExclusions: [String: CatalogExerciseID]

    public init(catalog: CourseCatalogSnapshot, diagnostics: [LearningDiagnostic], now: Date) {
        self.catalog = catalog
        self.now = now

        var observationByID: [UUID: CatalogObservation] = [:]
        for observation in catalog.observations.sorted(by: Self.observationOrder) where observationByID[observation.id] == nil {
            observationByID[observation.id] = observation
        }
        let validExplicit = diagnostics.filter { diagnostic in
            diagnostic.isValid
                && observationByID[diagnostic.id]?.isCorrect == false
                && observationByID[diagnostic.id]?.exerciseID == diagnostic.exerciseID
                && observationByID[diagnostic.id]?.date == diagnostic.date
        }
        var explicitByID: [UUID: LearningDiagnostic] = [:]
        for diagnostic in validExplicit.sorted(by: Self.diagnosticOrder) where explicitByID[diagnostic.id] == nil {
            explicitByID[diagnostic.id] = diagnostic
        }
        let inferred = CourseLearning.inferredDiagnostics(catalog: catalog)
        let resolvedDiagnostics = catalog.observations.compactMap { observation -> LearningDiagnostic? in
            guard !observation.isCorrect else { return nil }
            return explicitByID[observation.id]
                ?? inferred.first(where: { $0.id == observation.id })
        }
        self.diagnostics = resolvedDiagnostics

        let construction = Self.buildReviews(catalog: catalog, diagnostics: resolvedDiagnostics)
        reviews = construction.items
        reviewExclusions = construction.exclusions
    }

    /// Due repetitions take precedence. Future repetitions never suppress an unseen task.
    public func recommendation(in exerciseIDs: Set<CatalogExerciseID>) -> CatalogExerciseID? {
        let due = reviews.filter { $0.dueDate <= now }.sorted(by: Self.reviewOrder)
        for review in due {
            if let suggested = review.exerciseID, exerciseIDs.contains(suggested) { return suggested }
            if let excluded = reviewExclusions[review.id],
               let alternative = Self.nextExercise(topic: review.topicID, excluding: excluded,
                                                   observed: catalog.observations, allowed: exerciseIDs) {
                return alternative
            }
        }

        let attempted = Set(catalog.observations.map(\.exerciseID))
        return Self.orderedExerciseIDs(in: exerciseIDs).first { !attempted.contains($0) }
    }

    public func next(in exerciseIDs: Set<CatalogExerciseID>) -> CatalogExerciseID? {
        recommendation(in: exerciseIDs)
    }

    private static func buildReviews(catalog: CourseCatalogSnapshot,
                                     diagnostics: [LearningDiagnostic]) -> (items: [CourseReviewItem], exclusions: [String: CatalogExerciseID]) {
        let topicIDs = CourseTopicID.allCases
        var items: [CourseReviewItem] = []
        var exclusions: [String: CatalogExerciseID] = [:]

        for topicID in topicIDs {
            let relevantIDs = CourseCatalog.exerciseIDs(for: topicID)
            for kind in LearningErrorKind.allCases {
                let relevantDiagnostics = diagnostics.filter { relevantIDs.contains($0.exerciseID) && $0.kind == kind }.sorted(by: diagnosticOrder)
                guard let latestWrong = relevantDiagnostics.last else { continue }

                let events = catalog.observations.filter { relevantIDs.contains($0.exerciseID) }.sorted(by: observationOrder)
                var stage = 0
                var checkpointDate = latestWrong.date
                var previousExerciseID = latestWrong.exerciseID
                var dueDate = checkpointDate.addingTimeInterval(CourseLearning.reviewIntervals[stage])

                for event in events where event.date > latestWrong.date || (event.date == latestWrong.date && event.id.uuidString > latestWrong.id.uuidString) {
                    guard event.isCorrect, event.date >= dueDate, event.exerciseID != previousExerciseID else { continue }
                    if stage == CourseLearning.reviewIntervals.count - 1 {
                        stage = CourseLearning.reviewIntervals.count
                        break
                    }
                    previousExerciseID = event.exerciseID
                    checkpointDate = event.date
                    stage += 1
                    dueDate = checkpointDate.addingTimeInterval(CourseLearning.reviewIntervals[stage])
                }

                guard stage < CourseLearning.reviewIntervals.count else { continue }
                let itemID = "\(topicID.rawValue)-\(kind.rawValue)-\(latestWrong.id.uuidString)-\(stage)"
                let suggestion = nextExercise(topic: topicID, excluding: previousExerciseID,
                                              observed: catalog.observations, allowed: relevantIDs)
                items.append(CourseReviewItem(id: itemID, topicID: topicID, kind: latestWrong.kind,
                                              dueDate: dueDate, stage: stage, exerciseID: suggestion,
                                              sourceAttemptID: latestWrong.id))
                exclusions[itemID] = previousExerciseID
            }
        }
        return (items.sorted(by: reviewOrder), exclusions)
    }

    private static func nextExercise(topic: CourseTopicID, excluding: CatalogExerciseID,
                                     observed: [CatalogObservation], allowed: Set<CatalogExerciseID>) -> CatalogExerciseID? {
        let candidates = orderedExerciseIDs(in: CourseCatalog.exerciseIDs(for: topic).intersection(allowed)).filter { $0 != excluding }
        guard !candidates.isEmpty else { return nil }
        let attempted = Set(observed.map(\.exerciseID))
        return candidates.first { !attempted.contains($0) } ?? candidates.first
    }

    private static func orderedExerciseIDs(in allowed: Set<CatalogExerciseID>) -> [CatalogExerciseID] {
        var ordered: [CatalogExerciseID] = []
        var seen = Set<CatalogExerciseID>()
        for topic in CourseCatalog.topics {
            let topicExercises = CourseCatalog.exercises(for: topic.id).map(\.id)
                + CourseCatalog.foundations(for: topic.id).map(\.id)
            for id in topicExercises where allowed.contains(id) && seen.insert(id).inserted {
                ordered.append(id)
            }
        }
        // Unknown future IDs retain deterministic ordering without changing published order.
        ordered.append(contentsOf: allowed.subtracting(seen).sorted { $0.rawValue < $1.rawValue })
        return ordered
    }

    private static func observationOrder(_ lhs: CatalogObservation, _ rhs: CatalogObservation) -> Bool {
        lhs.date == rhs.date ? lhs.id.uuidString < rhs.id.uuidString : lhs.date < rhs.date
    }

    private static func diagnosticOrder(_ lhs: LearningDiagnostic, _ rhs: LearningDiagnostic) -> Bool {
        lhs.date == rhs.date ? lhs.id.uuidString < rhs.id.uuidString : lhs.date < rhs.date
    }

    private static func reviewOrder(_ lhs: CourseReviewItem, _ rhs: CourseReviewItem) -> Bool {
        if lhs.dueDate != rhs.dueDate { return lhs.dueDate < rhs.dueDate }
        if lhs.sourceAttemptID.uuidString != rhs.sourceAttemptID.uuidString {
            return lhs.sourceAttemptID.uuidString < rhs.sourceAttemptID.uuidString
        }
        return lhs.topicID.rawValue < rhs.topicID.rawValue
    }
}

public extension CourseCatalogSnapshot {
    /// Union of linked tasks prevents shared E-IDs from inflating level coverage.
    func progress(in level: CourseLevel) -> CatalogTopicProgress {
        let moduleIDs = Set(CourseCatalog.modules.filter { $0.level == level }.map(\.id))
        let topicIDs = Set(CourseCatalog.topics.filter { moduleIDs.contains($0.moduleID) }.map(\.id))
        let ids = Set(CourseCatalog.exercises.filter { !topicIDs.isDisjoint(with: $0.topicIDs) }.map(\.id)
            + CourseCatalog.foundationExercises.filter { topicIDs.contains($0.topicID) }.map(\.id))
        return CatalogTopicProgress(exerciseIDs: ids, observations: observations.filter { ids.contains($0.exerciseID) })
    }
}
