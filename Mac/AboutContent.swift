import Foundation
import SwiftUI

/// Contenuti della pagina Info: è l'unico file da toccare per aggiornare link e altre app.
/// Per aggiungere un'app: una voce in `apps`, l'icona in `Assets.xcassets/App_<id>.imageset`
/// e la frase nel catalogo con chiave `about.app.<id>` (5 lingue).
enum AboutContent {
    /// Dove si scarica un'app.
    struct Store: Identifiable {
        let name: String
        let url: URL
        var id: URL { url }

        static func appStore(_ path: String) -> Store { Store(name: "App Store", url: URL(string: "https://apps.apple.com/\(path)")!) }
        static func googlePlay(_ package: String) -> Store { Store(name: "Google Play", url: URL(string: "https://play.google.com/store/apps/details?id=\(package)")!) }
        static func github(_ repository: String) -> Store { Store(name: "GitHub", url: URL(string: "https://github.com/joemockdao/\(repository)")!) }
    }

    struct App: Identifiable {
        let id: String
        let name: String
        let stores: [Store]

        var summary: LocalizedStringKey { .key("about.app.\(id)") }
        var icon: String { "App_\(id)" }
    }

    /// Repository pubblico di PocketDisplayJoe. `nil` = la riga resta senza link finché non è pubblicato.
    static let projectURL: URL? = nil

    static let apps: [App] = [
        App(id: "sleeprec", name: "SleepRec", stores: [.appStore("it/app/sleeprec/id1528754113"), .googlePlay("it.joe.sleeprec")]),
        App(id: "joenote", name: "JoeNote", stores: [.appStore("it/app/joenote/id6738133424"), .googlePlay("it.note.joeNote")]),
        App(id: "screenshotjoe", name: "ScreenShotJoe", stores: [.github("ScreenShotJoe")]),
        App(id: "klipzen", name: "Klipzen", stores: [.github("Klipzen")]),
        App(id: "cleanmacjoe", name: "CleanMacJoe", stores: [.github("CleanMacJoe")]),
    ]
}
