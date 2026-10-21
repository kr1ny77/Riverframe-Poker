import SwiftUI
import PokerCore

struct LessonTermBox: View {
    let term: String
    let definition: String
    let example: String
    var body: some View {
        LessonFrame(title: "Термин", symbol: "text.book.closed") {
            Text(term).font(.headline)
            Text(definition).fixedSize(horizontal: false, vertical: true)
            Text("Пример: " + example).fixedSize(horizontal: false, vertical: true).font(.subheadline).foregroundStyle(AppTheme.muted)
        }
    }
}

struct LessonMethodBox: View {
    let when: String
    let steps: [String]
    var body: some View {
        LessonFrame(title: "Метод", symbol: "list.number") {
            Text(when).fixedSize(horizontal: false, vertical: true)
            ForEach(steps, id: \.self) { step in
                Text("\((steps.firstIndex(of: step) ?? 0) + 1). \(step)").fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct LessonCalculationBox: View {
    let exercise: CatalogExercise
    let assumptions: String
    var body: some View {
        LessonFrame(title: exercise.resultKind.title, symbol: "function") {
            Text(exercise.calculation.title).font(.subheadline.weight(.medium))
            Text("Входы: конкретные карты, числа, варианты и веса показаны в условии задачи.").fixedSize(horizontal: false, vertical: true)
            Text(assumptions).fixedSize(horizontal: false, vertical: true).font(.subheadline).foregroundStyle(AppTheme.muted)
        }
        .accessibilityIdentifier("lesson.math-status")
    }
}

private struct LessonFrame<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: Content
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Measure.d12) {
            Label(title, systemImage: symbol).font(.headline).accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Measure.d16)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.radius)
            .stroke(contrast == .increased ? AppTheme.text : AppTheme.border, lineWidth: AppTheme.Measure.d1))
        .accessibilityElement(children: .contain)
    }
}

/// A static conceptual tree. Exact task-specific diagrams remain in the reused
/// exercise screens (cards, weighted ranges, probability strips and pot bars).
struct LessonDecisionDiagram: View {
    let lesson: CourseLessonID
    private var isMoneyDecision: Bool { lesson == .potOdds || lesson == .evCall }
    private var summary: String {
        isMoneyDecision
            ? "Порядок решения: уточните банк и доплату. Оцените долю банка по условию. Сравните результат с ценой колла, затем выберите ответ."
            : "Порядок решения: прочитайте известные карты и условия. Выберите определение или расчёт. Проверьте ответ и разберите каждый шаг."
    }
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Measure.d12) {
            Text("План решения").font(.headline)
            VStack(spacing: AppTheme.Measure.d8) {
                node("Условия ситуации")
                Image(systemName: "arrow.down").accessibilityHidden(true)
                node(isMoneyDecision ? "Банк и доплата" : "Карты и известные данные")
                Image(systemName: "arrow.down").accessibilityHidden(true)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: AppTheme.Measure.d8) { branches }
                    VStack(alignment: .leading, spacing: AppTheme.Measure.d8) { branches }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(summary)
            Text(summary).fixedSize(horizontal: false, vertical: true).font(.footnote).foregroundStyle(AppTheme.muted).accessibilityHidden(true)
        }
        .accessibilityIdentifier("lesson.decision-diagram")
    }
    @ViewBuilder private var branches: some View {
        node(isMoneyDecision ? "Цена колла" : "Определение")
        node(isMoneyDecision ? "Доля банка / EV" : "Расчёт")
    }
    private func node(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.medium))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppTheme.Measure.d12)
            .background(AppTheme.surfaceAlt, in: RoundedRectangle(cornerRadius: AppTheme.Measure.d8))
    }
}

struct LessonPotDiagram: View {
    let pot: Int64
    let bet: Int64
    private var summary: String {
        "Банк до ставки: \(pot). Ставка соперника: \(bet). Ваш колл: \(bet). Банк после колла: \(pot + bet + bet) виртуальных фишек."
    }
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Measure.d12) {
            Text("Как складывается банк").font(.headline)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: AppTheme.Measure.d8) { parts }
                VStack(alignment: .leading, spacing: AppTheme.Measure.d8) { parts }
            }
            Text("Итог: \(pot + bet + bet) фишек").font(.headline)
        }
        .accessibilityElement(children: .ignore).accessibilityLabel(summary)
        .accessibilityIdentifier("lesson.pot-diagram")
    }
    @ViewBuilder private var parts: some View {
        part("Банк", amount: pot)
        Image(systemName: "plus").accessibilityHidden(true)
        part("Ставка", amount: bet)
        Image(systemName: "plus").accessibilityHidden(true)
        part("Колл", amount: bet)
    }
    private func part(_ title: String, amount: Int64) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Measure.d6) {
            Text(title).font(.subheadline)
            Text(amount, format: .number).font(.title3.monospacedDigit())
        }.padding(AppTheme.Measure.d12)
            .background(AppTheme.surfaceAlt, in: RoundedRectangle(cornerRadius: AppTheme.Measure.d8))
    }
}

