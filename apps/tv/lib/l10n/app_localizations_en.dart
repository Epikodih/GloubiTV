// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get connectingToServer => 'Connecting to server';

  @override
  String get retry => 'Retry';

  @override
  String get retryConnectionLabel => 'Try connecting to the server again';

  @override
  String unexpectedError(String details) {
    return 'Unexpected error: $details';
  }

  @override
  String get createAccount => 'Create an account';

  @override
  String get createAccountButton => 'Create account';

  @override
  String get creating => 'Creating...';

  @override
  String get back => 'Back';

  @override
  String get name => 'Name';

  @override
  String get nameHint => 'First name or nickname';

  @override
  String get enterName => 'Enter a name.';

  @override
  String get choosePhoto => 'Choose my photo';

  @override
  String get imagePickError => 'Unable to pick an image here.';

  @override
  String avatarIcon(int number) {
    return 'Icon $number';
  }

  @override
  String avatarIconSelected(int number) {
    return 'Icon $number, selected';
  }

  @override
  String get age => 'Age';

  @override
  String ageYears(int age) {
    return '$age years old';
  }

  @override
  String get decreaseAge => 'Decrease age';

  @override
  String get increaseAge => 'Increase age';

  @override
  String get language => 'Language';

  @override
  String get childProfile => 'Child profile';

  @override
  String get childProfileSemantic => 'Child profile (parental control)';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get noContentBlocked => 'No content blocked';

  @override
  String get noContentBlockedAdult => 'No content blocked (18 and over)';

  @override
  String blocksRatingAndAbove(int rating) {
    return 'Blocks $rating+ and above';
  }

  @override
  String get pairingTitle => 'Connect the remote';

  @override
  String get pairingInstruction =>
      'Scan the QR code or enter the code in the app.';

  @override
  String get newCode => 'New code';

  @override
  String newCodeCooldown(int seconds) {
    return 'New code ($seconds s)';
  }

  @override
  String get newCodeSemantics => 'Generate a new code and a new QR code';

  @override
  String get newCodeCoolingSemantics => 'New code, available in a few seconds';

  @override
  String expiresIn(String time) {
    return 'Expires in $time';
  }

  @override
  String expiresSemantics(int minutes) {
    return 'The code expires in $minutes minutes';
  }

  @override
  String pairingCodeSemantics(String code) {
    return 'Pairing code: $code';
  }

  @override
  String get pairingQrSemantics => 'Pairing QR code';

  @override
  String get switchLanguageLabel => 'Switch language';

  @override
  String get noAccountYet => 'No account yet';

  @override
  String get whoIsWatching => 'Who\'s watching?';

  @override
  String get createOrGuest => 'Create an account or watch as a guest';

  @override
  String get createCard => 'Create';

  @override
  String get guestCard => 'Guest';

  @override
  String get continueAsGuest => 'Continue as guest';

  @override
  String accountSemantics(String name) {
    return 'Account $name';
  }

  @override
  String accountLockedSemantics(String name) {
    return 'Account $name, protected by a PIN code';
  }

  @override
  String get pairingButton => 'Pairing';

  @override
  String get backToPairingLabel => 'Back to the pairing screen';

  @override
  String get profile => 'Profile';

  @override
  String profileMenuSemantics(String name) {
    return '$name profile menu';
  }

  @override
  String get closeMenu => 'Close menu';

  @override
  String get switchProfile => 'Switch profile';

  @override
  String get pinTitle => 'PIN required';

  @override
  String get pinSubtitle => 'Enter the PIN to change the age restriction.';

  @override
  String get newPinTitle => 'Choose a PIN';

  @override
  String get newPinSubtitle => 'It protects this account\'s parental controls.';

  @override
  String get confirmPinTitle => 'Confirm the PIN';

  @override
  String get confirmPinSubtitle => 'Type the same PIN again.';

  @override
  String get pinMismatch => 'The two PINs do not match.';

  @override
  String get editAccounts => 'Edit';

  @override
  String get editDone => 'Done';

  @override
  String get manageAccounts => 'Manage accounts';

  @override
  String get chooseAccountToDelete => 'Choose the account to delete.';

  @override
  String get deleteAccount => 'Delete';

  @override
  String deleteAccountSemantics(String name) {
    return 'Delete $name\'s account';
  }

  @override
  String deleteAccountTitle(String name) {
    return 'Delete $name\'s account?';
  }

  @override
  String get deleteAccountBody =>
      'Their favorites, watchlist and resume points will be lost. Files are not touched.';

  @override
  String get pinWrong => 'Incorrect PIN.';

  @override
  String pinDigitSemantics(String digit) {
    return 'Digit $digit';
  }

  @override
  String get deleteDigit => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get saving => 'Saving...';

  @override
  String get pinWillBeAsked => 'The PIN will be requested when saving.';

  @override
  String get sectionMovies => 'Movies';

  @override
  String get sectionSeries => 'TV shows';

  @override
  String get sectionMusic => 'Music';

  @override
  String get sectionPodcasts => 'Podcasts';

  @override
  String get libraryLoadError => 'Unable to load the library.';

  @override
  String get noMediaForProfile => 'No media available for this profile.';

  @override
  String get guestName => 'Guest';

  @override
  String get navSearch => 'Search';

  @override
  String get navHome => 'Home';

  @override
  String get navWatchlist => 'Watchlist';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get libraryNavigation => 'Library menu';

  @override
  String get searchHint => 'Search the whole media center';

  @override
  String get settings => 'Settings';

  @override
  String get sourcesTitle => 'Media center folders';

  @override
  String get sourcesHint =>
      'The folders the media center scans to fill the library. Type a path (phone keyboard) or browse the folders.';

  @override
  String get sourcePathLabel => 'Folder path';

  @override
  String get sourcePathHint => 'D:\\Movies or smb://nas/movies';

  @override
  String get browse => 'Browse…';

  @override
  String get addSource => 'Add';

  @override
  String get removeSource => 'Remove';

  @override
  String get scanAll => 'Scan all';

  @override
  String scanAllStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Scanning $count folders.',
      one: 'Scanning 1 folder.',
      zero: 'No folder to scan.',
    );
    return '$_temp0';
  }

  @override
  String get rescan => 'Rescan';

  @override
  String get noSources => 'No folders yet: add one to fill the library.';

  @override
  String get enterFolder => 'Enter a folder first.';

  @override
  String get folderPickError => 'Unable to open the folder picker.';

  @override
  String get sourcesLoadError => 'Unable to load the folders.';

  @override
  String get sourceOnline => 'Online';

  @override
  String get sourceOffline => 'Offline';

  @override
  String get sourceError => 'Error';

  @override
  String get sourceUnknown => 'Not checked yet';

  @override
  String get neverScanned => 'Never scanned';

  @override
  String lastScan(String date) {
    return 'Last scan: $date';
  }

  @override
  String sourceMediaCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count media',
      one: '1 media',
      zero: 'No media',
    );
    return '$_temp0';
  }

  @override
  String sourceAdded(String name) {
    return '“$name” added: scanning starts.';
  }

  @override
  String sourceRemoved(String name) {
    return '“$name” removed.';
  }

  @override
  String scanStarted(String name) {
    return 'Scan of “$name” started.';
  }

  @override
  String removeSourceConfirm(String name) {
    return 'Remove “$name”? Its media will leave the library (files are not deleted).';
  }

  @override
  String get close => 'Close';

  @override
  String get play => 'Play';

  @override
  String get playSoon => 'Playback is coming soon.';

  @override
  String get playRequestError => 'Could not start playback.';

  @override
  String get addFavorite => 'Add to favorites';

  @override
  String get inFavorites => 'In favorites';

  @override
  String get addWatchlist => 'Watch later';

  @override
  String get inWatchlist => 'In watchlist';

  @override
  String get listUpdateError => 'Unable to update the list.';

  @override
  String get mediaDetailsLoadError => 'Unable to load the media details.';

  @override
  String get noOverview => 'No summary for this media yet.';

  @override
  String get fileMissing => 'File not found: cannot play.';

  @override
  String get notRated => 'Not rated';

  @override
  String get allAges => 'All ages';

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
  String get filters => 'Filters';

  @override
  String filtersActive(int count) {
    return 'Filters, $count active';
  }

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get filterType => 'Type';

  @override
  String get filterGenre => 'Genre';

  @override
  String get filterAge => 'Age';

  @override
  String get filterAll => 'All';

  @override
  String ageMax(int age) {
    return 'Up to $age';
  }

  @override
  String get emptyWatchlist => 'Your watchlist is empty.';

  @override
  String get emptyFavorites => 'No favorites yet.';

  @override
  String get emptyCategory => 'Nothing in this category yet.';

  @override
  String get noResults => 'No results.';

  @override
  String get kindMovie => 'Movie';

  @override
  String get kindSeries => 'TV show';

  @override
  String get kindMusic => 'Music';

  @override
  String get kindPodcast => 'Podcast';

  @override
  String mediaWithKind(String title, String kind) {
    return '$title, $kind';
  }

  @override
  String get unavailable => 'unavailable';

  @override
  String get playerPlay => 'Play';

  @override
  String get playerPause => 'Pause';

  @override
  String get playerRewind => 'Rewind 10 seconds';

  @override
  String get playerForward => 'Forward 30 seconds';

  @override
  String get playerLoading => 'Loading…';

  @override
  String get playerPaused => 'Paused';

  @override
  String get playerEnded => 'Playback finished';

  @override
  String get playerPositionLabel => 'Playback position';

  @override
  String playerPosition(String position, String duration) {
    return '$position of $duration';
  }

  @override
  String playerError(String details) {
    return 'Unable to play: $details';
  }

  @override
  String get playerTracks => 'Audio and subtitles';

  @override
  String get playerAudio => 'Audio';

  @override
  String get playerSubtitles => 'Subtitles';

  @override
  String get playerSubtitlesOff => 'Off';

  @override
  String get playerAudioDescription => 'Audio description';

  @override
  String playerTrackNumber(int number) {
    return 'Track $number';
  }

  @override
  String get playerNoTrack => 'No track in this file';

  @override
  String get subtitleSize => 'Subtitle size';

  @override
  String get subtitleSizeSmall => 'Small';

  @override
  String get subtitleSizeNormal => 'Normal';

  @override
  String get subtitleSizeLarge => 'Large';

  @override
  String get subtitleSizeExtraLarge => 'Extra large';

  @override
  String get subtitleColor => 'Text colour';

  @override
  String get subtitleColorWhite => 'White';

  @override
  String get subtitleColorYellow => 'Yellow';

  @override
  String get subtitleColorCyan => 'Cyan';

  @override
  String get subtitleBackground => 'Background';

  @override
  String get subtitleBackgroundNone => 'None';

  @override
  String get subtitleBackgroundTranslucent => 'Semi-transparent';

  @override
  String get subtitleBackgroundOpaque => 'Black';

  @override
  String get subtitlePreview => 'Subtitle preview';
}
