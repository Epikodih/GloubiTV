// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get connectingToServer => 'Connexion au serveur';

  @override
  String get retry => 'Réessayer';

  @override
  String get retryConnectionLabel => 'Réessayer de se connecter au serveur';

  @override
  String unexpectedError(String details) {
    return 'Erreur inattendue : $details';
  }

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get createAccountButton => 'Créer le compte';

  @override
  String get creating => 'Création...';

  @override
  String get back => 'Retour';

  @override
  String get name => 'Nom';

  @override
  String get nameHint => 'Prénom ou pseudo';

  @override
  String get enterName => 'Entrez un nom.';

  @override
  String get choosePhoto => 'Choisir ma photo';

  @override
  String get imagePickError => 'Impossible de choisir une image ici.';

  @override
  String avatarIcon(int number) {
    return 'Icône $number';
  }

  @override
  String avatarIconSelected(int number) {
    return 'Icône $number, sélectionnée';
  }

  @override
  String get age => 'Âge';

  @override
  String ageYears(int age) {
    return '$age ans';
  }

  @override
  String get decreaseAge => 'Diminuer l\'âge';

  @override
  String get increaseAge => 'Augmenter l\'âge';

  @override
  String get language => 'Langue';

  @override
  String get childProfile => 'Profil enfant';

  @override
  String get childProfileSemantic => 'Profil enfant (contrôle parental)';

  @override
  String get yes => 'Oui';

  @override
  String get no => 'Non';

  @override
  String get noContentBlocked => 'Aucun contenu bloqué';

  @override
  String get noContentBlockedAdult => 'Aucun contenu bloqué (18 ans et +)';

  @override
  String blocksRatingAndAbove(int rating) {
    return 'Bloque les +$rating et plus';
  }

  @override
  String get pairingTitle => 'Connecter la télécommande';

  @override
  String get pairingInstruction =>
      'Scannez le QR code ou saisissez le code dans l’application.';

  @override
  String get newCode => 'Nouveau code';

  @override
  String newCodeCooldown(int seconds) {
    return 'Nouveau code ($seconds s)';
  }

  @override
  String get newCodeSemantics =>
      'Générer un nouveau code et un nouveau QR code';

  @override
  String get newCodeCoolingSemantics =>
      'Nouveau code, disponible dans quelques secondes';

  @override
  String expiresIn(String time) {
    return 'Expire dans $time';
  }

  @override
  String expiresSemantics(int minutes) {
    return 'Le code expire dans $minutes minutes';
  }

  @override
  String pairingCodeSemantics(String code) {
    return 'Code d’appairage : $code';
  }

  @override
  String get pairingQrSemantics => 'QR code d’appairage';

  @override
  String get switchLanguageLabel => 'Changer de langue';

  @override
  String get noAccountYet => 'Aucun compte pour l’instant';

  @override
  String get whoIsWatching => 'Qui regarde ?';

  @override
  String get createOrGuest => 'Créez un compte ou regardez en tant qu’invité';

  @override
  String get createCard => 'Créer';

  @override
  String get guestCard => 'Invité';

  @override
  String get continueAsGuest => 'Continuer en invité';

  @override
  String accountSemantics(String name) {
    return 'Compte $name';
  }

  @override
  String accountLockedSemantics(String name) {
    return 'Compte $name, protégé par un code PIN';
  }

  @override
  String get pairingButton => 'Appairage';

  @override
  String get backToPairingLabel => 'Revenir à l’écran d’appairage';

  @override
  String get profile => 'Profil';

  @override
  String profileMenuSemantics(String name) {
    return 'Menu du profil $name';
  }

  @override
  String get closeMenu => 'Fermer le menu';

  @override
  String get switchProfile => 'Changer de profil';

  @override
  String get pinTitle => 'Code PIN requis';

  @override
  String get pinSubtitle =>
      'Entrez le code PIN pour modifier la restriction d’âge.';

  @override
  String get pinWrong => 'Code PIN incorrect.';

  @override
  String pinDigitSemantics(String digit) {
    return 'Chiffre $digit';
  }

  @override
  String get deleteDigit => 'Effacer';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get saving => 'Enregistrement...';

  @override
  String get pinWillBeAsked => 'Le code PIN sera demandé à l’enregistrement.';

  @override
  String get sectionMovies => 'Films';

  @override
  String get sectionSeries => 'Séries';

  @override
  String get sectionMusic => 'Musique';

  @override
  String get sectionPodcasts => 'Podcasts';

  @override
  String get libraryLoadError => 'Impossible de charger la médiathèque.';

  @override
  String get noMediaForProfile => 'Aucun média disponible pour ce profil.';

  @override
  String get guestName => 'Invité';

  @override
  String get navSearch => 'Rechercher';

  @override
  String get navHome => 'Accueil';

  @override
  String get navWatchlist => 'À regarder';

  @override
  String get navFavorites => 'Favoris';

  @override
  String get libraryNavigation => 'Menu de la médiathèque';

  @override
  String get searchHint => 'Rechercher dans tout le media center';

  @override
  String get settings => 'Paramètres';

  @override
  String get sourcesTitle => 'Dossiers du media center';

  @override
  String get sourcesHint =>
      'Les dossiers que le media center scanne pour remplir la médiathèque. Tape un chemin (clavier du téléphone) ou parcours les dossiers.';

  @override
  String get sourcePathLabel => 'Chemin du dossier';

  @override
  String get sourcePathHint => 'D:\\Films ou smb://nas/films';

  @override
  String get browse => 'Parcourir…';

  @override
  String get addSource => 'Ajouter';

  @override
  String get removeSource => 'Retirer';

  @override
  String get scanAll => 'Tout scanner';

  @override
  String scanAllStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Scan des $count dossiers lancé.',
      one: 'Scan d’un dossier lancé.',
      zero: 'Aucun dossier à scanner.',
    );
    return '$_temp0';
  }

  @override
  String get rescan => 'Rescanner';

  @override
  String get noSources =>
      'Aucun dossier pour l’instant : ajoutes-en un pour remplir la médiathèque.';

  @override
  String get enterFolder => 'Indique d’abord un dossier.';

  @override
  String get folderPickError => 'Impossible d’ouvrir le sélecteur de dossier.';

  @override
  String get sourcesLoadError => 'Impossible de charger les dossiers.';

  @override
  String get sourceOnline => 'En ligne';

  @override
  String get sourceOffline => 'Hors ligne';

  @override
  String get sourceError => 'Erreur';

  @override
  String get sourceUnknown => 'Pas encore vérifié';

  @override
  String get neverScanned => 'Jamais scanné';

  @override
  String lastScan(String date) {
    return 'Dernier scan : $date';
  }

  @override
  String sourceMediaCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count médias',
      one: '1 média',
      zero: 'Aucun média',
    );
    return '$_temp0';
  }

  @override
  String sourceAdded(String name) {
    return '« $name » ajouté : le scan commence.';
  }

  @override
  String sourceRemoved(String name) {
    return '« $name » retiré.';
  }

  @override
  String scanStarted(String name) {
    return 'Scan de « $name » lancé.';
  }

  @override
  String removeSourceConfirm(String name) {
    return 'Retirer « $name » ? Ses médias disparaîtront de la médiathèque (les fichiers ne sont pas supprimés).';
  }

  @override
  String get close => 'Fermer';

  @override
  String get play => 'Lecture';

  @override
  String get playSoon => 'La lecture arrive bientôt.';

  @override
  String get playRequestError => 'Impossible de lancer la lecture.';

  @override
  String get addFavorite => 'Ajouter aux favoris';

  @override
  String get inFavorites => 'Dans les favoris';

  @override
  String get addWatchlist => 'À regarder plus tard';

  @override
  String get inWatchlist => 'Dans « À regarder »';

  @override
  String get listUpdateError => 'Impossible de mettre à jour la liste.';

  @override
  String get mediaDetailsLoadError =>
      'Impossible de charger la fiche du média.';

  @override
  String get noOverview => 'Pas encore de résumé pour ce média.';

  @override
  String get fileMissing => 'Fichier introuvable : lecture impossible.';

  @override
  String get notRated => 'Non classé';

  @override
  String get allAges => 'Tous publics';

  @override
  String ageRating(int age) {
    return '$age+';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHours(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get filters => 'Filtres';

  @override
  String filtersActive(int count) {
    return 'Filtres, $count actifs';
  }

  @override
  String get clearFilters => 'Effacer les filtres';

  @override
  String get filterType => 'Type';

  @override
  String get filterGenre => 'Genre';

  @override
  String get filterAge => 'Âge';

  @override
  String get filterAll => 'Tous';

  @override
  String ageMax(int age) {
    return '$age ans max';
  }

  @override
  String get emptyWatchlist => 'Ta liste « À regarder » est vide.';

  @override
  String get emptyFavorites => 'Aucun favori pour l’instant.';

  @override
  String get emptyCategory => 'Rien dans cette catégorie pour l’instant.';

  @override
  String get noResults => 'Aucun résultat.';

  @override
  String get kindMovie => 'Film';

  @override
  String get kindSeries => 'Série';

  @override
  String get kindMusic => 'Musique';

  @override
  String get kindPodcast => 'Podcast';

  @override
  String mediaWithKind(String title, String kind) {
    return '$title, $kind';
  }

  @override
  String get unavailable => 'indisponible';

  @override
  String get playerPlay => 'Lecture';

  @override
  String get playerPause => 'Pause';

  @override
  String get playerRewind => 'Reculer de 10 secondes';

  @override
  String get playerForward => 'Avancer de 30 secondes';

  @override
  String get playerLoading => 'Chargement…';

  @override
  String get playerPaused => 'En pause';

  @override
  String get playerEnded => 'Lecture terminée';

  @override
  String get playerPositionLabel => 'Position de lecture';

  @override
  String playerPosition(String position, String duration) {
    return '$position sur $duration';
  }

  @override
  String playerError(String details) {
    return 'Lecture impossible : $details';
  }

  @override
  String get playerTracks => 'Audio et sous-titres';

  @override
  String get playerAudio => 'Audio';

  @override
  String get playerSubtitles => 'Sous-titres';

  @override
  String get playerSubtitlesOff => 'Désactivés';

  @override
  String get playerAudioDescription => 'Audiodescription';

  @override
  String playerTrackNumber(int number) {
    return 'Piste $number';
  }

  @override
  String get playerNoTrack => 'Aucune piste dans ce fichier';

  @override
  String get subtitleSize => 'Taille des sous-titres';

  @override
  String get subtitleSizeSmall => 'Petite';

  @override
  String get subtitleSizeNormal => 'Normale';

  @override
  String get subtitleSizeLarge => 'Grande';

  @override
  String get subtitleSizeExtraLarge => 'Très grande';

  @override
  String get subtitleColor => 'Couleur du texte';

  @override
  String get subtitleColorWhite => 'Blanc';

  @override
  String get subtitleColorYellow => 'Jaune';

  @override
  String get subtitleColorCyan => 'Cyan';

  @override
  String get subtitleBackground => 'Fond';

  @override
  String get subtitleBackgroundNone => 'Aucun';

  @override
  String get subtitleBackgroundTranslucent => 'Semi-transparent';

  @override
  String get subtitleBackgroundOpaque => 'Noir';

  @override
  String get subtitlePreview => 'Aperçu des sous-titres';
}
