//! Cache local des images (affiches, fonds) : des fichiers, pas SQLite.
//! La médiathèque reste consultable hors connexion.

use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};

use epikodi_domain::ports::ImageCache;
use epikodi_domain::{DomainError, DomainResult};

pub struct FsImageCache {
    root: PathBuf,
}

impl FsImageCache {
    pub fn new(root: impl Into<PathBuf>) -> Self {
        Self { root: root.into() }
    }

    pub fn root(&self) -> &Path {
        &self.root
    }

    /// Chemin absolu d'une image du cache, ou `None` si le chemin sort du
    /// cache (`..`, chemin absolu, lien symbolique) ou si le fichier n'existe
    /// pas.
    pub fn resolve(&self, relative: &str) -> Option<PathBuf> {
        let rel = Path::new(relative);
        if rel.is_absolute()
            || rel
                .components()
                .any(|c| !matches!(c, std::path::Component::Normal(_)))
        {
            return None;
        }
        // Aucun élément du chemin ne doit être un lien symbolique : un lien
        // dans le cache pourrait pointer vers n'importe quel fichier.
        let mut path = self.root.clone();
        for part in rel.components() {
            path.push(part);
            let meta = fs::symlink_metadata(&path).ok()?;
            if meta.file_type().is_symlink() {
                return None;
            }
        }
        fs::symlink_metadata(&path)
            .ok()
            .filter(|m| m.file_type().is_file())
            .map(|_| path)
    }
}

/// Écrit `bytes` dans `dest` sans jamais laisser un fichier à moitié écrit :
/// fichier temporaire du même dossier, `sync`, puis renommage (atomique).
/// Le renommage remplace un éventuel lien symbolique, sans suivre sa cible.
fn write_atomic(dest: &Path, bytes: &[u8]) -> std::io::Result<()> {
    let dir = dest.parent().unwrap_or(Path::new("."));
    let name = dest.file_name().unwrap_or_default().to_string_lossy();
    let tmp = dir.join(format!(".{name}.{}.tmp", rand::random::<u64>()));
    let result = (|| {
        let mut f = fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&tmp)?;
        f.write_all(bytes)?;
        f.sync_all()?;
        fs::rename(&tmp, dest)
    })();
    if result.is_err() {
        let _ = fs::remove_file(&tmp);
    }
    result
}

/// Nom de fichier sûr à partir d'une clé (`tmdb-movie-123`).
fn sanitize(key: &str) -> String {
    let s: String = key
        .chars()
        .map(|c| {
            if c.is_ascii_alphanumeric() || c == '-' || c == '_' {
                c
            } else {
                '_'
            }
        })
        .take(100)
        .collect();
    if s.is_empty() {
        "image".into()
    } else {
        s
    }
}

fn extension_for(bytes: &[u8]) -> &'static str {
    match bytes {
        [0x89, b'P', b'N', b'G', ..] => "png",
        [b'R', b'I', b'F', b'F', _, _, _, _, b'W', b'E', b'B', b'P', ..] => "webp",
        _ => "jpg",
    }
}

impl ImageCache for FsImageCache {
    fn store(&self, key: &str, bytes: &[u8]) -> DomainResult<String> {
        let dir = self.root.join("images");
        fs::create_dir_all(&dir).map_err(DomainError::internal)?;
        if fs::symlink_metadata(&dir).is_ok_and(|m| m.file_type().is_symlink()) {
            return Err(DomainError::Internal(
                "le dossier images du cache est un lien symbolique".into(),
            ));
        }
        let name = format!("{}.{}", sanitize(key), extension_for(bytes));
        write_atomic(&dir.join(&name), bytes).map_err(DomainError::internal)?;
        Ok(format!("images/{name}"))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn stocke_et_retrouve() {
        let dir = tempfile::tempdir().unwrap();
        let cache = FsImageCache::new(dir.path());
        let rel = cache
            .store("tmdb/movie:1", &[0x89, b'P', b'N', b'G', 1, 2])
            .unwrap();
        assert_eq!(rel, "images/tmdb_movie_1.png");
        assert!(cache.resolve(&rel).is_some());
    }

    #[test]
    fn refuse_de_sortir_du_cache() {
        let dir = tempfile::tempdir().unwrap();
        let cache = FsImageCache::new(dir.path());
        assert!(cache.resolve("../secret.key").is_none());
        assert!(cache.resolve("/etc/passwd").is_none());
        assert!(cache.resolve("images/absent.jpg").is_none());
    }

    #[test]
    fn reecrit_sans_fichier_temporaire_restant() {
        let dir = tempfile::tempdir().unwrap();
        let cache = FsImageCache::new(dir.path());
        cache.store("a", b"un").unwrap();
        let rel = cache.store("a", b"deux").unwrap();
        assert_eq!(fs::read(cache.resolve(&rel).unwrap()).unwrap(), b"deux");
        let files: Vec<_> = fs::read_dir(dir.path().join("images"))
            .unwrap()
            .map(|e| e.unwrap().file_name())
            .collect();
        assert_eq!(files.len(), 1, "{files:?}");
    }

    #[cfg(unix)]
    #[test]
    fn refuse_les_liens_symboliques() {
        let dir = tempfile::tempdir().unwrap();
        let cache = FsImageCache::new(dir.path().join("cache"));
        fs::create_dir_all(dir.path().join("cache/images")).unwrap();
        let secret = dir.path().join("private.txt");
        fs::write(&secret, b"secret").unwrap();
        std::os::unix::fs::symlink(&secret, dir.path().join("cache/images/poster.jpg")).unwrap();
        assert!(cache.resolve("images/poster.jpg").is_none());

        // dossier lien symbolique
        std::os::unix::fs::symlink(dir.path(), dir.path().join("cache/autre")).unwrap();
        assert!(cache.resolve("autre/private.txt").is_none());

        // écrire par-dessus le lien remplace le lien, pas sa cible
        let rel = cache.store("poster", b"image").unwrap();
        assert_eq!(rel, "images/poster.jpg");
        assert_eq!(fs::read(&secret).unwrap(), b"secret");
        assert!(cache.resolve(&rel).is_some());
    }
}
