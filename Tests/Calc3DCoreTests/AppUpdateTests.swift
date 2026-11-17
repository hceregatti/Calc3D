import Testing
import Foundation
@testable import Calc3DCore

@Suite struct AppUpdateTests {
    @Test func comparaVersoes() {
        #expect(AppVersion("1.2.0")! > AppVersion("1.1.9")!)
        #expect(AppVersion("v1.10.0")! > AppVersion("1.9.0")!)
        #expect(AppVersion("1.1")! == AppVersion("1.1.0")!)
        #expect(AppVersion("abc") == nil)
    }

    @Test func interpretaRelease() throws {
        let json = """
        {"tag_name":"v1.2.0","name":"Calc3D v1.2.0","body":"## O que mudou\\n* Novo A\\n* Novo B","html_url":"https://github.com/x/y/releases/tag/v1.2.0",
         "assets":[{"name":"Calc3D.dmg","browser_download_url":"https://e.com/Calc3D.dmg"},{"name":"Calc3D-1.2.0.dmg","browser_download_url":"https://e.com/Calc3D-1.2.0.dmg"}]}
        """
        let info = try #require(ReleaseInfo.parse(Data(json.utf8)))
        #expect(info.version == AppVersion("1.2.0"))
        #expect(info.dmgURL?.lastPathComponent == "Calc3D-1.2.0.dmg")
        #expect(info.displayNotes == ["O que mudou", "• Novo A", "• Novo B"])
    }

    @Test func ignoraPreLancamento() {
        let json = #"{"tag_name":"v2.0.0","prerelease":true,"html_url":"https://e.com"}"#
        #expect(ReleaseInfo.parse(Data(json.utf8)) == nil)
    }
}
