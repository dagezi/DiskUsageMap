import Darwin

/// One entry from `getmntinfo(3)` — the same syscall-level source `mount`/`df`
/// read from. Used instead of `FileManager.mountedVolumeURLs` to enumerate
/// volumes: that Foundation API both hides `nobrowse` mounts and, more
/// fundamentally, reports every volume in a System/Data volume group under
/// the *paired* System volume's name — asking it about `/System/Volumes/Data`
/// directly still answers "Macintosh HD". `getmntinfo` plus `diskutil info`
/// per mount point (see APFSContainer) gives the real, distinguishable names.
struct MountEntry {
    let mountPoint: String
    let fsTypeName: String
}

enum MountTable {
    static func currentMounts() -> [MountEntry] {
        var mntbufp: UnsafeMutablePointer<statfs>?
        let count = getmntinfo(&mntbufp, MNT_NOWAIT)
        guard count > 0, let buf = mntbufp else { return [] }

        var result: [MountEntry] = []
        for i in 0..<Int(count) {
            let fs = buf[i]
            result.append(
                MountEntry(
                    mountPoint: cString(from: fs.f_mntonname),
                    fsTypeName: cString(from: fs.f_fstypename)
                )
            )
        }
        return result
    }

    private static func cString<T>(from tuple: T) -> String {
        withUnsafeBytes(of: tuple) { raw in
            raw.withMemoryRebound(to: CChar.self) { String(cString: $0.baseAddress!) }
        }
    }
}
