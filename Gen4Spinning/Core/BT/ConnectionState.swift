import Foundation

enum ConnectionState: Equatable {
    case disconnected
    case connecting(name: String)
    case connected(name: String)
    case reconnecting(name: String)
    case lost(name: String)
}
