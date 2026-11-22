import Testing
import Foundation
@testable import Calc3DCore

@Suite struct PrintJobTests {
    @Test func jsonAntigoSemFotoContinuaLegivel() throws {
        let old = try JSONEncoder().encode(PrintJob.defaults)
        var object = try #require(JSONSerialization.jsonObject(with: old) as? [String: Any])
        object.removeValue(forKey: "imageID")
        let data = try JSONSerialization.data(withJSONObject: object)
        let job = try JSONDecoder().decode(PrintJob.self, from: data)
        #expect(job.imageID == nil)
    }

    @Test func fotoDaPecaSobreviveAoSalvar() throws {
        var job = PrintJob.defaults
        job.imageID = UUID()
        let copy = try JSONDecoder().decode(PrintJob.self, from: JSONEncoder().encode(job))
        #expect(copy.imageID == job.imageID)
    }
}
