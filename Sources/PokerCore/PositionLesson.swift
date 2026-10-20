import Foundation

public enum PositionLessonError: Error { case invalidSeat, invalidAnswer }

public enum SixMaxPosition: String, CaseIterable, Codable, Sendable {
    case utg="UTG", hj="HJ", co="CO", btn="BTN", sb="SB", bb="BB"
    public var title: String {
        switch self {
        case .utg: "UTG · первый после BB"
        case .hj: "HJ · перед CO"
        case .co: "CO · перед кнопкой"
        case .btn: "BTN · кнопка дилера"
        case .sb: "SB · малый блайнд"
        case .bb: "BB · большой блайнд"
        }
    }
    public static let clockwiseFromButton: [Self] = [.btn,.sb,.bb,.utg,.hj,.co]
    public static let preflopOrder: [Self] = [.utg,.hj,.co,.btn,.sb,.bb]
    public static let postflopOrder: [Self] = [.sb,.bb,.utg,.hj,.co,.btn]
    public static func at(seat:Int,button:Int) throws -> Self {
        guard (0..<6).contains(seat), (0..<6).contains(button) else { throw PositionLessonError.invalidSeat }
        return clockwiseFromButton[(seat-button+6)%6]
    }
}

public struct PositionQuestion: Identifiable, Sendable {
    public let id: String
    public let button: Int
    public let heroSeat: Int
    public let context: String
    public let hands: [[Card]]
    public let prompt: String
    public let choices: [String]
    public let correctIndex: Int
    public let explanation: String
    public let recognition: Bool
}

