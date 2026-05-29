import Foundation

enum BuiltInRules {
    static let defaultRules: [FolderIconRule] = [
        FolderIconRule(
            id: "finance",
            label: "Finance",
            keywords: ["invoice", "invoices", "billing", "tax", "taxes", "receipt", "receipts", "payments", "payroll"],
            iconId: "receipt",
            priority: 100
        ),
        FolderIconRule(
            id: "code",
            label: "Developer",
            keywords: ["code", "repo", "repos", "github", "gitlab", "project", "projects", "src", "source"],
            iconId: "code",
            priority: 90
        ),
        FolderIconRule(
            id: "photos",
            label: "Photos",
            keywords: ["photo", "photos", "image", "images", "screenshot", "screenshots", "camera", "gallery"],
            iconId: "image",
            priority: 80
        ),
        FolderIconRule(
            id: "design",
            label: "Design",
            keywords: ["design", "figma", "sketch", "brand", "assets", "mockups", "creative"],
            iconId: "design",
            priority: 75
        ),
        FolderIconRule(
            id: "archive",
            label: "Archive",
            keywords: ["archive", "archives", "backup", "backups", "old", "vault"],
            iconId: "archive",
            priority: 70
        ),
        FolderIconRule(
            id: "movies",
            label: "Movies",
            keywords: ["movie", "movies", "video", "videos", "film", "films", "cinema", "clips"],
            iconId: "movie",
            priority: 65
        ),
        FolderIconRule(
            id: "music",
            label: "Music",
            keywords: ["music", "audio", "song", "songs", "album", "albums", "playlist", "playlists"],
            iconId: "music",
            priority: 60
        ),
        FolderIconRule(
            id: "documents",
            label: "Documents",
            keywords: ["document", "documents", "docs", "paperwork", "forms", "files"],
            iconId: "document",
            priority: 55
        ),
        FolderIconRule(
            id: "school",
            label: "School",
            keywords: ["school", "college", "university", "class", "classes", "course", "courses", "study"],
            iconId: "school",
            priority: 50
        ),
        FolderIconRule(
            id: "clients",
            label: "Clients",
            keywords: ["client", "clients", "customer", "customers", "agency", "accounts"],
            iconId: "briefcase",
            priority: 45
        ),
        FolderIconRule(
            id: "presentations",
            label: "Presentations",
            keywords: ["presentation", "presentations", "deck", "decks", "slides", "keynote", "pitch"],
            iconId: "presentation",
            priority: 40
        )
    ]
}

enum BuiltInIcons {
    static let all: [IconDescriptor] = [
        IconDescriptor(id: "receipt", label: "Receipt", symbolName: "receipt", tintName: "green"),
        IconDescriptor(id: "code", label: "Code", symbolName: "chevron.left.forwardslash.chevron.right", tintName: "blue"),
        IconDescriptor(id: "image", label: "Image", symbolName: "photo", tintName: "pink"),
        IconDescriptor(id: "design", label: "Design", symbolName: "paintbrush.pointed", tintName: "purple"),
        IconDescriptor(id: "archive", label: "Archive", symbolName: "archivebox", tintName: "gray"),
        IconDescriptor(id: "movie", label: "Movie", symbolName: "film", tintName: "red"),
        IconDescriptor(id: "music", label: "Music", symbolName: "music.note", tintName: "indigo"),
        IconDescriptor(id: "document", label: "Document", symbolName: "doc.text", tintName: "cyan"),
        IconDescriptor(id: "school", label: "School", symbolName: "graduationcap", tintName: "orange"),
        IconDescriptor(id: "briefcase", label: "Briefcase", symbolName: "briefcase", tintName: "brown"),
        IconDescriptor(id: "presentation", label: "Presentation", symbolName: "chart.bar.doc.horizontal", tintName: "mint")
    ]

    static func descriptor(for id: String) -> IconDescriptor {
        all.first { $0.id == id } ?? all[0]
    }
}
