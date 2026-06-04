import Foundation

@_silgen_name("grapho_runtime_init")
private func c_grapho_runtime_init()

@_silgen_name("grapho_runtime_shutdown")
private func c_grapho_runtime_shutdown()

@_silgen_name("grapho_add")
private func c_grapho_add(_ a: Int32, _ b: Int32) -> Int32

@_silgen_name("grapho_tick")
private func c_grapho_tick() -> Int32

@_silgen_name("grapho_hello")
private func c_grapho_hello() -> UnsafeMutablePointer<CChar>?

@_silgen_name("grapho_free_string")
private func c_grapho_free_string(_ ptr: UnsafeMutablePointer<CChar>?)

enum GraphoBridge {
    static func startRuntime() {
        c_grapho_runtime_init()
    }

    static func shutdownRuntime() {
        c_grapho_runtime_shutdown()
    }

    static func add(_ a: Int32, _ b: Int32) -> Int32 {
        c_grapho_add(a, b)
    }

    static func tick() -> Int32 {
        c_grapho_tick()
    }

    static func hello() -> String {
        guard let ptr = c_grapho_hello() else {
            return "(null)"
        }

        defer { c_grapho_free_string(ptr) }
        return String(cString: ptr)
    }
}
