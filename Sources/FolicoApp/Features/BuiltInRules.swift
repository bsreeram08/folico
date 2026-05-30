import Foundation

enum BuiltInRules {
    static let defaultRules: [FolderIconRule] = [
        FolderIconRule(
            id: "finance",
            label: "Finance",
            keywords: ["invoice", "invoices", "billing", "tax", "taxes", "receipt", "receipts", "payments", "payroll"],
            pathKeywords: ["finance", "accounting", "accounts", "bank", "tax"],
            iconId: "receipt",
            priority: 100,
            folderColorName: "green",
            symbolColorName: "green"
        ),
        FolderIconRule(
            id: "code",
            label: "Developer",
            keywords: ["code", "repo", "repos", "github", "gitlab", "project", "projects", "src", "source"],
            pathKeywords: ["workspace", "developer", "development", "github", "gitlab", "src"],
            iconId: "code",
            priority: 90,
            folderColorName: "blue",
            symbolColorName: "blue"
        ),
        FolderIconRule(
            id: "photos",
            label: "Photos",
            keywords: ["photo", "photos", "image", "images", "screenshot", "screenshots", "camera", "gallery"],
            pathKeywords: ["pictures", "photos", "screenshots", "camera"],
            iconId: "image",
            priority: 80,
            folderColorName: "pink",
            symbolColorName: "pink"
        ),
        FolderIconRule(
            id: "design",
            label: "Design",
            keywords: ["design", "figma", "sketch", "brand", "assets", "mockups", "creative"],
            pathKeywords: ["design", "brand", "assets", "creative"],
            iconId: "design",
            priority: 75,
            folderColorName: "purple",
            symbolColorName: "purple"
        ),
        FolderIconRule(
            id: "games",
            label: "Games",
            keywords: ["game", "games", "gaming", "steam", "rom", "roms", "emulator", "emulators"],
            pathKeywords: ["games", "gaming", "steam", "roms", "emulators"],
            iconId: "game",
            priority: 72,
            folderColorName: "purple",
            symbolColorName: "purple"
        ),
        FolderIconRule(
            id: "archive",
            label: "Archive",
            keywords: ["archive", "archives", "backup", "backups", "old", "vault"],
            pathKeywords: ["archive", "backup", "backups", "vault"],
            iconId: "archive",
            priority: 70,
            folderColorName: "gray",
            symbolColorName: "gray"
        ),
        FolderIconRule(
            id: "movies",
            label: "Movies",
            keywords: ["movie", "movies", "video", "videos", "film", "films", "cinema", "clips"],
            pathKeywords: ["movies", "videos", "media", "cinema"],
            iconId: "movie",
            priority: 65,
            folderColorName: "red",
            symbolColorName: "red"
        ),
        FolderIconRule(
            id: "music",
            label: "Music",
            keywords: ["music", "audio", "song", "songs", "album", "albums", "playlist", "playlists"],
            pathKeywords: ["music", "audio", "media"],
            iconId: "music",
            priority: 60,
            folderColorName: "indigo",
            symbolColorName: "indigo"
        ),
        FolderIconRule(
            id: "documents",
            label: "Documents",
            keywords: ["document", "documents", "docs", "paperwork", "forms", "files"],
            pathKeywords: ["documents", "docs", "paperwork"],
            iconId: "document",
            priority: 55,
            folderColorName: "cyan",
            symbolColorName: "cyan"
        ),
        FolderIconRule(
            id: "books",
            label: "Books",
            keywords: ["book", "books", "ebook", "ebooks", "library", "reading", "kindle"],
            pathKeywords: ["books", "library", "reading"],
            iconId: "book",
            priority: 52,
            folderColorName: "orange",
            symbolColorName: "orange"
        ),
        FolderIconRule(
            id: "school",
            label: "School",
            keywords: ["school", "college", "university", "class", "classes", "course", "courses", "study"],
            pathKeywords: ["school", "college", "university", "study", "classes"],
            iconId: "school",
            priority: 50,
            folderColorName: "orange",
            symbolColorName: "orange"
        ),
        FolderIconRule(
            id: "clients",
            label: "Clients",
            keywords: ["client", "clients", "customer", "customers", "agency", "accounts"],
            pathKeywords: ["clients", "customers", "agency", "work"],
            iconId: "briefcase",
            priority: 45,
            folderColorName: "brown",
            symbolColorName: "brown"
        ),
        FolderIconRule(
            id: "downloads",
            label: "Downloads",
            keywords: ["download", "downloads", "installer", "installers", "pkg", "packages"],
            pathKeywords: ["downloads"],
            iconId: "download",
            priority: 43,
            folderColorName: "blue",
            symbolColorName: "blue"
        ),
        FolderIconRule(
            id: "presentations",
            label: "Presentations",
            keywords: ["presentation", "presentations", "deck", "decks", "slides", "keynote", "pitch"],
            pathKeywords: ["presentations", "slides", "decks", "pitch"],
            iconId: "presentation",
            priority: 40,
            folderColorName: "mint",
            symbolColorName: "mint"
        )
    ]