/// Entry and restored result for one stable catalog exercise. The original
/// exercise screen owns answer/check/explanation/save; no second attempt is made.
struct LessonTemplateView: View {
    let exercise: CatalogExercise
    let topicID: CourseTopicID
    @EnvironmentObject private var store: PracticeStore

    var body: some View {
        let guide = LessonGuide.guide(for: exercise.lesson)
        let latest = store.catalog.observations.last { $0.exerciseID == exercise.id }
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Measure.d20) {
                LessonHeader(title: exercise.title, detail: "\(topicID.rawValue) · \(exercise.lesson.title)")
                Text("Цель").font(.headline).accessibilityAddTraits(.isHeader)
                Text(guide.goal).font(.body).fixedSize(horizontal: false, vertical: true).padding(.vertical, AppTheme.Measure.d3).accessibilityIdentifier("lesson.goal")
                if let error = store.errorMessage {
                    ErrorNotice(text: error)
                    Button("Повторить загрузку") { store.reload() }.buttonStyle(SecondaryButtonStyle())
                }
                if let latest {
                    VStack(alignment: .leading, spacing: AppTheme.Measure.d12) {
                        Label(latest.isCorrect ? "Последний ответ: верно по условию." : "Последний ответ: есть ошибка.",
                              systemImage: latest.isCorrect ? "checkmark.circle" : "exclamationmark.circle")
                            .font(.headline)
                            .accessibilityIdentifier("lesson.restored-result")
                        Text(latest.date, format: .dateTime.day().month().year().hour().minute())
                            .font(.footnote).foregroundStyle(AppTheme.muted)
                        Text("Результат восстановлен из локальной истории.").font(.footnote)
                        if let next = CourseCatalog.nextExercise(after: exercise.id, in: topicID) {
                            NavigationLink { LessonTemplateView(exercise: next, topicID: topicID) } label: {
                                Label("Следующая задача: \(next.title)", systemImage: "arrow.right")
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .accessibilityIdentifier("lesson.next")
                        } else {
                            Text("Это последняя доступная задача в этой теме. Охват и точность показаны на экране темы.")
                                .fixedSize(horizontal: false, vertical: true).font(.subheadline)
                        }
                    }
                }
                Text(exercise.resultKind.title).font(.subheadline.weight(.medium))
                NavigationLink {
                    CatalogTaskDestination(exercise: exercise)
                } label: {
                    Label(latest == nil ? "Перейти к задаче" : "Решить ещё раз", systemImage: "pencil.and.list.clipboard")
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("lesson.start")
                Text("В задаче: ситуация → ваш ответ → проверка → пошаговый разбор. После сохранения вернитесь сюда к результату и следующей задаче.")
                    .font(.footnote).foregroundStyle(AppTheme.muted).fixedSize(horizontal: false, vertical: true)
                LessonTermBox(term: guide.term, definition: guide.definition, example: guide.example)
                LessonMethodBox(when: guide.when, steps: guide.steps)
                LessonCalculationBox(exercise: exercise, assumptions: guide.assumptions)
                if let question = exercise.potOddsQuestion {
                    LessonPotDiagram(pot: question.potBefore, bet: question.opponentBet)
                }
                LessonDecisionDiagram(lesson: exercise.lesson)
                Text("ID: \(exercise.id.rawValue) · редакция \(exercise.contentVersion)")
                    .font(.footnote).foregroundStyle(AppTheme.muted)
            }
            .frame(maxWidth: AppTheme.Metrics.lessonReadingWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(AppTheme.Measure.d16)
        }
        .lessonCanvas().navigationTitle("Урок")
    }
}

struct CatalogTaskDestination: View {
    let exercise: CatalogExercise
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Group {
        switch exercise.lesson {
        case .combinations: HandComparisonLessonView(exerciseKey: exercise.legacyKey)
        case .outs: OutsLessonView(exerciseKey: exercise.legacyKey)
        case .potOdds:
            if let question = exercise.potOddsQuestion {
                PotOddsExerciseView(question: question, onContinue: { dismiss() })
            } else { ErrorNotice(text: "Задание отсутствует в каталоге.") }
        case .knownEquity: EquityLessonView(exerciseKey: exercise.legacyKey)
        case .positions: PositionLessonView(exerciseKey: exercise.legacyKey)
        case .rangeEquity: RangeEquityLessonView(exerciseKey: exercise.legacyKey)
        case .evCall: EVCallLessonView(exerciseKey: exercise.legacyKey)
        case .blockers: BlockerLessonView(exerciseKey: exercise.legacyKey)
        }
        }
        .safeAreaInset(edge: .top) {
            Text(exercise.resultKind.title).font(.footnote.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppTheme.Measure.d12).background(AppTheme.surface)
                .accessibilityIdentifier("lesson.task-math-status")
        }
    }
}
