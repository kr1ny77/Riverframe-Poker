import SwiftUI
import PokerCore

struct LessonHeader: View {
    let title: String
    let detail: String
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            Text(title).font(.system(.title2,design:.serif).weight(.semibold)).fixedSize(horizontal:false,vertical:true).accessibilityAddTraits(.isHeader)
            if !detail.isEmpty { Text(detail).font(.subheadline).foregroundStyle(AppTheme.muted).fixedSize(horizontal:false,vertical:true) }
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
}

struct CardStrip: View {
    let cards: [Card]
    var label: String? = nil
    @ScaledMetric(relativeTo:.body) private var width: CGFloat = 46
    private var cardWidth:CGFloat { min(width,72) }
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            if let label { Text(label).font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.muted) }
            ViewThatFits(in:.horizontal) {
                HStack(spacing:8) { content }
                LazyVGrid(columns:[GridItem(.adaptive(minimum:cardWidth),alignment:.leading)],alignment:.leading,spacing:8) { content }
            }
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
    private var content: some View {
        ForEach(cards) { card in PlayingCardView(card:card,size:CGSize(width:cardWidth,height:cardWidth*1.4)) }
    }
}

struct MetricStrip: View {
    let items: [(String,String)]
    @ScaledMetric(relativeTo:.body) private var minimumWidth:CGFloat = 96
    var body: some View {
        LazyVGrid(columns:[GridItem(.adaptive(minimum:minimumWidth),alignment:.leading)],alignment:.leading,spacing:16) {
            ForEach(items.indices,id:\.self) { index in
                VStack(alignment:.leading,spacing:4) {
                    Text(items[index].0).font(.caption).foregroundStyle(AppTheme.muted)
                    Text(items[index].1).font(.title3.weight(.semibold).monospacedDigit()).fixedSize(horizontal:false,vertical:true)
                }.accessibilityElement(children:.combine)
            }
        }.padding(.vertical,12)
    }
}

struct EquityMeter: View {
    let percent: Double
    let caption: String
    var title: String = "Доля банка"
    var accessibilityName: String = "Equity"
    @Environment(\.dynamicTypeSize) private var typeSize
    private var fraction: Double { percent.isFinite ? min(1,max(0,percent/100)) : 0 }
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            if typeSize.isAccessibilitySize {
                VStack(alignment:.leading,spacing:4) { value;titleLabel }
            } else {
                HStack(alignment:.firstTextBaseline) { value;Spacer();titleLabel }
            }
            GeometryReader { proxy in
                let width = proxy.size.width.isFinite ? max(0, proxy.size.width) : 0
                ZStack(alignment:.leading) {
                    Capsule().fill(AppTheme.surfaceAlt)
                    Capsule().fill(AppTheme.accent).frame(width:width*fraction)
                }
            }.frame(height:10).accessibilityHidden(true)
            Text(caption).font(.footnote).foregroundStyle(AppTheme.muted)
        }.padding(16).background(AppTheme.surface,in:RoundedRectangle(cornerRadius:16))
            .accessibilityElement(children:.ignore)
            .accessibilityLabel("\(accessibilityName) \(String(format:"%.2f",percent)) процентов. \(caption)")
    }
    private var value:some View { Text(String(format:"%.2f %%",percent)).font(.system(.largeTitle,design:.rounded).weight(.semibold).monospacedDigit()).fixedSize(horizontal:false,vertical:true) }
    private var titleLabel:some View { Text(title).font(.subheadline).foregroundStyle(AppTheme.muted) }
}

struct OutcomeDistribution: View {
    let wins: Int
    let ties: Int
    let losses: Int
    var weighted: Bool = false
    var body: some View {
        VStack(alignment:.leading,spacing:4) {
            MetricStrip(items:[(weighted ? "Вес побед" : "Победы",String(wins)),(weighted ? "Вес ничьих" : "Ничьи",String(ties)),(weighted ? "Вес поражений" : "Поражения",String(losses))])
            if weighted { Text("Суммы весов рук по каждому исходу.").font(.footnote).foregroundStyle(AppTheme.muted) }
        }
    }
}

struct FormulaSteps: View {
    let lines: [String]
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            ForEach(lines.indices,id:\.self) { index in
                HStack(alignment:.top,spacing:12) {
                    Text(String(index+1)).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.accent)
                        .frame(width:24,height:24).background(AppTheme.surfaceAlt,in:Circle()).accessibilityHidden(true)
                    Text(lines[index]).font(.body).fixedSize(horizontal:false,vertical:true)
                }.accessibilityElement(children:.combine)
            }
        }
    }
}

