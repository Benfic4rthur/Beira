import SwiftUI
import BeiraCore

private let ink = Color(red: 0.16, green: 0.19, blue: 0.18)
private let accent = Color(red: 0.72, green: 0.34, blue: 0.19)
private let paper = Color(red: 0.97, green: 0.96, blue: 0.93)

struct SettingsView: View {
    @ObservedObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if !state.permissionGranted { permissionCard }
                if let error = state.error { errorCard(error) }
                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Text("Seu trackpad, dois controles.")
                                .font(.system(size: 23, weight: .semibold, design: .rounded))
                            Spacer()
                        }
                        Text("Uma passada completa percorre toda a escala. Suba para aumentar, desça para diminuir.")
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                        TrackpadView(state: state)
                        HStack {
                            Label(state.deviceName, systemImage: "hand.draw")
                            Spacer()
                            Text(state.monitoring ? "AO VIVO" : "DESCONECTADO").font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1.4).foregroundStyle(state.monitoring ? accent : .secondary)
                        }.font(.system(size: 11)).foregroundStyle(.secondary)
                        Text(state.lastAction).font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ink.opacity(0.75)).frame(height: 18)
                    }
                    .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 14) {
                        controlLegend("speaker.wave.2", title: "Volume", edge: state.preferences.swapped ? "Borda direita" : "Borda esquerda")
                        controlLegend("sun.max", title: "Brilho", edge: state.preferences.swapped ? "Borda esquerda" : "Borda direita")
                        Divider()
                        Toggle("Beira ativado", isOn: $state.preferences.enabled)
                            .toggleStyle(.switch).tint(accent).font(.system(size: 12, weight: .medium))
                        Text("Os gestos precisam começar na borda. Movimentos iniciados no centro seguem livres.")
                            .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(3)
                    }.frame(width: 190).padding(20)
                        .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 20))
                }
                VStack(alignment: .leading, spacing: 18) {
                    Text("DO SEU JEITO").font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.7).foregroundStyle(.secondary)
                    HStack(alignment: .top, spacing: 32) {
                        VStack(alignment: .leading, spacing: 18) {
                            sliderRow("Largura das bordas", value: $state.preferences.edgeWidth,
                                      range: 0.01...0.08, text: String(format: "%.1f%%", state.preferences.edgeWidth * 100))
                            sliderRow("Sensibilidade", value: $state.preferences.sensitivity,
                                      range: 0.5...2, text: String(format: "%.1f×", state.preferences.sensitivity))
                            Toggle("Inverter os lados", isOn: $state.preferences.swapped)
                            Toggle("Somente na parte inferior", isOn: $state.preferences.bottomOnly)
                        }
                        VStack(alignment: .leading, spacing: 14) {
                            Toggle("Ajustes finos", isOn: $state.preferences.fineControl)
                            Toggle("Retorno tátil", isOn: $state.preferences.hapticFeedback)
                            Toggle("Manter o cursor no lugar", isOn: $state.preferences.freezeCursor)
                            Toggle("Pausar enquanto digito", isOn: $state.preferences.protectTyping)
                            Toggle("Exigir a tecla Option ⌥", isOn: $state.preferences.requireOption)
                            Toggle("Abrir ao iniciar o Mac", isOn: Binding(get: { state.launchAtLogin }, set: state.setLaunchAtLogin))
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.font(.system(size: 12)).toggleStyle(.checkbox).tint(accent)
                }.padding(22).background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 20))
                HStack {
                    Text("Beira  /  0.1.1").font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(1)
                    Spacer()
                    Button("Reconectar trackpad") { state.reconnect() }.buttonStyle(.link)
                }.font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(30)
        }
        .background(paper).foregroundStyle(ink)
        .frame(minWidth: 760, idealWidth: 800, minHeight: 640, idealHeight: 720)
        .preferredColorScheme(.light)
        .alert("Início automático", isPresented: Binding(get: { state.loginError != nil }, set: { if !$0 { state.loginError = nil } })) {
            Button("OK") { state.loginError = nil }
        } message: { Text(state.loginError ?? "") }
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(ink).frame(width: 48, height: 48)
                    HStack(spacing: 12) {
                        BracketMark(right: false).stroke(Color(red: 0.90, green: 0.59, blue: 0.38),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        BracketMark(right: true).stroke(Color(red: 0.96, green: 0.78, blue: 0.43),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    }.frame(width: 24, height: 24)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Beira").font(.system(size: 32, weight: .semibold, design: .rounded)).tracking(-1)
                    Text("Na ponta dos dedos.").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 7) {
                Circle().fill(state.permissionGranted && state.preferences.enabled && state.monitoring ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                Text(state.statusTitle).font(.system(size: 11, weight: .medium))
            }.padding(.horizontal, 12).padding(.vertical, 8)
                .background(.white.opacity(0.85), in: Capsule())
        }
    }

    private var permissionCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "hand.raised").font(.system(size: 24)).foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 4) {
                Text("Só falta permitir o controle do Mac.").font(.system(size: 13, weight: .semibold))
                Text("Ative o Beira em Acessibilidade para ajustar brilho e volume. A visualização dos toques já funciona.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Permitir acesso") { SystemControls.requestAccessibility() }
                .buttonStyle(.borderedProminent).tint(accent).controlSize(.regular)
        }.padding(18).background(accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    private func errorCard(_ error: String) -> some View {
        Label(error, systemImage: "exclamationmark.triangle")
            .font(.system(size: 12)).padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }

    private func controlLegend(_ symbol: String, title: String, edge: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 21, weight: .light)).frame(width: 27)
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(edge).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 2)
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Text(title); Spacer(); Text(text).monospacedDigit().foregroundStyle(.secondary) }
            Slider(value: value, in: range).tint(accent).accessibilityLabel(title)
        }.frame(maxWidth: .infinity)
    }
}

