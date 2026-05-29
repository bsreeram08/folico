import Foundation
import FolicoApp
import Darwin

@main
struct Folico {
    static func main() {
        if CommandLine.arguments.count > 1 {
            Darwin.exit(Int32(FolicoCommandLine.run(arguments: Array(CommandLine.arguments.dropFirst()))))
        } else {
            FolicoDesktopApp.main()
        }
    }
}
