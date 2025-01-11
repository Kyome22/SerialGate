import Combine

extension AnyCancellable: @retroactive @unchecked Sendable {}
extension PassthroughSubject: @retroactive @unchecked Sendable {}
extension CurrentValueSubject: @retroactive @unchecked Sendable {}
