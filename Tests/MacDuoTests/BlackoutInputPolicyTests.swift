import CoreGraphics
import Testing
@testable import MacDuo

struct BlackoutInputPolicyTests {
    @Test func onlyOptionMAndItsModifierReleasePassWhileBlocked() {
        #expect(BlackoutInputPolicy.allows(type: .keyDown, keyCode: 46, flags: .maskAlternate))
        #expect(BlackoutInputPolicy.allows(type: .keyUp, keyCode: 46, flags: []))
        #expect(BlackoutInputPolicy.allows(type: .flagsChanged, keyCode: 58, flags: []))
        #expect(BlackoutInputPolicy.allows(type: .flagsChanged, keyCode: 61, flags: .maskAlternate))
        #expect(!BlackoutInputPolicy.allows(type: .keyDown, keyCode: 46, flags: []))
        #expect(!BlackoutInputPolicy.allows(type: .keyDown, keyCode: 46, flags: [.maskAlternate, .maskCommand]))
        #expect(!BlackoutInputPolicy.allows(type: .keyDown, keyCode: 11, flags: .maskAlternate))
        #expect(!BlackoutInputPolicy.allows(type: .keyDown, keyCode: 12, flags: .maskCommand))
        #expect(!BlackoutInputPolicy.allows(type: .flagsChanged, keyCode: 55, flags: .maskCommand))
    }
    @Test func blurModeOnlyAllowsOptionB() {
        #expect(BlackoutInputPolicy.allows(type: .keyDown, keyCode: 11, flags: .maskAlternate, mode: .blur))
        #expect(BlackoutInputPolicy.allows(type: .keyUp, keyCode: 11, flags: [], mode: .blur))
        #expect(!BlackoutInputPolicy.allows(type: .keyDown, keyCode: 46, flags: .maskAlternate, mode: .blur))
        #expect(!BlackoutInputPolicy.allows(type: .keyUp, keyCode: 46, flags: [], mode: .blur))
    }
    @Test func pointerScrollAndGestureEventsAreBlocked() {
        for type in [CGEventType.mouseMoved, .leftMouseDown, .leftMouseUp, .rightMouseDown, .otherMouseDragged, .scrollWheel] {
            #expect(!BlackoutInputPolicy.allows(type: type, keyCode: 0, flags: []))
        }
        #expect(!BlackoutInputPolicy.allows(type: CGEventType(rawValue: 29)!, keyCode: 0, flags: []))
    }
}
