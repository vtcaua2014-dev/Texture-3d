import SwiftUI
import UIKit
import CoreText


@main
struct StopwatchApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}


struct AppFont: Identifiable, Hashable {
    let id: String      // PostScript name
    let title: String
}

enum FontLoader {
    // Registra todos os .ttf da pasta Fonts e devolve os nomes PostScript
    static func loadAll() -> [AppFont] {
        var result: [AppFont] = []
        let urls = (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            if let provider = CGDataProvider(url: url as CFURL),
               let cg = CGFont(provider),
               let ps = cg.postScriptName as String? {
                let title = url.deletingPathExtension().lastPathComponent
                    .replacingOccurrences(of: "_", with: " ")
                result.append(AppFont(id: ps, title: title))
            }
        }
        return result
    }
}


struct Lap: Identifiable {
    let id = UUID()
    let number: Int
    let split: TimeInterval
    let total: TimeInterval
}

final class StopwatchModel: ObservableObject {
    @Published var elapsed: TimeInterval = 0
    @Published var running = false
    @Published var laps: [Lap] = []

    private var startDate: Date?
    private var accumulated: TimeInterval = 0
    private var timer: Timer?

    func toggle() { running ? pause() : start() }

    func start() {
        running = true
        startDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            guard let self, let s = self.startDate else { return }
            self.elapsed = self.accumulated + Date().timeIntervalSince(s)
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func pause() {
        running = false
        timer?.invalidate()
        if let s = startDate { accumulated += Date().timeIntervalSince(s) }
        startDate = nil
        elapsed = accumulated
    }

    func reset() {
        pause()
        accumulated = 0
        elapsed = 0
        laps.removeAll()
    }

    func lap() {
        guard running else { return }
        let last = laps.first?.total ?? 0
        laps.insert(Lap(number: laps.count + 1, split: elapsed - last, total: elapsed), at: 0)
    }
}

func format(_ t: TimeInterval) -> String {
    let cs = Int((t * 100).rounded(.down))
    let h = cs / 360000
    let m = (cs / 6000) % 60
    let s = (cs / 100) % 60
    let c = cs % 100
    return h > 0
        ? String(format: "%d:%02d:%02d.%02d", h, m, s, c)
        : String(format: "%02d:%02d.%02d", m, s, c)
}

struct ContentView: View {
    @StateObject private var model = StopwatchModel()
    @State private var fonts: [AppFont] = []
    @State private var fontID: String = ""
    @State private var textColor: Color = .white
    @State private var bgColor: Color = .black
    @State private var showSettings = false

    private var displayFont: Font {
        fontID.isEmpty ? .system(size: 64, weight: .light, design: .monospaced)
                       : .custom(fontID, size: 64)
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button { showSettings = true } label: {
                        Image(systemName: "paintpalette").font(.title2).foregroundColor(textColor)
                    }
                }.padding(.horizontal)

                Text(format(model.elapsed))
                    .font(displayFont)
                    .monospacedDigit()
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .foregroundColor(textColor)
                    .padding(.horizontal)

                HStack(spacing: 20) {
                    circleButton(model.running ? "Lap" : "Reset", .gray) {
                        model.running ? model.lap() : model.reset()
                    }
                    circleButton(model.running ? "Stop" : "Start",
                                 model.running ? .red : .green) { model.toggle() }
                }

                List(model.laps) { lap in
                    HStack {
                        Text("Volta \(lap.number)")
                        Spacer()
                        Text(format(lap.split))
                        Text(format(lap.total)).opacity(0.6)
                    }
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(textColor)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
            }
        }
        .onAppear {
            fonts = FontLoader.loadAll()
            UIApplication.shared.isIdleTimerDisabled = true  // mantém a tela ligada
        }
        .sheet(isPresented: $showSettings) {
            NavigationView {
                Form {
                    Section("Cores") {
                        ColorPicker("Cor do texto", selection: $textColor)
                        ColorPicker("Cor do fundo", selection: $bgColor)
                    }
                    Section("Fonte") {
                        Picker("Fonte", selection: $fontID) {
                            Text("Padrão").tag("")
                            ForEach(fonts) { f in Text(f.title).tag(f.id) }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }
                .navigationTitle("Personalizar")
                .toolbar { Button("OK") { showSettings = false } }
            }
        }
    }

    private func circleButton(_ title: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline).foregroundColor(.white)
                .frame(width: 90, height: 90)
                .background(color.opacity(0.85)).clipShape(Circle())
        }
    }
}

