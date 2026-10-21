import Foundation

/// Labels describe the evidence behind a result. Tables require a named source;
/// sampled estimates require a sample count and seed in the exercise itself.
public enum LessonResultKind: String, CaseIterable, Sendable {
    case exact, monteCarlo, conditionalModel, verifiedTable, definitions
    public var title: String {
        switch self {
        case .exact: "Точный результат"
        case .monteCarlo: "Оценка Монте-Карло"
        case .conditionalModel: "Условная модель"
        case .verifiedTable: "Проверенная таблица"
        case .definitions: "Определения и правила"
        }
    }
}

/// Presentation metadata; typed lesson calculators remain the grading authority.
public struct LessonGuide: Sendable {
    public let goal: String
    public let term: String
    public let definition: String
    public let example: String
    public let when: String
    public let steps: [String]
    public let assumptions: String

    public static func guide(for lesson: CourseLessonID) -> Self {
        switch lesson {
        case .combinations:
            .init(goal: "Выберите лучшую пятёрку и сравните две открытые руки.",
                  term: "Лучшая пятёрка", definition: "Пять карт, образующих старшую комбинацию из доступных семи.",
                  example: "В стрите A–2–3–4–5 туз играет как единица.",
                  when: "Применяйте на вскрытии, когда известны руки и пять общих карт.",
                  steps: ["Составьте пятёрки из семи карт.", "Сравните категорию и старшие ранги.", "При равенстве проверьте кикеры и возможность ничьей."],
                  assumptions: "Две открытые руки, готовая доска. Ставки и стеки в сравнении комбинаций не участвуют.")
        case .outs:
            .init(goal: "Различите число аутов и вероятность собрать флеш к выбранному сроку.",
                  term: "Аут", definition: "Неизвестная карта, которая завершает заданную комбинацию.",
                  example: "При четырёх известных картах одной масти остаётся девять карт этой масти.",
                  when: "Сначала задайте событие и срок: следующая карта или обе оставшиеся улицы.",
                  steps: ["Исключите известные карты.", "Отметьте карты, завершающие флеш.", "Посчитайте подходящие исходы для указанного срока."],
                  assumptions: "Событие — собрать флеш. Карты соперника неизвестны; победа над его рукой требует отдельного расчёта.")
        case .potOdds:
            .init(goal: "Найдите долю банка для оплаты колла.",
                  term: "Pot odds", definition: "Отношение доплаты за колл к банку после этого колла.",
                  example: "Банк 100, соперник ставит 50: доплата 50, итоговый банк 200.",
                  when: "Сопоставляйте цену колла со средней долей банка при заданных условиях.",
                  steps: ["Назовите банк до ставки и размер ставки соперника.", "Добавьте ставку соперника и свою доплату.", "Разделите доплату на итоговый банк и переведите в проценты."],
                  assumptions: "Один банк, без рейка и будущих ставок. Equity и вероятность собрать комбинацию имеют разные значения.")
        case .knownEquity:
            .init(goal: "Определите среднюю долю банка двух известных рук к риверу.",
                  term: "Equity", definition: "Средняя доля банка по всем учитываемым исходам, включая делёж.",
                  example: "При ничьей двух игроков каждый получает половину общего банка.",
                  when: "Применяйте полный перебор при известных руках и небольшом числе оставшихся карт.",
                  steps: ["Удалите известные карты из колоды.", "Переберите допустимые продолжения доски.", "Сложите победы и половины ничьих, затем разделите на число исходов."],
                  assumptions: "Обе руки известны. Один общий банк; ставки завершены; все допустимые продолжения равновероятны.")
        case .positions:
            .init(goal: "Различите позиции, порядок действий и свойства стартовых рук в ситуации 6-max.",
                  term: "Позиция", definition: "Место в порядке действий относительно баттона и других участников.",
                  example: "На префлопе первым обычно действует UTG; после флопа порядок начинается слева от баттона.",
                  when: "Уточняйте улицу, баттон и уже совершённые действия перед оценкой стартовой руки.",
                  steps: ["Найдите баттон и блайнды.", "Уточните улицу и активные места.", "Прочитайте доступную информацию и выберите ответ по условию."],
                  assumptions: "Шесть мест. Вопросы проверяют порядок и свойства рук; стратегические диапазоны требуют отдельной модели.")
        case .rangeEquity:
            .init(goal: "Посчитайте equity против заданных рук с учебными весами.",
                  term: "Вес руки", definition: "Относительная частота конкретной руки в заданной модели диапазона.",
                  example: "Вес 3 против веса 1 означает три части массы против одной.",
                  when: "Используйте взвешивание, когда условие задаёт несколько возможных рук соперника.",
                  steps: ["Проверьте руки, известные карты и веса.", "Переберите продолжения для каждой допустимой руки.", "Сложите взвешенные доли банка и нормируйте на сумму весов."],
                  assumptions: "Малый фиксированный диапазон; один соперник, без будущих ставок. Веса заданы условием, точный перебор действует внутри этой модели.")
        case .evCall:
            .init(goal: "Сравните колл и пас на ривере по ожидаемому изменению фишек.",
                  term: "EV решения", definition: "Среднее изменение фишек при повторении ситуации с указанными весами исходов.",
                  example: "Пас сохраняет оставшийся стек; уже вложенные фишки относятся к прошлым решениям.",
                  when: "Сравнивайте решения от одного момента времени при готовой доске и заданном диапазоне.",
                  steps: ["Зафиксируйте банк, доплату и руки с весами.", "Определите выплату при победе, ничьей и поражении.", "Взвесьте изменения фишек и сравните с пасом."],
                  assumptions: "Ривер, один общий банк, заданные руки и веса, без рейка и будущих ставок. Это условная модель диапазона.")
        case .blockers:
            .init(goal: "Удалите невозможные комбинации и пересчитайте оставшуюся массу диапазона.",
                  term: "Блокер", definition: "Известная карта, исключающая руки соперника с той же физической картой.",
                  example: "Известный туз уменьшает число доступных комбинаций AA.",
                  when: "Удаляйте пересечения перед подсчётом комбинаций и нормировкой весов.",
                  steps: ["Перечислите исходные комбинации.", "Исключите пересечения с собственными картами и доской один раз.", "Пересчитайте количество или взвешенную долю оставшихся рук."],
                  assumptions: "Карты и исходный список заданы. В заданиях с диапазоном роли value/bluff и веса являются учебными допущениями.")
        }
    }
}

