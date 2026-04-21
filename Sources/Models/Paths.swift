import Foundation

/// Returns the resolved URL for ~/.claude/, following symlinks.
/// This is necessary because ~/.claude may be a symlink (e.g. from a dotfiles repo),
/// and FileManager's URL-based APIs fail on symlinked directories.
func claudeDirURL() -> URL {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let path = home.appendingPathComponent(".claude").path
    let resolved = (path as NSString).resolvingSymlinksInPath
    return URL(fileURLWithPath: resolved)
}

/// Returns a resolved URL for a path under ~/.claude/.
/// e.g. claudePath("plugins/cache") → resolved real path
func claudePath(_ subpath: String) -> URL {
    claudeDirURL().appendingPathComponent(subpath)
}

/// Returns the resolved home directory URL.
func homeURL() -> URL {
    FileManager.default.homeDirectoryForCurrentUser
}