public enum PositionLesson {
    public static let conditions = "Учебная модель: NLHE cash, 6 мест, эффективный стек 100 BB, блайнды 0,5/1 BB, анте 0, рейк 0. Ситуации до флопа; общих карт пока нет. Диапазоны соперников не заданы."
    public static let scope = "Ответы относятся к показанным условиям и проверяют понятия. Выбор fold/call/raise требует диапазонов, цены действия и модели будущих улиц."
    public static let introduction: [String] = [
        "Позиция отсчитывается от кнопки дилера D. Здесь все шесть мест заняты; на следующую раздачу кнопка перемещается на одно место по часовой стрелке.",
        "От кнопки по часовой стрелке: BTN → SB → BB → UTG → HJ → CO. В этом модуле раннее место называется UTG, следующее — HJ; в других материалах названия могут отличаться.",
        "Первый круг до флопа: UTG → HJ → CO → BTN → SB → BB. Пропускаем сфолдивших и all-in игроков. После повышения очередь возвращается к тем, кому нужно ответить; BB сохраняет право повышения, если до него только уравнивали.",
        "Первый ход каждой улицы после флопа: первое участвующее место слева от BTN. При всех активных местах порядок SB → BB → UTG → HJ → CO → BTN. Пропускаем fold/all-in; повышение может снова открыть ответы. BTN действует после остальных активных соперников.",
        "Положение относительно соперника: CO действует раньше BTN после флопа, а BTN действует позже BB. Позднее место даёт сведения об уже сделанных действиях. В упражнении учитываем конкретных оставшихся игроков.",
        "Стартовая рука — две карманные карты. Пара: одинаковый ранг. Suited (s): одна масть; offsuit (o): разные масти. Старшие карты, масть и связность описывают разные свойства. Общая пригодность руки зависит от позиции, диапазонов, стеков и стоимости входа.",
        "RFI/open-raise — первое повышение после фолдов до игрока. После повышения соперника рассматриваем ответ на открытие; следующее повышение называется 3-bet. Лимп — вход коллом большого блайнда до первого повышения. Эти ветви требуют разных исходных данных.",
        "Учебный материал v1, проверен 17.10.2026. Определения: PokerStars Learn — Poker Positions Explained и Opening the Pot. Стратегические таблицы в модуль не импортированы."
    ]
    public static let sources: [(title:String,url:String)] = [
        ("PokerStars Learn · Poker Positions Explained","https://www.pokerstars.com/poker/learn/lesson/position/"),
        ("PokerStars Learn · Opening the Pot","https://www.pokerstars.com/poker/learn/lesson/opening-the-pot/")
    ]
    public static let questions: [PositionQuestion] = {
        let seats=[(2,5),(1,5),(4,3),(3,3),(5,0),(0,2)]
        var result=zip(SixMaxPosition.preflopOrder,seats).map { position,pair in
            PositionQuestion(id:"position-v1-recognize-\(position.rawValue)",button:pair.0,heroSeat:pair.1,
                context:"Все места заняты. Кнопка D у места \(pair.0+1), Hero на месте \(pair.1+1). Определяем место до действий.",hands:[],
                prompt:"Какая позиция у Hero?",choices:SixMaxPosition.preflopOrder.map(\.rawValue),
                correctIndex:SixMaxPosition.preflopOrder.firstIndex(of:position)!,
                explanation:"От D идём по часовой стрелке: BTN, SB, BB, UTG, HJ, CO. Место \(pair.1+1) соответствует \(position.rawValue).",
                recognition:true)
        }
        result += [
            .init(id:"position-v1-preflop",button:0,heroSeat:3,context:"Новая раздача. SB внёс 0,5 BB, BB — 1 BB. Банк 1,5 BB. Все ещё участвуют.",hands:[],prompt:"Кто первым принимает решение до флопа?",choices:["UTG","BTN","SB"],correctIndex:0,explanation:"В 6-max первый игрок слева от BB — UTG. Внесённые блайнды уже находятся в банке; действия UTG открывают первый круг торговли.",recognition:false),
            .init(id:"position-v1-postflop",button:0,heroSeat:0,context:"Планируем порядок после флопа, если останутся BTN и BB. Остальные сфолдили. BTN повысил до 2,5 BB, BB уравнял; банк 5,5 BB. Стеки по 97,5 BB за спиной.",hands:[],prompt:"Кто сделает первый ход на флопе?",choices:["BTN","BB","UTG"],correctIndex:1,explanation:"Из оставшихся участников первым слева от кнопки находится BB. BTN будет действовать после BB. Сфолдившие SB, UTG, HJ и CO пропускаются.",recognition:false),
            .init(id:"position-v1-suited",button:0,heroSeat:0,context:"Hero BTN. UTG, HJ и CO сфолдили. Банк 1,5 BB; за Hero ещё SB и BB. Сравниваем два альтернативных варианта руки.",hands:[[Card(id:12),Card(id:11)],[Card(id:25),Card(id:37)]],prompt:"Какой вариант одномастный (suited)?",choices:["Вариант A: A♠ K♠","Вариант B: A♥ K♦","Оба варианта одномастные"],correctIndex:0,explanation:"У A обе карты пики; у B масти различаются. До BTN все сфолдили, поэтому возможное первое повышение относится к RFI. Признак одной масти описывает руку; действие выбирается по полной модели.",recognition:false),
            .init(id:"position-v1-kicker",button:0,heroSeat:5,context:"Hero CO. UTG повысил до 2,5 BB, HJ сфолдил. Банк 4 BB; за Hero BTN, SB и BB. Сравниваем A♠Q♠ и A♥J♥ как альтернативы.",hands:[[Card(id:12),Card(id:10)],[Card(id:25),Card(id:22)]],prompt:"При одинаковой паре тузов, когда в лучших пяти играет карманный кикер Q/J и старших общих кикеров нет, у какого варианта кикер выше?",choices:["A♥ J♥","A♠ Q♠","Кикеры равны"],correctIndex:1,explanation:"Q выше J: при заданном сравнении A-Q превосходит A-J по кикеру. Перед CO уже было повышение UTG: это ситуация ответа на открытие. Для прибыльности колла нужны диапазон UTG и дальнейшая модель; свойство кикера само по себе этого не определяет.",recognition:false),
            .init(id:"position-v1-prior-actions",button:0,heroSeat:0,context:"Hero BTN с K♠J♥. Ситуация A: UTG/HJ/CO fold, банк 1,5 BB. Ситуация B: UTG raise-to 2,5 BB, HJ 3-bet до 8 BB, CO fold; банк 12 BB. SB/BB ещё не действовали. Hero в обеих ситуациях имеет 100 BB.",hands:[[Card(id:11),Card(id:22)]],prompt:"Как сравнить требования к решению Hero?",choices:["Одна рука и позиция задают одно действие в обеих ситуациях","Открытие банка и ответ на 3-bet требуют разных диапазонов и цен действия","KJ всегда требует all-in"],correctIndex:1,explanation:"В A Hero может первым повысить. В B перед ним уже два повышения; для анализа нужна модель ответа на 3-bet с ценой входа 8 BB и возможными ответами UTG и блайндов. Одинаковые карты и BTN сохраняют свойства руки, а линия и диапазоны меняют задачу.",recognition:false),
            .init(id:"position-v1-relative",button:0,heroSeat:0,context:"Сравниваем K♠J♥ в двух линиях. A: Hero CO raise-to 2,5 BB, BTN call, SB/BB fold; банк 6,5 BB. B: Hero BTN raise-to 2,5 BB, BB call, остальные fold; банк 5,5 BB. У обоих оставшихся игроков по 97,5 BB; будущая доска неизвестна.",hands:[[Card(id:11),Card(id:22)]],prompt:"В какой ситуации Hero будет действовать после соперника на постфлопе?",choices:["A: CO против BTN","B: BTN против BB","В обеих ситуациях"],correctIndex:1,explanation:"В A BTN находится позже CO: Hero действует первым. В B BB действует перед BTN: Hero получает позицию. Преимущество порядка действий зависит от оставшегося соперника; порядок определяют позиции оставшихся участников.",recognition:false)
        ]
        return result
    }()
}

public struct PositionAttempt: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let questionID: String
    public let answerIndex: Int
    public let isCorrect: Bool
    public var question: PositionQuestion? { PositionLesson.questions.first { $0.id == questionID } }
    public var isValid: Bool {
        guard let question else { return false }
        return question.choices.indices.contains(answerIndex) && isCorrect == (answerIndex == question.correctIndex)
    }
    public init(question:PositionQuestion,answerIndex:Int) throws {
        guard question.choices.indices.contains(answerIndex) else { throw PositionLessonError.invalidAnswer }
        id=UUID();date=Date();questionID=question.id;self.answerIndex=answerIndex;isCorrect=answerIndex == question.correctIndex
    }
}
