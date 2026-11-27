//! `epikodi-core reset-pin` : PIN oublié, porte de secours.
//!
//! Lancée sur la machine du serveur (pas depuis la télécommande ni la TV) :
//! il faut y avoir accès, ce qu'un enfant devant la TV n'a pas. Seul le PIN
//! est effacé (favoris, listes, reprises gardés) ; à sa prochaine connexion,
//! la TV demande de choisir un nouveau code. Comptes triés par nom.
//!
//! ```text
//! epikodi-core reset-pin <nom>    PIN d'un compte
//! epikodi-core reset-pin --all    PIN de tous les comptes
//! ```

use epikodi_domain::ports::ProfileRepo;
use epikodi_domain::profile::Profile;
use epikodi_domain::DomainResult;

/// Comptes visés par la commande.
#[derive(Debug, PartialEq, Eq)]
pub enum Target {
    One(String),
    All,
}

pub const USAGE: &str =
    "usage : epikodi-core reset-pin <nom du compte>\n        epikodi-core reset-pin --all";

/// Lit les arguments après `reset-pin`.
pub fn parse(args: &[String]) -> Result<Target, String> {
    match args {
        [a] if a == "--all" => Ok(Target::All),
        [] => Err(USAGE.into()),
        [a] if a.starts_with('-') => Err(format!("option inconnue : {a}\n{USAGE}")),
        // un nom avec des espaces peut être donné sans guillemets
        names => Ok(Target::One(names.join(" "))),
    }
}

/// Résultat, à afficher.
#[derive(Debug, PartialEq, Eq)]
pub enum Outcome {
    /// PIN effacé pour ces comptes.
    Reset(Vec<String>),
    /// Ce compte est restreint (enfant) : il n'a pas de PIN.
    NoPin(String),
    /// Aucun compte de ce nom. Liste des noms existants.
    NotFound { name: String, existing: Vec<String> },
}

/// Efface le PIN des comptes visés. Nom : exact, sinon sans tenir compte
/// des majuscules.
pub fn reset_pins<S: ProfileRepo>(store: &S, target: &Target) -> DomainResult<Outcome> {
    let profiles = store.list_profiles()?;
    let chosen: Vec<&Profile> = match target {
        Target::All => profiles.iter().filter(|p| p.pin_hash.is_some()).collect(),
        Target::One(name) => {
            let name = name.trim();
            let found = profiles.iter().find(|p| p.name == name).or_else(|| {
                profiles
                    .iter()
                    .find(|p| p.name.to_lowercase() == name.to_lowercase())
            });
            match found {
                None => {
                    return Ok(Outcome::NotFound {
                        name: name.to_string(),
                        existing: profiles.iter().map(|p| p.name.clone()).collect(),
                    })
                }
                Some(p) if p.pin_hash.is_none() => return Ok(Outcome::NoPin(p.name.clone())),
                Some(p) => vec![p],
            }
        }
    };
    let mut names = Vec::new();
    for p in chosen {
        let mut next = p.clone();
        next.pin_hash = None;
        store.update_profile(&next)?;
        names.push(p.name.clone());
    }
    Ok(Outcome::Reset(names))
}

/// Texte affiché dans la console.
pub fn message(outcome: &Outcome) -> String {
    match outcome {
        Outcome::Reset(names) if names.is_empty() => "Aucun compte n'a de PIN.".into(),
        Outcome::Reset(names) => format!(
            "PIN effacé : {}.\nÀ la prochaine connexion, la TV demandera de choisir un nouveau code.",
            names.join(", ")
        ),
        Outcome::NoPin(name) => format!("« {name} » est un compte enfant : il n'a pas de PIN."),
        Outcome::NotFound { name, existing } if existing.is_empty() => {
            format!("Aucun compte « {name} » : il n'y a encore aucun compte.")
        }
        Outcome::NotFound { name, existing } => format!(
            "Aucun compte « {name} ». Comptes : {}.",
            existing.join(", ")
        ),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use epikodi_domain::profile::NewProfile;
    use epikodi_storage::Store;

    fn add(s: &Store, name: &str, restricted: bool) {
        s.create_profile(&NewProfile {
            name: name.into(),
            icon: None,
            language: "fr".into(),
            age: if restricted { 10 } else { 35 },
            is_restricted: restricted,
            pin_hash: (!restricted).then(|| "hash".to_string()),
        })
        .unwrap();
    }

    fn pins(s: &Store) -> Vec<(String, bool)> {
        s.list_profiles()
            .unwrap()
            .into_iter()
            .map(|p| (p.name, p.pin_hash.is_some()))
            .collect()
    }

    fn args(a: &[&str]) -> Vec<String> {
        a.iter().map(|s| s.to_string()).collect()
    }

    #[test]
    fn arguments() {
        assert_eq!(parse(&args(&["--all"])), Ok(Target::All));
        assert_eq!(parse(&args(&["Marc"])), Ok(Target::One("Marc".into())));
        assert_eq!(
            parse(&args(&["Jean", "Paul"])),
            Ok(Target::One("Jean Paul".into()))
        );
        assert!(parse(&[]).is_err());
        assert!(parse(&args(&["--tout"])).is_err());
    }

    #[test]
    fn un_compte_par_son_nom() {
        let s = Store::in_memory();
        add(&s, "Marc", false);
        add(&s, "Julie", false);
        add(&s, "Léa", true);
        let out = reset_pins(&s, &Target::One("marc".into())).unwrap();
        assert_eq!(out, Outcome::Reset(vec!["Marc".into()]));
        assert_eq!(
            pins(&s),
            vec![
                ("Julie".into(), true),
                ("Léa".into(), false),
                ("Marc".into(), false)
            ]
        );
    }

    #[test]
    fn tous_les_comptes() {
        let s = Store::in_memory();
        add(&s, "Marc", false);
        add(&s, "Julie", false);
        add(&s, "Léa", true);
        let out = reset_pins(&s, &Target::All).unwrap();
        assert_eq!(out, Outcome::Reset(vec!["Julie".into(), "Marc".into()]));
        assert!(pins(&s).iter().all(|(_, pin)| !pin));
        assert_eq!(
            reset_pins(&s, &Target::All).unwrap(),
            Outcome::Reset(vec![])
        );
    }

    #[test]
    fn compte_enfant_ou_inconnu() {
        let s = Store::in_memory();
        add(&s, "Marc", false);
        add(&s, "Léa", true);
        assert_eq!(
            reset_pins(&s, &Target::One("Léa".into())).unwrap(),
            Outcome::NoPin("Léa".into())
        );
        assert_eq!(
            reset_pins(&s, &Target::One("Zoé".into())).unwrap(),
            Outcome::NotFound {
                name: "Zoé".into(),
                existing: vec!["Léa".into(), "Marc".into()]
            }
        );
        assert_eq!(
            pins(&s),
            vec![("Léa".into(), false), ("Marc".into(), true)],
            "rien n'a changé"
        );
    }
}
