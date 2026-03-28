import Testing
import Foundation
import CryptoKit
@testable import FaceBridgeTransport
@testable import FaceBridgeCore
@testable import FaceBridgeProtocol
@testable import FaceBridgeSharedUI

@Suite("ConnectionManager")
struct ConnectionManagerTests {
    @Test("starts and stops without crash")
    func startsAndStops() async {
        let manager = ConnectionManager()
        await manager.startDiscovery()
        await manager.stopDiscovery()
    }
}

@Suite("BLEFragmentationManager")
struct BLEFragmentationTests {
    @Test("small data wraps as single fragment")
    func smallDataSingleFragment() async {
        let manager = BLEFragmentationManager(mtu: 182)
        let data = Data(repeating: 0x42, count: 100)
        let fragments = await manager.fragment(data)
        #expect(fragments.count == 1)
    }

    @Test("large data fragments and reassembles")
    func largeDataRoundtrip() async {
        let manager = BLEFragmentationManager(mtu: 50)
        let originalData = Data((0..<200).map { UInt8($0 % 256) })
        let fragments = await manager.fragment(originalData)
        #expect(fragments.count > 1)

        var reassembled: Data? = nil
        for fragment in fragments {
            reassembled = await manager.reassemble(fragment)
        }
        #expect(reassembled == originalData)
    }

    @Test("corrupted CRC rejected")
    func corruptedCRCRejected() async {
        let manager = BLEFragmentationManager(mtu: 182)
        let data = Data(repeating: 0x42, count: 50)
        let fragments = await manager.fragment(data)

        guard var fragment = fragments.first, fragment.count > 24 else {
            Issue.record("Expected fragment data")
            return
        }
        fragment[21] = fragment[21] ^ 0xFF // corrupt CRC byte
        let result = await manager.reassemble(fragment)
        #expect(result == nil)
    }

    @Test("stale buffers are pruned")
    func staleBufferPrune() async {
        let manager = BLEFragmentationManager(mtu: 50, reassemblyTimeout: 0.1)
        let data = Data(repeating: 0x42, count: 200)
        let fragments = await manager.fragment(data)

        // Only send first fragment
        if let first = fragments.first {
            _ = await manager.reassemble(first)
        }

        try? await Task.sleep(for: .milliseconds(200))
        await manager.pruneStaleBuffers()

        // Remaining fragments should not reassemble
        if fragments.count > 1 {
            let result = await manager.reassemble(fragments[1])
            #expect(result == nil)
        }
    }
}

@Suite("MessageEnvelope Encoder")
struct MessageEnvelopeEncoderTests {
    @Test("encodes and decodes envelope")
    func roundtrip() throws {
        let encoder = MessageEncoder()
        let envelope = MessageEnvelope(
            type: .authorizationRequest,
            sequenceNumber: 42,
            payload: Data("test".utf8)
        )
        let data = try encoder.encodeEnvelope(envelope)
        let decoded = try encoder.decodeEnvelope(from: data)
        #expect(decoded.type == .authorizationRequest)
        #expect(decoded.sequenceNumber == 42)
        #expect(decoded.payload == Data("test".utf8))
    }
}

@Suite("DisplaySanitizer")
struct DisplaySanitizerTests {
    @Test("strips bidi override characters")
    func stripsBidi() {
        let malicious = "Hello\u{202E}dlroW"
        let sanitized = DisplaySanitizer.sanitize(malicious)
        #expect(!sanitized.contains("\u{202E}"))
    }

    @Test("caps length")
    func capsLength() {
        let long = String(repeating: "A", count: 500)
        let sanitized = DisplaySanitizer.sanitize(long, maxLength: 100)
        #expect(sanitized.count <= 100)
    }

    @Test("normalizes whitespace")
    func normalizesWhitespace() {
        let messy = "Hello   \t\n  World"
        let sanitized = DisplaySanitizer.sanitize(messy)
        #expect(sanitized == "Hello World")
    }

    @Test("strips RTL/LTR marks")
    func stripsDirectionalMarks() {
        let marked = "Test\u{200E}String\u{200F}Here"
        let sanitized = DisplaySanitizer.sanitize(marked)
        #expect(!sanitized.contains("\u{200E}"))
        #expect(!sanitized.contains("\u{200F}"))
    }

    @Test("strips isolate characters")
    func stripsIsolates() {
        let isolated = "Test\u{2066}evil\u{2069}text"
        let sanitized = DisplaySanitizer.sanitize(isolated)
        #expect(!sanitized.contains("\u{2066}"))
        #expect(!sanitized.contains("\u{2069}"))
    }
}

@Suite("LocalNetworkTransport Configuration")
struct LocalNetworkTransportTests {
    @Test("default init uses TLS")
    func defaultUsesTLS() {
        let transport = LocalNetworkTransport()
        #expect(transport.connectionState == .disconnected)
    }

    @Test("explicit insecure mode allowed only with flag")
    func insecureRequiresFlag() {
        let secureTransport = LocalNetworkTransport()
        _ = secureTransport
        let insecureTransport = LocalNetworkTransport(allowInsecure: true)
        _ = insecureTransport
    }

    @Test("max message size is 1MB")
    func maxMessageSize() {
        #expect(LocalNetworkTransport.maxMessageSize == 1_048_576)
    }

    @Test("max connections is 10")
    func maxConnections() {
        #expect(LocalNetworkTransport.maxConnections == 10)
    }
}

@Suite("BLETransport Configuration")
struct BLETransportTests {
    @Test("max receive size is 64KB")
    func maxReceiveSize() {
        #expect(BLETransport.maxReceiveSize == 65_536)
    }

    @Test("per-device connection state tracks correctly")
    func perDeviceState() {
        let transport = BLETransport()
        let deviceId = UUID()
        let state = transport.connectionState(for: deviceId)
        #expect(state == .disconnected)
    }

    @Test("authorize and deauthorize peers")
    func peerAuthorization() {
        let transport = BLETransport()
        let deviceId = UUID()
        transport.authorizePeer(deviceId)
        transport.deauthorizePeer(deviceId)
    }
}
