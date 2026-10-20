// Offscreen native macOS SwiftUI render. This is not an iOS Simulator screenshot.
import AppKit
import SwiftUI
import PokerCore

@main struct RenderChecks {
    @MainActor static func save<V:View>(_ view:V,_ name:String,_ root:URL) throws {
        let renderer=ImageRenderer(content:view.preferredColorScheme(.dark).foregroundStyle(AppTheme.text))
        renderer.scale=2
        guard let image=renderer.nsImage,let data=image.tiffRepresentation,
              let rep=NSBitmapImageRep(data:data),let png=rep.representation(using:.png,properties:[:]) else { fatalError("Render failed: \(name)") }
        try png.write(to:root.appendingPathComponent(name+".png"))
        print("Rendered \(name): \(rep.pixelsWide)x\(rep.pixelsHigh)")
    }
    @MainActor static func main() throws {
        _=NSApplication.shared
        let root=URL(fileURLWithPath:CommandLine.arguments[1])
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        var game=HoldemGame(seed:42)
        for _ in 0..<6 { let s=game.snapshot;try game.act(s.actor==2 ? .check : .call,seat:s.actor!,revision:s.revision) }
        let flop=game.snapshot
        try save(VStack(alignment:.leading,spacing:12){
            Text("Раздача 1 · \(flop.street)").font(.title2.bold())
            Text("Блайнды 5 / 10 · Учебные фишки").foregroundStyle(AppTheme.muted)
            PokerTableView(snapshot:flop)
        }.padding().frame(width:390).background(AppTheme.bg),"S04-flop-macos-render",root)
        while !game.snapshot.complete {
            let s=game.snapshot
            try game.act(s.currentBet==0 ? .check : .call,seat:s.actor!,revision:s.revision)
        }
        try save(OutcomeView(snapshot:game.snapshot,next:{}).frame(width:390).background(AppTheme.bg),"S04-outcome-macos-render",root)
    }
}
