import 'local_storage_service.dart';

class SurahInfo {
  final int numero;
  final String nomeArabe;
  final String nomeIngles;
  final String traducaoIngles;
  final int numeroAyahs;

  const SurahInfo({
    required this.numero,
    required this.nomeArabe,
    required this.nomeIngles,
    required this.traducaoIngles,
    required this.numeroAyahs,
  });
}

class QuranMarcador {
  final String nome;
  final int surah;
  final int ayah;
  final String surahNome;
  final DateTime criadoEm;

  QuranMarcador({
    required this.nome,
    required this.surah,
    required this.ayah,
    required this.surahNome,
    required this.criadoEm,
  });

  Map<String, dynamic> toJson() => {
        "nome": nome,
        "surah": surah,
        "ayah": ayah,
        "surahNome": surahNome,
        "criadoEm": criadoEm.toIso8601String(),
      };

  factory QuranMarcador.fromJson(Map<String, dynamic> json) => QuranMarcador(
        nome: json["nome"] as String? ?? "Marcador",
        surah: json["surah"] as int,
        ayah: json["ayah"] as int,
        surahNome: json["surahNome"] as String,
        criadoEm: DateTime.parse(json["criadoEm"] as String),
      );
}

/// Metadados das 114 suras (números/nomes/nº de versículos) — dado
/// bibliográfico embutido no app, sem precisar de rede. O texto do
/// Alcorão em si (Mushaf Indopak 13 linhas) vem de
/// [IndopakMushafService], já embutido como asset da app.
class QuranService {
  static List<SurahInfo> listarSurahs() => _lista;

  static SurahInfo? porNumero(int numero) {
    for (final s in _lista) {
      if (s.numero == numero) return s;
    }
    return null;
  }

  // ---------------- Marcadores (múltiplos, únicos por versículo) ----------------

  static Future<List<QuranMarcador>> listarMarcadores() async {
    final lista = await LocalStorageService.carregarMarcadoresQuran();
    return lista.map(QuranMarcador.fromJson).toList()
      ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
  }

  /// Grava um marcador nomeado. Se já existir um marcador neste
  /// versículo exato, substitui-o (nome + data) em vez de duplicar.
  static Future<void> salvarMarcador(QuranMarcador marcador) async {
    final lista = await LocalStorageService.carregarMarcadoresQuran();
    lista.removeWhere(
      (m) => m["surah"] == marcador.surah && m["ayah"] == marcador.ayah,
    );
    lista.add(marcador.toJson());
    await LocalStorageService.salvarMarcadoresQuran(lista);
  }

  static Future<void> removerMarcador(DateTime criadoEm) async {
    final lista = await LocalStorageService.carregarMarcadoresQuran();
    lista.removeWhere((m) => m["criadoEm"] == criadoEm.toIso8601String());
    await LocalStorageService.salvarMarcadoresQuran(lista);
  }

  // ---------------- Continuar leitura (automático) ----------------

  static Future<void> registarUltimaLeitura(int surah, int ayah) {
    return LocalStorageService.salvarUltimaLeituraQuran(surah, ayah);
  }

  static Future<Map<String, dynamic>?> obterUltimaLeitura() {
    return LocalStorageService.carregarUltimaLeituraQuran();
  }

  // ---------------- Suras principais (mais lidas) ----------------

  static const List<int> suasPrincipais = [
    1, // Al-Faatiha
    36, // Ya-Sin
    18, // Al-Kahf
    32, // As-Sajda
    55, // Ar-Rahmaan
    56, // Al-Waaqia
    67, // Al-Mulk
    112, // Al-Ikhlaas
    113, // Al-Falaq
    114, // An-Naas
  ];