private struct BracketMark: Shape {
    let right: Bool
    func path(in rect: CGRect) -> Path {
        let outer = right ? rect.maxX : rect.minX
        let inner = right ? rect.minX : rect.maxX
        return Path { p in
            p.move(to: CGPoint(x: inner, y: rect.minY))
            p.addLine(to: CGPoint(x: outer, y: rect.minY))
            p.addLine(to: CGPoint(x: outer, y: rect.maxY))
            p.addLine(to: CGPoint(x: inner, y: rect.maxY))
        }
    }
}

private struct TrackpadView: View {
    @ObservedObject var state: AppState
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let band = size.width * state.preferences.edgeWidth
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.88, green: 0.87, blue: 0.83))
                RoundedRectangle(cornerRadius: 20).strokeBorder(ink.opacity(0.16), lineWidth: 1)
                HStack(spacing: 0) {
                    Rectangle().fill(edgeColor(.left)).frame(width: max(3, band))
                    Spacer(minLength: 0)
                    Rectangle().fill(edgeColor(.right)).frame(width: max(3, band))
                }.frame(height: state.preferences.bottomOnly ? size.height * 0.3 : size.height)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                VStack(spacing: 9) {
                    Image(systemName: state.isAdjusting ? (state.activeEdge == .left) != state.preferences.swapped ? "speaker.wave.2" : "sun.max" : "hand.draw")
                        .font(.system(size: 25, weight: .ultraLight))
                    Text(state.isAdjusting ? "Ajustando" : "Deslize nas laterais")
                        .font(.system(size: 11, weight: .medium))
                }.foregroundStyle(ink.opacity(0.45))
                ForEach(state.contacts, id: \.id) { touch in
                    Circle().fill(accent.opacity(0.22)).overlay(Circle().stroke(accent.opacity(0.65), lineWidth: 1))
                        .frame(width: 24, height: 24)
                        .position(x: touch.x * size.width, y: (1 - touch.y) * size.height)
                }
            }.clipShape(RoundedRectangle(cornerRadius: 20))
        }.frame(height: 206)
            .accessibilityLabel("Visualização do trackpad. \(state.contacts.count) dedos em contato.")
    }

    private func edgeColor(_ edge: BeiraCore.Edge) -> Color {
        state.activeEdge == edge && state.isAdjusting ? accent : accent.opacity(0.5)
    }
}
