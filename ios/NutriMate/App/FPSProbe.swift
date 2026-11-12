import UIKit

/// Замер плавности для CI (`-uiShot -fps`): через 2 с после запуска сам прокручивает главный список
/// экрана вниз и обратно (как палец), считает кадры через CADisplayLink и пишет результат
/// в Documents/fps.txt («home avg=58.9 min=41 hitches=2 frames=355»). На телефоне владельца не включается.
@MainActor
final class FPSProbe: NSObject {
    static let shared = FPSProbe()
    static var enabled: Bool { UIShot.enabled && UIShot.args.contains("-fps") }

    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private var start: CFTimeInterval = 0
    private var deltas: [CFTimeInterval] = []
    private weak var scroll: UIScrollView?
    private var maxOffset: CGFloat = 0
    private let duration: CFTimeInterval = 6

    func startLater() {
        guard FPSProbe.enabled else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { self.begin() }
    }

    private func begin() {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).flatMap(\.windows).first(where: \.isKeyWindow) else { return }
        // самый большой вертикальный скролл на экране (ScrollView / List)
        var best: UIScrollView?
        func walk(_ v: UIView) {
            if let s = v as? UIScrollView, s.contentSize.height > s.bounds.height + 40,
               s.bounds.width > window.bounds.width * 0.8,
               (best?.contentSize.height ?? 0) < s.contentSize.height { best = s }
            v.subviews.forEach(walk)
        }
        walk(window)
        scroll = best
        maxOffset = min(2400, max(0, (best?.contentSize.height ?? 0) - (best?.bounds.height ?? 0)))
        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 120)
        l.add(to: .main, forMode: .common)
        link = l
    }

    @objc private func tick(_ l: CADisplayLink) {
        let now = l.timestamp
        if start == 0 { start = now; last = now; return }
        deltas.append(now - last)
        last = now
        let t = now - start
        // вниз за половину времени, потом обратно (плавная синусоида, как свайп)
        if let s = scroll, maxOffset > 0 {
            let p = t / duration
            let y = maxOffset * CGFloat(sin(min(1, p) * .pi))
            s.setContentOffset(CGPoint(x: s.contentOffset.x, y: y - s.adjustedContentInset.top), animated: false)
        }
        if t >= duration { finish(expected: l.duration) }
    }

    private func finish(expected: CFTimeInterval) {
        link?.invalidate()
        link = nil
        let total = deltas.reduce(0, +)
        let avg = total > 0 ? Double(deltas.count) / total : 0
        let worst = deltas.max().map { 1 / $0 } ?? 0
        let frame = expected > 0 ? expected : 1.0 / 60
        let hitches = deltas.filter { $0 > frame * 1.5 }.count
        let tag = UIShot.value("-sheet") ?? UIShot.value("-tab") ?? "home"
        let line = String(format: "%@ avg=%.1f min=%.0f hitches=%d frames=%d scrolled=%.0fpt\n",
                          tag, avg, worst, hitches, deltas.count, Double(maxOffset))
        print("FPS " + line)
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("fps.txt")
        try? line.data(using: .utf8)?.write(to: url)
        scroll?.setContentOffset(.zero, animated: false)
    }
}
