import SwiftUI

// MARK: - Toast Model

struct Toast: Identifiable, Equatable {
    enum Style { case success, error, info }
    let id = UUID()
    var message: String
    var style: Style = .info
    var duration: TimeInterval = 2.0
}

// MARK: - ToastCenter

final class ToastCenter: ObservableObject {
    @Published var current: Toast?

    func show(_ toast: Toast) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) { current = toast }
        DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) { [weak self] in
            withAnimation(.easeOut(duration: 0.25)) { self?.current = nil }
        }
    }

    func success(_ message: String, duration: TimeInterval = 5.0) { show(Toast(message: message, style: .success, duration: duration)) }
    func error(_ message: String, duration: TimeInterval = 5.0)   { show(Toast(message: message, style: .error,   duration: duration)) }
    func info(_ message: String, duration: TimeInterval = 5.0)    { show(Toast(message: message, style: .info,    duration: duration)) }
}

// MARK: - ToastView

struct ToastView: View {
    let toast: Toast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
            Text(toast.message)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(toastBackground)
        .foregroundStyle(.white)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
    }

    private var iconName: String {
        switch toast.style {
        case .success: return "checkmark.circle.fill"
        case .error:   return "exclamationmark.triangle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    @ViewBuilder private var toastBackground: some View {
        if #available(iOS 26, *) {
            Capsule()
                .glassEffect(.regular.tint(tintColor).interactive(), in: Capsule())
        } else {
            tintColor.opacity(0.92)
        }
    }

    private var tintColor: Color {
        switch toast.style {
        case .success: return .green
        case .error:   return .red
        case .info:    return Color(red: 0.20, green: 0.45, blue: 0.90)
        }
    }
}

// MARK: - ToastOverlay

struct ToastOverlay: ViewModifier {
    @ObservedObject var center: ToastCenter

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            if let toast = center.current {
                VStack {
                    ToastView(toast: toast)
                        .padding(.top, 8)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            )
                        )
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
    }
}

extension View {
    func toast(_ center: ToastCenter) -> some View {
        modifier(ToastOverlay(center: center))
    }
}