public extension CatalogExercise {
    var resultKind: LessonResultKind {
        if lesson == .positions { return .definitions }
        if lesson == .rangeEquity || lesson == .evCall { return .conditionalModel }
        if lesson == .blockers, BlockerQuestion.examples.first(where: { $0.id == legacyKey })?.isRangeModel == true { return .conditionalModel }
        return .exact
    }
}

public extension CourseCatalog {
    static func nextExercise(after id: CatalogExerciseID, in topic: CourseTopicID) -> CatalogExercise? {
        let tasks = exercises(for: topic)
        guard let index = tasks.firstIndex(where: { $0.id == id }), index + 1 < tasks.count else { return nil }
        return tasks[index + 1]
    }
}

public extension CourseCatalogSnapshot {
    /// Union of exercise IDs prevents shared topics from inflating course/module coverage.
    var overallProgress: CatalogTopicProgress {
        scopedProgress(ids: Set(CourseCatalog.exercises.map(\.id)))
    }
    func progress(in module: CourseModuleID) -> CatalogTopicProgress {
        let topics = Set(CourseCatalog.topics.filter { $0.moduleID == module }.map(\.id))
        let ids = Set(CourseCatalog.exercises.filter { !topics.isDisjoint(with: $0.topicIDs) }.map(\.id))
        return scopedProgress(ids: ids)
    }
    private func scopedProgress(ids: Set<CatalogExerciseID>) -> CatalogTopicProgress {
        CatalogTopicProgress(exerciseIDs: ids, observations: observations.filter { ids.contains($0.exerciseID) })
    }
}