  static const List<SurahInfo> _lista = [
    SurahInfo(numero: 1, nomeArabe: "سُورَةُ ٱلْفَاتِحَةِ", nomeIngles: "Al-Faatiha", traducaoIngles: "The Opening", numeroAyahs: 7),
    SurahInfo(numero: 2, nomeArabe: "سُورَةُ البَقَرَةِ", nomeIngles: "Al-Baqara", traducaoIngles: "The Cow", numeroAyahs: 286),
    SurahInfo(numero: 3, nomeArabe: "سُورَةُ آلِ عِمۡرَانَ", nomeIngles: "Aal-i-Imraan", traducaoIngles: "The Family of Imraan", numeroAyahs: 200),
    SurahInfo(numero: 4, nomeArabe: "سُورَةُ النِّسَاءِ", nomeIngles: "An-Nisaa", traducaoIngles: "The Women", numeroAyahs: 176),
    SurahInfo(numero: 5, nomeArabe: "سُورَةُ المَائـِدَةِ", nomeIngles: "Al-Maaida", traducaoIngles: "The Table", numeroAyahs: 120),
    SurahInfo(numero: 6, nomeArabe: "سُورَةُ الأَنۡعَامِ", nomeIngles: "Al-An'aam", traducaoIngles: "The Cattle", numeroAyahs: 165),
    SurahInfo(numero: 7, nomeArabe: "سُورَةُ الأَعۡرَافِ", nomeIngles: "Al-A'raaf", traducaoIngles: "The Heights", numeroAyahs: 206),
    SurahInfo(numero: 8, nomeArabe: "سُورَةُ الأَنفَالِ", nomeIngles: "Al-Anfaal", traducaoIngles: "The Spoils of War", numeroAyahs: 75),
    SurahInfo(numero: 9, nomeArabe: "سُورَةُ التَّوۡبَةِ", nomeIngles: "At-Tawba", traducaoIngles: "The Repentance", numeroAyahs: 129),
    SurahInfo(numero: 10, nomeArabe: "سُورَةُ يُونُسَ", nomeIngles: "Yunus", traducaoIngles: "Jonas", numeroAyahs: 109),
    SurahInfo(numero: 11, nomeArabe: "سُورَةُ هُودٍ", nomeIngles: "Hud", traducaoIngles: "Hud", numeroAyahs: 123),
    SurahInfo(numero: 12, nomeArabe: "سُورَةُ يُوسُفَ", nomeIngles: "Yusuf", traducaoIngles: "Joseph", numeroAyahs: 111),
    SurahInfo(numero: 13, nomeArabe: "سُورَةُ الرَّعۡدِ", nomeIngles: "Ar-Ra'd", traducaoIngles: "The Thunder", numeroAyahs: 43),
    SurahInfo(numero: 14, nomeArabe: "سُورَةُ إِبۡرَاهِيمَ", nomeIngles: "Ibrahim", traducaoIngles: "Abraham", numeroAyahs: 52),
    SurahInfo(numero: 15, nomeArabe: "سُورَةُ الحِجۡرِ", nomeIngles: "Al-Hijr", traducaoIngles: "The Rock", numeroAyahs: 99),
    SurahInfo(numero: 16, nomeArabe: "سُورَةُ النَّحۡلِ", nomeIngles: "An-Nahl", traducaoIngles: "The Bee", numeroAyahs: 128),
    SurahInfo(numero: 17, nomeArabe: "سُورَةُ الإِسۡرَاءِ", nomeIngles: "Al-Israa", traducaoIngles: "The Night Journey", numeroAyahs: 111),
    SurahInfo(numero: 18, nomeArabe: "سُورَةُ الكَهۡفِ", nomeIngles: "Al-Kahf", traducaoIngles: "The Cave", numeroAyahs: 110),
    SurahInfo(numero: 19, nomeArabe: "سُورَةُ مَرۡيَمَ", nomeIngles: "Maryam", traducaoIngles: "Mary", numeroAyahs: 98),
    SurahInfo(numero: 20, nomeArabe: "سُورَةُ طه", nomeIngles: "Taa-Haa", traducaoIngles: "Taa-Haa", numeroAyahs: 135),
    SurahInfo(numero: 21, nomeArabe: "سُورَةُ الأَنبِيَاءِ", nomeIngles: "Al-Anbiyaa", traducaoIngles: "The Prophets", numeroAyahs: 112),
    SurahInfo(numero: 22, nomeArabe: "سُورَةُ الحَجِّ", nomeIngles: "Al-Hajj", traducaoIngles: "The Pilgrimage", numeroAyahs: 78),
    SurahInfo(numero: 23, nomeArabe: "سُورَةُ المُؤۡمِنُونَ", nomeIngles: "Al-Muminoon", traducaoIngles: "The Believers", numeroAyahs: 118),
    SurahInfo(numero: 24, nomeArabe: "سُورَةُ النُّورِ", nomeIngles: "An-Noor", traducaoIngles: "The Light", numeroAyahs: 64),
    SurahInfo(numero: 25, nomeArabe: "سُورَةُ الفُرۡقَانِ", nomeIngles: "Al-Furqaan", traducaoIngles: "The Criterion", numeroAyahs: 77),
    SurahInfo(numero: 26, nomeArabe: "سُورَةُ الشُّعَرَاءِ", nomeIngles: "Ash-Shu'araa", traducaoIngles: "The Poets", numeroAyahs: 227),
    SurahInfo(numero: 27, nomeArabe: "سُورَةُ النَّمۡلِ", nomeIngles: "An-Naml", traducaoIngles: "The Ant", numeroAyahs: 93),
    SurahInfo(numero: 28, nomeArabe: "سُورَةُ القَصَصِ", nomeIngles: "Al-Qasas", traducaoIngles: "The Stories", numeroAyahs: 88),
    SurahInfo(numero: 29, nomeArabe: "سُورَةُ العَنكَبُوتِ", nomeIngles: "Al-Ankaboot", traducaoIngles: "The Spider", numeroAyahs: 69),
    SurahInfo(numero: 30, nomeArabe: "سُورَةُ الرُّومِ", nomeIngles: "Ar-Room", traducaoIngles: "The Romans", numeroAyahs: 60),
    SurahInfo(numero: 31, nomeArabe: "سُورَةُ لُقۡمَانَ", nomeIngles: "Luqman", traducaoIngles: "Luqman", numeroAyahs: 34),
    SurahInfo(numero: 32, nomeArabe: "سُورَةُ السَّجۡدَةِ", nomeIngles: "As-Sajda", traducaoIngles: "The Prostration", numeroAyahs: 30),
    SurahInfo(numero: 33, nomeArabe: "سُورَةُ الأَحۡزَابِ", nomeIngles: "Al-Ahzaab", traducaoIngles: "The Clans", numeroAyahs: 73),
    SurahInfo(numero: 34, nomeArabe: "سُورَةُ سَبَإٍ", nomeIngles: "Saba", traducaoIngles: "Sheba", numeroAyahs: 54),
    SurahInfo(numero: 35, nomeArabe: "سُورَةُ فَاطِرٍ", nomeIngles: "Faatir", traducaoIngles: "The Originator", numeroAyahs: 45),
    SurahInfo(numero: 36, nomeArabe: "سُورَةُ يسٓ", nomeIngles: "Yaseen", traducaoIngles: "Yaseen", numeroAyahs: 83),
    SurahInfo(numero: 37, nomeArabe: "سُورَةُ الصَّافَّاتِ", nomeIngles: "As-Saaffaat", traducaoIngles: "Those drawn up in Ranks", numeroAyahs: 182),
    SurahInfo(numero: 38, nomeArabe: "سُورَةُ صٓ", nomeIngles: "Saad", traducaoIngles: "The letter Saad", numeroAyahs: 88),
    SurahInfo(numero: 39, nomeArabe: "سُورَةُ الزُّمَرِ", nomeIngles: "Az-Zumar", traducaoIngles: "The Groups", numeroAyahs: 75),
    SurahInfo(numero: 40, nomeArabe: "سُورَةُ غَافِرٍ", nomeIngles: "Ghafir", traducaoIngles: "The Forgiver", numeroAyahs: 85),
    SurahInfo(numero: 41, nomeArabe: "سُورَةُ فُصِّلَتۡ", nomeIngles: "Fussilat", traducaoIngles: "Explained in detail", numeroAyahs: 54),
    SurahInfo(numero: 42, nomeArabe: "سُورَةُ الشُّورَىٰ", nomeIngles: "Ash-Shura", traducaoIngles: "Consultation", numeroAyahs: 53),
    SurahInfo(numero: 43, nomeArabe: "سُورَةُ الزُّخۡرُفِ", nomeIngles: "Az-Zukhruf", traducaoIngles: "Ornaments of gold", numeroAyahs: 89),
    SurahInfo(numero: 44, nomeArabe: "سُورَةُ الدُّخَانِ", nomeIngles: "Ad-Dukhaan", traducaoIngles: "The Smoke", numeroAyahs: 59),
    SurahInfo(numero: 45, nomeArabe: "سُورَةُ الجَاثِيَةِ", nomeIngles: "Al-Jaathiya", traducaoIngles: "Crouching", numeroAyahs: 37),
    SurahInfo(numero: 46, nomeArabe: "سُورَةُ الأَحۡقَافِ", nomeIngles: "Al-Ahqaf", traducaoIngles: "The Dunes", numeroAyahs: 35),
    SurahInfo(numero: 47, nomeArabe: "سُورَةُ مُحَمَّدٍ", nomeIngles: "Muhammad", traducaoIngles: "Muhammad", numeroAyahs: 38),
    SurahInfo(numero: 48, nomeArabe: "سُورَةُ الفَتۡحِ", nomeIngles: "Al-Fath", traducaoIngles: "The Victory", numeroAyahs: 29),
    SurahInfo(numero: 49, nomeArabe: "سُورَةُ الحُجُرَاتِ", nomeIngles: "Al-Hujuraat", traducaoIngles: "The Inner Apartments", numeroAyahs: 18),
    SurahInfo(numero: 50, nomeArabe: "سُورَةُ قٓ", nomeIngles: "Qaaf", traducaoIngles: "The letter Qaaf", numeroAyahs: 45),
    SurahInfo(numero: 51, nomeArabe: "سُورَةُ الذَّارِيَاتِ", nomeIngles: "Adh-Dhaariyat", traducaoIngles: "The Winnowing Winds", numeroAyahs: 60),
    SurahInfo(numero: 52, nomeArabe: "سُورَةُ الطُّورِ", nomeIngles: "At-Tur", traducaoIngles: "The Mount", numeroAyahs: 49),
    SurahInfo(numero: 53, nomeArabe: "سُورَةُ النَّجۡمِ", nomeIngles: "An-Najm", traducaoIngles: "The Star", numeroAyahs: 62),
    SurahInfo(numero: 54, nomeArabe: "سُورَةُ القَمَرِ", nomeIngles: "Al-Qamar", traducaoIngles: "The Moon", numeroAyahs: 55),
    SurahInfo(numero: 55, nomeArabe: "سُورَةُ الرَّحۡمَٰن", nomeIngles: "Ar-Rahmaan", traducaoIngles: "The Beneficent", numeroAyahs: 78),
    SurahInfo(numero: 56, nomeArabe: "سُورَةُ الوَاقِعَةِ", nomeIngles: "Al-Waaqia", traducaoIngles: "The Inevitable", numeroAyahs: 96),
    SurahInfo(numero: 57, nomeArabe: "سُورَةُ الحَدِيدِ", nomeIngles: "Al-Hadid", traducaoIngles: "The Iron", numeroAyahs: 29),
    SurahInfo(numero: 58, nomeArabe: "سُورَةُ المُجَادلَةِ", nomeIngles: "Al-Mujaadila", traducaoIngles: "The Pleading Woman", numeroAyahs: 22),
    SurahInfo(numero: 59, nomeArabe: "سُورَةُ الحَشۡرِ", nomeIngles: "Al-Hashr", traducaoIngles: "The Exile", numeroAyahs: 24),
    SurahInfo(numero: 60, nomeArabe: "سُورَةُ المُمۡتَحنَةِ", nomeIngles: "Al-Mumtahana", traducaoIngles: "She that is to be examined", numeroAyahs: 13),
    SurahInfo(numero: 61, nomeArabe: "سُورَةُ الصَّفِّ", nomeIngles: "As-Saff", traducaoIngles: "The Ranks", numeroAyahs: 14),
    SurahInfo(numero: 62, nomeArabe: "سُورَةُ الجُمُعَةِ", nomeIngles: "Al-Jumu'a", traducaoIngles: "Friday", numeroAyahs: 11),
    SurahInfo(numero: 63, nomeArabe: "سُورَةُ المُنَافِقُونَ", nomeIngles: "Al-Munaafiqoon", traducaoIngles: "The Hypocrites", numeroAyahs: 11),
    SurahInfo(numero: 64, nomeArabe: "سُورَةُ التَّغَابُنِ", nomeIngles: "At-Taghaabun", traducaoIngles: "Mutual Disillusion", numeroAyahs: 18),
    SurahInfo(numero: 65, nomeArabe: "سُورَةُ الطَّلَاقِ", nomeIngles: "At-Talaaq", traducaoIngles: "Divorce", numeroAyahs: 12),
    SurahInfo(numero: 66, nomeArabe: "سُورَةُ التَّحۡرِيمِ", nomeIngles: "At-Tahrim", traducaoIngles: "The Prohibition", numeroAyahs: 12),
    SurahInfo(numero: 67, nomeArabe: "سُورَةُ المُلۡكِ", nomeIngles: "Al-Mulk", traducaoIngles: "The Sovereignty", numeroAyahs: 30),
    SurahInfo(numero: 68, nomeArabe: "سُورَةُ القَلَمِ", nomeIngles: "Al-Qalam", traducaoIngles: "The Pen", numeroAyahs: 52),
    SurahInfo(numero: 69, nomeArabe: "سُورَةُ الحَاقَّةِ", nomeIngles: "Al-Haaqqa", traducaoIngles: "The Reality", numeroAyahs: 52),
    SurahInfo(numero: 70, nomeArabe: "سُورَةُ المَعَارِجِ", nomeIngles: "Al-Ma'aarij", traducaoIngles: "The Ascending Stairways", numeroAyahs: 44),
    SurahInfo(numero: 71, nomeArabe: "سُورَةُ نُوحٍ", nomeIngles: "Nooh", traducaoIngles: "Noah", numeroAyahs: 28),
    SurahInfo(numero: 72, nomeArabe: "سُورَةُ الجِنِّ", nomeIngles: "Al-Jinn", traducaoIngles: "The Jinn", numeroAyahs: 28),
    SurahInfo(numero: 73, nomeArabe: "سُورَةُ المُزَّمِّلِ", nomeIngles: "Al-Muzzammil", traducaoIngles: "The Enshrouded One", numeroAyahs: 20),
    SurahInfo(numero: 74, nomeArabe: "سُورَةُ المُدَّثِّرِ", nomeIngles: "Al-Muddaththir", traducaoIngles: "The Cloaked One", numeroAyahs: 56),
    SurahInfo(numero: 75, nomeArabe: "سُورَةُ القِيَامَةِ", nomeIngles: "Al-Qiyaama", traducaoIngles: "The Resurrection", numeroAyahs: 40),
    SurahInfo(numero: 76, nomeArabe: "سُورَةُ الإِنسَانِ", nomeIngles: "Al-Insaan", traducaoIngles: "Man", numeroAyahs: 31),
    SurahInfo(numero: 77, nomeArabe: "سُورَةُ المُرۡسَلَاتِ", nomeIngles: "Al-Mursalaat", traducaoIngles: "Those sent forth", numeroAyahs: 50),
    SurahInfo(numero: 78, nomeArabe: "سُورَةُ النَّبَإِ", nomeIngles: "An-Naba", traducaoIngles: "The Announcement", numeroAyahs: 40),
    SurahInfo(numero: 79, nomeArabe: "سُورَةُ النَّازِعَاتِ", nomeIngles: "An-Naazi'aat", traducaoIngles: "Those who drag forth", numeroAyahs: 46),
    SurahInfo(numero: 80, nomeArabe: "سُورَةُ عَبَسَ", nomeIngles: "Abasa", traducaoIngles: "He frowned", numeroAyahs: 42),
    SurahInfo(numero: 81, nomeArabe: "سُورَةُ التَّكۡوِيرِ", nomeIngles: "At-Takwir", traducaoIngles: "The Overthrowing", numeroAyahs: 29),
    SurahInfo(numero: 82, nomeArabe: "سُورَةُ الانفِطَارِ", nomeIngles: "Al-Infitaar", traducaoIngles: "The Cleaving", numeroAyahs: 19),
    SurahInfo(numero: 83, nomeArabe: "سُورَةُ المُطَفِّفِينَ", nomeIngles: "Al-Mutaffifin", traducaoIngles: "Defrauding", numeroAyahs: 36),
    SurahInfo(numero: 84, nomeArabe: "سُورَةُ الانشِقَاقِ", nomeIngles: "Al-Inshiqaaq", traducaoIngles: "The Splitting Open", numeroAyahs: 25),
    SurahInfo(numero: 85, nomeArabe: "سُورَةُ البُرُوجِ", nomeIngles: "Al-Burooj", traducaoIngles: "The Constellations", numeroAyahs: 22),
    SurahInfo(numero: 86, nomeArabe: "سُورَةُ الطَّارِقِ", nomeIngles: "At-Taariq", traducaoIngles: "The Morning Star", numeroAyahs: 17),
    SurahInfo(numero: 87, nomeArabe: "سُورَةُ الأَعۡلَىٰ", nomeIngles: "Al-A'laa", traducaoIngles: "The Most High", numeroAyahs: 19),
    SurahInfo(numero: 88, nomeArabe: "سُورَةُ الغَاشِيَةِ", nomeIngles: "Al-Ghaashiya", traducaoIngles: "The Overwhelming", numeroAyahs: 26),
    SurahInfo(numero: 89, nomeArabe: "سُورَةُ الفَجۡرِ", nomeIngles: "Al-Fajr", traducaoIngles: "The Dawn", numeroAyahs: 30),
    SurahInfo(numero: 90, nomeArabe: "سُورَةُ البَلَدِ", nomeIngles: "Al-Balad", traducaoIngles: "The City", numeroAyahs: 20),
    SurahInfo(numero: 91, nomeArabe: "سُورَةُ الشَّمۡسِ", nomeIngles: "Ash-Shams", traducaoIngles: "The Sun", numeroAyahs: 15),
    SurahInfo(numero: 92, nomeArabe: "سُورَةُ اللَّيۡلِ", nomeIngles: "Al-Lail", traducaoIngles: "The Night", numeroAyahs: 21),
    SurahInfo(numero: 93, nomeArabe: "سُورَةُ الضُّحَىٰ", nomeIngles: "Ad-Dhuhaa", traducaoIngles: "The Morning Hours", numeroAyahs: 11),
    SurahInfo(numero: 94, nomeArabe: "سُورَةُ الشَّرۡحِ", nomeIngles: "Ash-Sharh", traducaoIngles: "The Consolation", numeroAyahs: 8),
    SurahInfo(numero: 95, nomeArabe: "سُورَةُ التِّينِ", nomeIngles: "At-Tin", traducaoIngles: "The Fig", numeroAyahs: 8),
    SurahInfo(numero: 96, nomeArabe: "سُورَةُ العَلَقِ", nomeIngles: "Al-Alaq", traducaoIngles: "The Clot", numeroAyahs: 19),
    SurahInfo(numero: 97, nomeArabe: "سُورَةُ القَدۡرِ", nomeIngles: "Al-Qadr", traducaoIngles: "The Power, Fate", numeroAyahs: 5),
    SurahInfo(numero: 98, nomeArabe: "سُورَةُ البَيِّنَةِ", nomeIngles: "Al-Bayyina", traducaoIngles: "The Evidence", numeroAyahs: 8),
    SurahInfo(numero: 99, nomeArabe: "سُورَةُ الزَّلۡزَلَةِ", nomeIngles: "Az-Zalzala", traducaoIngles: "The Earthquake", numeroAyahs: 8),
    SurahInfo(numero: 100, nomeArabe: "سُورَةُ العَادِيَاتِ", nomeIngles: "Al-Aadiyaat", traducaoIngles: "The Chargers", numeroAyahs: 11),
    SurahInfo(numero: 101, nomeArabe: "سُورَةُ القَارِعَةِ", nomeIngles: "Al-Qaari'a", traducaoIngles: "The Calamity", numeroAyahs: 11),
    SurahInfo(numero: 102, nomeArabe: "سُورَةُ التَّكَاثُرِ", nomeIngles: "At-Takaathur", traducaoIngles: "Competition", numeroAyahs: 8),
    SurahInfo(numero: 103, nomeArabe: "سُورَةُ العَصۡرِ", nomeIngles: "Al-Asr", traducaoIngles: "The Declining Day, Epoch", numeroAyahs: 3),
    SurahInfo(numero: 104, nomeArabe: "سُورَةُ الهُمَزَةِ", nomeIngles: "Al-Humaza", traducaoIngles: "The Traducer", numeroAyahs: 9),
    SurahInfo(numero: 105, nomeArabe: "سُورَةُ الفِيلِ", nomeIngles: "Al-Fil", traducaoIngles: "The Elephant", numeroAyahs: 5),
    SurahInfo(numero: 106, nomeArabe: "سُورَةُ قُرَيۡشٍ", nomeIngles: "Quraish", traducaoIngles: "Quraysh", numeroAyahs: 4),
    SurahInfo(numero: 107, nomeArabe: "سُورَةُ المَاعُونِ", nomeIngles: "Al-Maa'un", traducaoIngles: "Almsgiving", numeroAyahs: 7),
    SurahInfo(numero: 108, nomeArabe: "سُورَةُ الكَوۡثَرِ", nomeIngles: "Al-Kawthar", traducaoIngles: "Abundance", numeroAyahs: 3),
    SurahInfo(numero: 109, nomeArabe: "سُورَةُ الكَافِرُونَ", nomeIngles: "Al-Kaafiroon", traducaoIngles: "The Disbelievers", numeroAyahs: 6),
    SurahInfo(numero: 110, nomeArabe: "سُورَةُ النَّصۡرِ", nomeIngles: "An-Nasr", traducaoIngles: "Divine Support", numeroAyahs: 3),
    SurahInfo(numero: 111, nomeArabe: "سُورَةُ المَسَدِ", nomeIngles: "Al-Masad", traducaoIngles: "The Palm Fibre", numeroAyahs: 5),
    SurahInfo(numero: 112, nomeArabe: "سُورَةُ الإِخۡلَاصِ", nomeIngles: "Al-Ikhlaas", traducaoIngles: "Sincerity", numeroAyahs: 4),
    SurahInfo(numero: 113, nomeArabe: "سُورَةُ الفَلَقِ", nomeIngles: "Al-Falaq", traducaoIngles: "The Dawn", numeroAyahs: 5),
    SurahInfo(numero: 114, nomeArabe: "سُورَةُ النَّاسِ", nomeIngles: "An-Naas", traducaoIngles: "Mankind", numeroAyahs: 6),
  ];
}