    static let generatedRules: [FolderIconRule] = [
        FolderIconRule(
            id: "generated-code",
            label: "Generated Developer",
            keywords: ["app", "build", "dev", "lib", "module", "package", "script"],
            pathKeywords: ["workspace", "source", "repos"],
            iconId: "code",
            priority: 80,
            folderColorName: "blue",
            symbolColorName: "blue"
        ),
        FolderIconRule(
            id: "generated-games",
            label: "Generated Games",
            keywords: ["game", "games", "gaming", "steam", "rom", "roms", "emulator", "emulators"],
            pathKeywords: ["games", "gaming", "steam"],
            iconId: "game",
            priority: 75,
            folderColorName: "purple",
            symbolColorName: "purple"
        ),
        FolderIconRule(
            id: "generated-money",
            label: "Generated Money",
            keywords: ["money", "order", "purchase", "sale"],
            pathKeywords: ["finance", "business"],
            iconId: "receipt",
            priority: 70,
            folderColorName: "green",
            symbolColorName: "green"
        ),
        FolderIconRule(
            id: "generated-presentation",
            label: "Generated Presentation",
            keywords: ["meeting", "review", "proposal"],
            pathKeywords: ["presentations", "slides"],
            iconId: "presentation",
            priority: 60,
            folderColorName: "mint",
            symbolColorName: "mint"
        ),
        FolderIconRule(
            id: "generated-document",
            label: "Generated Document",
            keywords: ["note", "draft", "writing", "spec"],
            pathKeywords: ["documents", "docs"],
            iconId: "document",
            priority: 50,
            folderColorName: "cyan",
            symbolColorName: "cyan"
        ),
        FolderIconRule(
            id: "generated-books",
            label: "Generated Books",
            keywords: ["book", "books", "ebook", "ebooks", "library", "reading", "kindle"],
            pathKeywords: ["books", "library", "reading"],
            iconId: "book",
            priority: 45,
            folderColorName: "orange",
            symbolColorName: "orange"
        ),
        FolderIconRule(
            id: "generated-image",
            label: "Generated Image",
            keywords: ["asset", "visual", "export"],
            pathKeywords: ["assets", "design"],
            iconId: "image",
            priority: 40,
            folderColorName: "pink",
            symbolColorName: "pink"
        ),
        FolderIconRule(
            id: "generated-archive",
            label: "Generated Archive",
            keywords: ["old", "done", "complete"],
            pathKeywords: ["archive", "backups"],
            iconId: "archive",
            priority: 30,
            folderColorName: "gray",
            symbolColorName: "gray"
        )
    ]

    static func mergeDefaultRules(into rules: [FolderIconRule]) -> [FolderIconRule] {
        merge(defaultRules, into: rules)
    }

    static func mergeGeneratedRules(into rules: [FolderIconRule]) -> [FolderIconRule] {
        merge(generatedRules, into: rules)
    }

    private static func merge(_ defaults: [FolderIconRule], into rules: [FolderIconRule]) -> [FolderIconRule] {
        var merged = rules
        var ids = Set(rules.map(\.id))

        for rule in defaults where !ids.contains(rule.id) {
            merged.append(rule)
            ids.insert(rule.id)
        }

        return merged.sorted {
            if $0.priority == $1.priority { return $0.label < $1.label }
            return $0.priority > $1.priority
        }
    }

    static func isBuiltInRuleID(_ id: String) -> Bool {
        defaultRules.contains { $0.id == id }
    }
}

enum BuiltInIcons {
    static let all: [IconDescriptor] = [
        IconDescriptor(id: "folder", label: "Folder", symbolName: "folder", tintName: "blue"),
        IconDescriptor(id: "receipt", label: "Receipt", symbolName: "receipt", tintName: "green"),
        IconDescriptor(id: "code", label: "Code", symbolName: "chevron.left.forwardslash.chevron.right", tintName: "blue"),
        IconDescriptor(id: "image", label: "Image", symbolName: "photo", tintName: "pink"),
        IconDescriptor(id: "design", label: "Design", symbolName: "paintbrush.pointed", tintName: "purple"),
        IconDescriptor(id: "game", label: "Game", symbolName: "gamecontroller", tintName: "purple"),
        IconDescriptor(id: "archive", label: "Archive", symbolName: "archivebox", tintName: "gray"),
        IconDescriptor(id: "movie", label: "Movie", symbolName: "film", tintName: "red"),
        IconDescriptor(id: "music", label: "Music", symbolName: "music.note", tintName: "indigo"),
        IconDescriptor(id: "document", label: "Document", symbolName: "doc.text", tintName: "cyan"),
        IconDescriptor(id: "book", label: "Book", symbolName: "book.closed", tintName: "orange"),
        IconDescriptor(id: "school", label: "School", symbolName: "graduationcap", tintName: "orange"),
        IconDescriptor(id: "briefcase", label: "Briefcase", symbolName: "briefcase", tintName: "brown"),
        IconDescriptor(id: "download", label: "Download", symbolName: "arrow.down.circle", tintName: "blue"),
        IconDescriptor(id: "presentation", label: "Presentation", symbolName: "chart.bar.doc.horizontal", tintName: "mint")
    ]

    static func descriptor(for id: String) -> IconDescriptor {
        all.first { $0.id == id } ?? all[0]
    }
}
