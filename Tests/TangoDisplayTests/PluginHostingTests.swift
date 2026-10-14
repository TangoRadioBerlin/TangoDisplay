import Foundation
import TangoDisplayCore

func runPluginHostingTests() {
    let mjuc = PluginComponentKey(manufacturer: "KlHm", subType: "MJUC")
    let proQ = PluginComponentKey(manufacturer: "FabF", subType: "FQ4p")
    let other = PluginComponentKey(manufacturer: "Acme", subType: "Comp")

    suite("PluginComponentKey") {
        test("four-char codes round-trip to the OSType values AudioComponent uses") {
            try expectEqual(proQ.manufacturer, 0x4661_6246)   // 'FabF'
            try expectEqual(proQ.subType, 0x4651_3470)        // 'FQ4p'
            try expectEqual(proQ.displayCode, "FabF/FQ4p")
        }
        test("JSON round-trip") {
            let data = try JSONEncoder().encode([proQ, mjuc])
            try expectEqual(try JSONDecoder().decode([PluginComponentKey].self, from: data), [proQ, mjuc])
        }
    }

    suite("PluginHostingRules.loadsInProcess") {
        test("default is out-of-process") {
            try expect(!PluginHostingRules.loadsInProcess(other, builtIn: [mjuc], optIns: []))
        }
        test("the built-in allowlist loads in-process") {
            try expect(PluginHostingRules.loadsInProcess(mjuc, builtIn: [mjuc], optIns: []))
        }
        test("a user opt-in loads in-process") {
            try expect(PluginHostingRules.loadsInProcess(proQ, builtIn: [mjuc], optIns: [proQ]))
        }
    }

    suite("PluginHostingRules.recover — undo an opt-in after an unexpected exit") {
        test("a clean previous exit changes nothing") {
            let r = PluginHostingRules.recover(optIns: [proQ], loadedAtExit: [])
            try expectEqual(r.optIns, [proQ])
            try expect(r.revoked.isEmpty)
        }
        test("an opt-in plugin that was loaded when the app died is switched back") {
            let r = PluginHostingRules.recover(optIns: [proQ, other], loadedAtExit: [proQ])
            try expectEqual(r.optIns, [other])
            try expectEqual(r.revoked, [proQ])
        }
        test("only opt-ins are revoked; a stale marker for anything else is ignored") {
            let r = PluginHostingRules.recover(optIns: [proQ], loadedAtExit: [mjuc])
            try expectEqual(r.optIns, [proQ])
            try expect(r.revoked.isEmpty)
        }
    }
}
