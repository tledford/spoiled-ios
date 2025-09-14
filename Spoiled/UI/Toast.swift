import SwiftUI

struct Toast: Identifiable, Equatable {
    enum Style { case success, error, info }
    let id = UUID()
    var message: String
    var style: Style = .info
    var duration: TimeInterval = 2.0
}

final class ToastCenter: ObservableObject {
    @Published var current: Toast?

    func show(_ toast: Toast) {
        withAnimation { current = toast }
        let d = toast.duration
        DispatchQueue.main.asyncAfter(deadline: .now() + d) { [weak self] in
            withAnimation { self?.current = nil }
        }
    }

    func success(_ message: String, duration: TimeInterval = 5.0) { show(Toast(message: message, style: .success, duration: duration)) }
    func error(_ message: String, duration: TimeInterval = 5.0) { show(Toast(message: message, style: .error, duration: duration)) }
    func info(_ message: String, duration: TimeInterval = 5.0) { show(Toast(message: message, style: .info, duration: duration)) }
}

struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(toast.message)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(background)
        .foregroundColor(.white)
        .clipShape(Capsule())
        .shadow(radius: 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var icon: String {
        switch toast.style {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private var background: some View {
        let color: Color
        switch toast.style {
        case .success: color = .green
        case .error: color = .red
        case .info: color = .blue
        }
        return Color(UIColor { _ in UIColor(color) }).opacity(0.95)
    }
}

struct ToastOverlay: ViewModifier {
    @ObservedObject var center: ToastCenter

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            if let toast = center.current {
                VStack {
                    ToastView(toast: toast)
                        .padding(.top, 8)
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
    }
}

extension View {
    func toast(_ center: ToastCenter) -> some View {
        self.modifier(ToastOverlay(center: center))
    }
}
