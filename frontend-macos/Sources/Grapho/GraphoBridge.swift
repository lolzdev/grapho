import Foundation

@_silgen_name("grapho_runtime_init")
private func c_grapho_runtime_init()

@_silgen_name("grapho_runtime_shutdown")
private func c_grapho_runtime_shutdown()

enum GraphoBridge {
    static func startRuntime() {
        c_grapho_runtime_init()
    }

    static func shutdownRuntime() {
        c_grapho_runtime_shutdown()
    }
}
