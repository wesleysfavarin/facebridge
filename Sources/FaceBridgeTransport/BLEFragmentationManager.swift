import Foundation
import FaceBridgeCore

public actor BLEFragmentationManager {
    private let mtu: Int
    private let headerSize = 24
    private let reassemblyTimeout: TimeInterval
    private var reassemblyBuffers: [Data: [UInt16: Data]] = [:]
    private var expectedCounts: [Data: UInt16] = [:]
    private var reassemblyTimestamps: [Data: Date] = [:]

    public init(mtu: Int = 182, reassemblyTimeout: TimeInterval = 30) {
        self.mtu = mtu
        self.reassemblyTimeout = reassemblyTimeout
    }

    public func fragment(_ data: Data) -> [Data] {
        let maxPayload = mtu - headerSize
        guard data.count > maxPayload else {
            return [wrapSingle(data)]
        }

        let sequenceId = generateSequenceId()
        var chunks: [Data] = []
        var offset = 0
        while offset < data.count {
            let end = min(offset + maxPayload, data.count)
            chunks.append(data[offset..<end])
            offset = end
        }

        let totalCount = UInt16(chunks.count)
        return chunks.enumerated().map { index, chunk in
            var frame = Data()
            frame.append(sequenceId)
            var idx = UInt16(index).bigEndian
            frame.append(Data(bytes: &idx, count: 2))
            var total = totalCount.bigEndian
            frame.append(Data(bytes: &total, count: 2))
            var crc = crc32(chunk).bigEndian
            frame.append(Data(bytes: &crc, count: 4))
            frame.append(chunk)
            return frame
        }
    }

    public func reassemble(_ frame: Data) -> Data? {
        pruneStaleBuffers()
        guard frame.count >= headerSize else { return nil }

        let seqId = frame.prefix(16)
        let index = frame.subdata(in: 16..<18).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
        let totalCount = frame.subdata(in: 18..<20).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
        let expectedCRC = frame.subdata(in: 20..<24).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        let payload = frame.subdata(in: headerSize..<frame.count)

        guard crc32(payload) == expectedCRC else { return nil }

        if totalCount == 1 && index == 0 {
            return payload
        }

        reassemblyBuffers[seqId, default: [:]][index] = payload
        expectedCounts[seqId] = totalCount
        if reassemblyTimestamps[seqId] == nil {
            reassemblyTimestamps[seqId] = Date()
        }

        guard let buffer = reassemblyBuffers[seqId],
              buffer.count == Int(totalCount) else { return nil }

        var assembled = Data()
        for i in 0..<totalCount {
            guard let chunk = buffer[i] else { return nil }
            assembled.append(chunk)
        }

        reassemblyBuffers.removeValue(forKey: seqId)
        expectedCounts.removeValue(forKey: seqId)
        reassemblyTimestamps.removeValue(forKey: seqId)

        return assembled
    }

    public func pruneStaleBuffers() {
        let now = Date()
        let stale = reassemblyTimestamps.filter { now.timeIntervalSince($0.value) > reassemblyTimeout }
        for (seqId, _) in stale {
            reassemblyBuffers.removeValue(forKey: seqId)
            expectedCounts.removeValue(forKey: seqId)
            reassemblyTimestamps.removeValue(forKey: seqId)
        }
    }

    private func generateSequenceId() -> Data {
        var bytes = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, 16, &bytes)
        if status != errSecSuccess {
            let uuid = UUID()
            return withUnsafeBytes(of: uuid.uuid) { Data($0) }
        }
        return Data(bytes)
    }

    private func wrapSingle(_ data: Data) -> Data {
        let sequenceId = generateSequenceId()
        var frame = Data()
        frame.append(sequenceId)
        var idx = UInt16(0).bigEndian
        frame.append(Data(bytes: &idx, count: 2))
        var total = UInt16(1).bigEndian
        frame.append(Data(bytes: &total, count: 2))
        var crc = crc32(data).bigEndian
        frame.append(Data(bytes: &crc, count: 4))
        frame.append(data)
        return frame
    }

    private func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc >> 1) ^ (crc & 1 != 0 ? 0xEDB88320 : 0)
            }
        }
        return crc ^ 0xFFFFFFFF
    }
}
