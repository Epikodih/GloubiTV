mod config;
mod mdns;
mod reset;
mod wiring;

use std::{fs, net::SocketAddr, process};

use epikodi_api::router;
use tracing_subscriber::EnvFilter;

use config::Config;

#[tokio::main]
async fn main() {
    // Commande de secours : `epikodi-core reset-pin <nom> | --all`.
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.first().map(String::as_str) == Some("reset-pin") {
        process::exit(reset_pin(&args[1..]));
    }

    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")),
        )
        .init();

    let config = Config::load().unwrap_or_else(|e| {
        tracing::error!("configuration invalide : {e}");
        process::exit(1);
    });

    let data_dir = &config.storage.data_dir;
    fs::create_dir_all(data_dir).unwrap_or_else(|e| {
        tracing::error!(dir = %data_dir.display(), "impossible de créer le dossier de données : {e}");
        process::exit(1);
    });

    // --- Réseau ---
    let host = config
        .server
        .host
        .clone()
        .or_else(|| local_ip_address::local_ip().ok().map(|ip| ip.to_string()));
    tracing::info!(?host, "adresse annoncée aux remotes");

    let state = wiring::app_state(&config, host.clone());

    // 1. On écoute tout de suite : la TV, lancée en même temps, reçoit 503
    //    (« pas prêt ») tant que la base n'est pas ouverte.
    let addr = SocketAddr::new(config.server.bind, config.server.port);
    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .unwrap_or_else(|e| {
            tracing::error!(%addr, "impossible d'écouter (port déjà utilisé ?) : {e}");
            process::exit(1);
        });
    tracing::info!(%addr, "serveur à l'écoute");
    let app = router(state.clone()).into_make_service_with_connect_info::<SocketAddr>();
    let server = tokio::spawn(async move {
        axum::serve(listener, app)
            .with_graceful_shutdown(shutdown_signal())
            .await
    });

    // 2. Base : créée si absente, migrations appliquées. Échec = arrêt propre.
    let st = state.clone();
    let opened = tokio::task::spawn_blocking(move || st.open_db()).await;
    match opened {
        Ok(Ok(())) => tracing::info!(dir = %data_dir.display(), "base de données prête"),
        Ok(Err(e)) => {
            tracing::error!("impossible d'ouvrir la base : {e}");
            process::exit(1);
        }
        Err(e) => {
            tracing::error!("ouverture de la base interrompue : {e}");
            process::exit(1);
        }
    }

    // 3. Annonce mDNS (la télécommande trouve le serveur toute seule).
    let _announcement = match (&host, config.server.mdns) {
        (Some(ip), true) => match mdns::announce(&config.server.name, ip, config.server.port) {
            Ok(a) => {
                tracing::info!(service = mdns::SERVICE_TYPE, "annonce mDNS active");
                Some(a)
            }
            Err(e) => {
                tracing::warn!("annonce mDNS impossible (saisie manuelle de l'IP possible) : {e}");
                None
            }
        },
        _ => None,
    };

    match server.await {
        Ok(Ok(())) => tracing::info!("serveur arrêté"),
        Ok(Err(e)) => {
            tracing::error!("erreur du serveur : {e}");
            process::exit(1);
        }
        Err(e) => {
            tracing::error!("serveur interrompu : {e}");
            process::exit(1);
        }
    }
}

/// `reset-pin` : efface le PIN d'un compte (ou de tous) dans la base du
/// dossier de données configuré. Possible même serveur lancé (SQLite).
/// Renvoie le code de sortie.
fn reset_pin(args: &[String]) -> i32 {
    let target = match reset::parse(args) {
        Ok(t) => t,
        Err(e) => {
            eprintln!("{e}");
            return 2;
        }
    };
    let config = match Config::load() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("configuration invalide : {e}");
            return 1;
        }
    };
    let data_dir = &config.storage.data_dir;
    if !data_dir.join("epikodi.db").exists() {
        eprintln!(
            "pas de base dans {} : lancez la commande depuis le dossier du serveur (ou EPIKODI_CONFIG).",
            data_dir.display()
        );
        return 1;
    }
    let store = match wiring::store_factory(data_dir)() {
        Ok(s) => s,
        Err(e) => {
            eprintln!("impossible d'ouvrir la base : {e}");
            return 1;
        }
    };
    match reset::reset_pins(&store, &target) {
        Ok(outcome) => {
            println!("{}", reset::message(&outcome));
            match outcome {
                reset::Outcome::Reset(_) => 0,
                _ => 1,
            }
        }
        Err(e) => {
            eprintln!("échec : {e}");
            1
        }
    }
}

async fn shutdown_signal() {
    let _ = tokio::signal::ctrl_c().await;
    tracing::info!("arrêt demandé");
}
