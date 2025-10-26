import Foundation

protocol SimulationClockDelegate: AnyObject {
    func simulationClock(_ clock: SimulationClock, didAdvanceTo date: Date)
}

final class SimulationClock {
    enum Speed: Int, CaseIterable {
        case x0 = 0
        case x1
        case x2
        case x3
        case x4
        case x5

        var simulatedSecondsPerRealSecond: TimeInterval {
            switch self {
            case .x0:
                return 0
            case .x1:
                return 3_600    // 24 real seconds per simulated day
            case .x2:
                return 7_200    // 12 real seconds per simulated day
            case .x3:
                return 21_600   // 4 real seconds per simulated day
            case .x4:
                return 86_400   // 1 real second per simulated day
            case .x5:
                return 432_000  // 0.2 real seconds per simulated day
            }
        }

        static func from(argument: String) -> Speed? {
            let trimmed = argument.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let valueString: String
            if trimmed.hasPrefix("x") {
                valueString = String(trimmed.dropFirst())
            } else {
                valueString = trimmed
            }

            guard let value = Int(valueString) else {
                return nil
            }

            return Speed(rawValue: value)
        }
    }

    private let stateQueue = DispatchQueue(label: "com.capitalistworld.simulationClock.state")
    private let callbackQueue: DispatchQueue
    private let refreshInterval: DispatchTimeInterval
    private var timer: DispatchSourceTimer?

    private var speed: Speed = .x0
    private var simulatedDate: Date
    private var lastRealUpdate: Date

    weak var delegate: SimulationClockDelegate?

    init(referenceDate: Date, refreshInterval: TimeInterval = 0.1, callbackQueue: DispatchQueue) {
        self.simulatedDate = referenceDate
        self.lastRealUpdate = Date()
        self.refreshInterval = .milliseconds(Int((refreshInterval * 1_000).rounded()))
        self.callbackQueue = callbackQueue
        startTimer()
    }

    deinit {
        timer?.setEventHandler {}
        timer?.cancel()
    }

    func setSpeed(_ newSpeed: Speed) {
        stateQueue.async { [weak self] in
            guard let self else { return }
            _ = self.advanceLocked(to: Date())
            self.speed = newSpeed
            self.notifyLocked()
        }
    }

    func currentDate() -> Date {
        stateQueue.sync {
            _ = advanceLocked(to: Date())
            return simulatedDate
        }
    }

    func currentSpeedRawValue() -> Int {
        stateQueue.sync { speed.rawValue }
    }

    private func startTimer() {
        let timer = DispatchSource.makeTimerSource(queue: stateQueue)
        timer.schedule(deadline: .now(), repeating: refreshInterval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let advanced = self.advanceLocked(to: Date())
            if advanced {
                self.notifyLocked()
            }
        }
        timer.resume()
        self.timer = timer
    }

    @discardableResult
    private func advanceLocked(to now: Date) -> Bool {
        let elapsed = now.timeIntervalSince(lastRealUpdate)
        lastRealUpdate = now

        guard elapsed > 0 else { return false }
        let ratio = speed.simulatedSecondsPerRealSecond
        guard ratio > 0 else { return false }

        simulatedDate = simulatedDate.addingTimeInterval(elapsed * ratio)
        return true
    }

    private func notifyLocked() {
        let date = simulatedDate
        callbackQueue.async { [weak self] in
            guard let self, let delegate = self.delegate else { return }
            delegate.simulationClock(self, didAdvanceTo: date)
        }
    }
}
