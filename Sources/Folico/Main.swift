import Foundation
import FolicoApp
import Darwin

@main
struct Folico {
    static func main() {
        let arguments = CommandLine.arguments
            .dropFirst()
            .filter { !$0.hasPrefix("-psn_") }

        if arguments.isEmpty {
            FolicoDesktopApp.main()
        } else {
            Darwin.exit(Int32(FolicoCommandLine.run(arguments: Array(arguments))))
        }
    }
}