struct EVComparisonDiagram: View {
    let callEV: Double
    let callCost: Double
    @Environment(\.dynamicTypeSize) private var typeSize
    private var limit:Double { max(1,max(abs(callEV),callCost)) }
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            Text("Ожидаемое изменение стека").font(.subheadline.weight(.medium))
            ForEach(0..<2,id:\.self) { row in
                let value=row == 0 ? 0 : callEV
                Group {
                    if typeSize.isAccessibilitySize {
                        VStack(alignment:.leading,spacing:8) {
                            Text(row == 0 ? "Fold · пас" : "Call · колл")
                            Text(String(format:"%+.2f",value)).font(.title3.monospacedDigit().weight(.semibold))
                            bar(value)
                        }
                    } else {
                        HStack {
                            Text(row == 0 ? "Fold · пас" : "Call · колл").frame(width:108,alignment:.leading)
                            bar(value)
                            Text(String(format:"%+.2f",value)).font(.subheadline.monospacedDigit().weight(.semibold)).frame(minWidth:62,alignment:.trailing)
                        }
                    }
                }.accessibilityElement(children:.combine)
            }
            Text("Шкала: −\(String(format:"%.2f",limit)) … +\(String(format:"%.2f",limit)) фишек. Ноль — текущий стек.").font(.footnote).foregroundStyle(AppTheme.muted)
        }.padding(16).background(AppTheme.surface,in:RoundedRectangle(cornerRadius:16))
    }
    private func bar(_ value:Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment:.leading) {
                Rectangle().fill(AppTheme.border).frame(width:1).offset(x:proxy.size.width/2)
                Rectangle().fill(value < 0 ? AppTheme.danger : AppTheme.success)
                    .frame(width:proxy.size.width/2*abs(value)/limit,height:10)
                    .offset(x:value < 0 ? proxy.size.width/2*(1-abs(value)/limit) : proxy.size.width/2)
            }.frame(maxHeight:.infinity)
        }.frame(height:24).accessibilityHidden(true)
    }
}

struct RemovalPipeline: View {
    let baseline: Int
    let afterHero: Int
    let remaining: Int
    var body: some View {
        MetricStrip(items:[("Исходно",String(baseline)),("После ваших",String(afterHero)),("После доски",String(remaining))])
            .accessibilityElement(children:.ignore)
            .accessibilityLabel("Комбинации: исходно \(baseline), после ваших карт \(afterHero), после доски \(remaining)")
    }
}

struct OddsDiagram: View {
    let pot: Int64
    let bet: Int64
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            MetricStrip(items:[("Банк до ставки",String(pot)),("Ставка",String(bet)),("Ваш колл",String(bet))])
            Divider().overlay(AppTheme.border)
            HStack {
                Text("Банк после колла").foregroundStyle(AppTheme.muted)
                Spacer();Text("\(pot+bet+bet)").font(.title3.weight(.semibold).monospacedDigit())
            }.accessibilityElement(children:.combine)
        }.padding(16).background(AppTheme.surface,in:RoundedRectangle(cornerRadius:16))
    }
}

struct LessonInputStyle: ViewModifier {
    func body(content:Content) -> some View {
        content.font(.title3.monospacedDigit()).padding(14)
            .background(AppTheme.surfaceAlt,in:RoundedRectangle(cornerRadius:12))
            .overlay(RoundedRectangle(cornerRadius:12).stroke(AppTheme.borderInput,lineWidth:1))
    }
}

extension View {
    @ViewBuilder func lessonKeyboardToolbar(_ dismissKeyboard:@escaping () -> Void) -> some View {
        #if os(iOS)
        self.toolbar {
            ToolbarItemGroup(placement:.keyboard) {
                Spacer()
                Button("Готово",action:dismissKeyboard).accessibilityHint("Скрыть клавиатуру")
            }
        }
        #else
        self
        #endif
    }
    @ViewBuilder func lessonCanvas() -> some View {
        #if os(iOS)
        self.foregroundStyle(AppTheme.text).background(AppTheme.bg).navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.bg,for:.navigationBar,.tabBar)
            .toolbarBackground(.visible,for:.navigationBar,.tabBar)
        #else
        self.foregroundStyle(AppTheme.text).background(AppTheme.bg)
        #endif
    }
    func lessonInput() -> some View { modifier(LessonInputStyle()) }
}
