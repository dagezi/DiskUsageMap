import Darwin

enum MountPoint {
    /// Resolves the real, non-virtualized mount point a path lives on, via `statfs(2)`.
    /// Unlike `stat(2)`'s `st_dev`, this is NOT flattened across firmlinks — it matches
    /// what `df`/`mount` report, which is what we need to detect true volume boundaries.
    static func resolve(_ path: String) -> String? {
        var buf = statfs()
        guard statfs(path, &buf) == 0 else { return nil }
        return withUnsafeBytes(of: &buf.f_mntonname) { raw -> String in
            raw.withMemoryRebound(to: CChar.self) { cstr in
                String(cString: cstr.baseAddress!)
            }
        }
    }
}
