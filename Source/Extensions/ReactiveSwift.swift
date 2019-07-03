import Foundation
import ReactiveSwift

extension SignalProducer {
    /// Await the termination of the signal producer.
    ///
    /// - returns: A `Bool` indicated whether the producer completed.
    internal func await(timeout: TimeInterval = 0.1) -> Bool {
        var done = false
        var completed = false

        let started = Date()
        start { event in
            switch event {
            case .value:
                break
            case .completed:
                completed = true
                done = true
            case .interrupted, .failed:
                done = true
            }
        }

        while !done, abs(started.timeIntervalSinceNow) < timeout {
            RunLoop.main.run(mode: RunLoop.Mode.default, before: Date(timeIntervalSinceNow: 0.01))
        }

        return completed
    }

    /// Await the first value from the signal producer.
    internal func awaitFirst() -> Result<Value, Error>? {
        var result: Result<Value, Error>?

        _ = take(first: 1)
            .map(Result.success)
            .flatMapError { error -> SignalProducer<Result<Value, Error>, Never> in
                let result = Result<Value, Error>.failure(error)
                return SignalProducer<Result<Value, Error>, Never>(value: result)
            }
            .on(value: { result = $0 })
            .await()

        return result
    }
}
