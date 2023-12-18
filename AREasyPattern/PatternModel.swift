import Foundation
import UIKit

class PatternModel: ObservableObject {
    @Published var patternUrl: URL?
    @Published var positionX: Float = 0.0
    @Published var positionY: Float = 0.0
    @Published var invert: Bool = false
}
