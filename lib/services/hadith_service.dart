import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

class HadithColecao {
  final String id;
  final String nome;
  final Map<int, String> secoes;

  const HadithColecao({
    required this.id,
    required this.nome,
    required this.secoes,
  });
}

class Hadith {
  final int numero;
  final String texto;

  Hadith({required this.numero, required this.texto});
}

/// Um hadith muito conhecido, com texto árabe e tradução portuguesa
/// embutidos (traduzidos a partir do árabe original — não é uma
/// tradução derivada de nenhuma edição inglesa protegida). O texto
/// inglês não é guardado aqui: é sempre pedido em direto à mesma API
/// já usada para o Bukhari/Muslim completos (ver [HadithService.obterSecao]).
class HadithConhecido {
  final String colecaoId;
  final int secaoId;
  final int numero;
  final String tema;
  final String arabe;
  final String traducaoPt;

  HadithConhecido({
    required this.colecaoId,
    required this.secaoId,
    required this.numero,
    required this.tema,
    required this.arabe,
    required this.traducaoPt,
  });
}

/// Fonte: fawazahmed0/hadith-api (CDN gratuito, sem chave). Só em
/// inglês — a HadeethEnc.com tem português, mas está organizada como
/// enciclopédia académica de jurisprudência (categorias temáticas
/// profundas), não como colecção livro/capítulo simples, o que ficou
/// confuso de navegar; por isso voltámos a esta fonte.
class HadithService {
  // Índice de secções (tabela de conteúdos) extraído de
  // https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/info.json
  // — só os títulos dos capítulos; o texto de cada hadith é sempre
  // pedido à API (nunca embutido aqui).
  static final List<HadithColecao> colecoes = [
    HadithColecao(
      id: "bukhari",
      nome: "Sahih al Bukhari",
      secoes: {
        1: "Revelation",
        2: "Belief",
        3: "Knowledge",
        4: "Ablutions (Wudu')",
        5: "Bathing (Ghusl)",
        6: "Menstrual Periods",
        7: "Rubbing hands and feet with dust (Tayammum)",
        8: "Prayers (Salat)",
        9: "Times of the Prayers",
        10: "Call to Prayers (Adhaan)",
        11: "Friday Prayer",
        12: "Fear Prayer",
        13: "The Two Festivals (Eids)",
        14: "Witr Prayer",
        15: "Invoking Allah for Rain (Istisqaa)",
        16: "Eclipses",
        17: "Prostration During Recital of Qur'an",
        18: "Shortening the Prayers (At-Taqseer)",
        19: "Prayer at Night (Tahajjud)",
        20: "Virtues of Prayer at Masjid Makkah and Madinah",
        21: "Actions while Praying",
        22: "Forgetfulness in Prayer",
        23: "Funerals (Al-Janaa'iz)",
        24: "Obligatory Charity Tax (Zakat)",
        25: "Hajj (Pilgrimage)",
        26: "`Umrah (Minor pilgrimage)",
        27: "Pilgrims Prevented from Completing the Pilgrimage",
        28: "Penalty of Hunting while on Pilgrimage",
        29: "Virtues of Madinah",
        30: "Fasting",
        31: "Praying at Night in Ramadaan (Taraweeh)",
        32: "Virtues of the Night of Qadr",
        33: "Retiring to a Mosque for Remembrance of Allah (I'tikaf)",
        34: "Sales and Trade",
        35: "Sales in which a Price is paid for Goods to be Delivered Later (As-Salam)",
        36: "Shuf'a",
        37: "Hiring",
        38: "Transferance of a Debt from One Person to Another (Al-Hawaala)",
        39: "Kafalah",
        40: "Representation, Authorization, Business by Proxy",
        41: "Agriculture",
        42: "Distribution of Water",
        43: "Loans, Payment of Loans, Freezing of Property, Bankruptcy",
        44: "Khusoomaat",
        45: "Lost Things Picked up by Someone (Luqatah)",
        46: "Oppressions",
        47: "Partnership",
        48: "Mortgaging",
        49: "Manumission of Slaves",
        50: "Makaatib",
        51: "Gifts",
        52: "Witnesses",
        53: "Peacemaking",
        54: "Conditions",
        55: "Wills and Testaments (Wasaayaa)",
        56: "Fighting for the Cause of Allah (Jihaad)",
        57: "One-fifth of Booty to the Cause of Allah (Khumus)",
        58: "Jizyah and Mawaada'ah",
        59: "Beginning of Creation",
        60: "Prophets",
        61: "Virtues and Merits of the Prophet (pbuh) and his Companions",
        62: "Companions of the Prophet",
        63: "Merits of the Helpers in Madinah (Ansaar)",
        64: "Military Expeditions led by the Prophet (pbuh) (Al-Maghaazi)",
        65: "Prophetic Commentary on the Qur'an (Tafseer of the Prophet (pbuh))",
        66: "Virtues of the Qur'an",
        67: "Wedlock, Marriage (Nikaah)",
        68: "Divorce",
        69: "Supporting the Family",
        70: "Food, Meals",
        71: "Sacrifice on Occasion of Birth (`Aqiqa)",
        72: "Hunting, Slaughtering",
        73: "Al-Adha Festival Sacrifice (Adaahi)",
        74: "Drinks",
        75: "Patients",
        76: "Medicine",
        77: "Dress",
        78: "Good Manners and Form (Al-Adab)",
        79: "Asking Permission",
        80: "Invocations",
        81: "To make the Heart Tender (Ar-Riqaq)",
        82: "Divine Will (Al-Qadar)",
        83: "Oaths and Vows",
        84: "Expiation for Unfulfilled Oaths",
        85: "Laws of Inheritance (Al-Faraa'id)",
        86: "Limits and Punishments set by Allah (Hudood)",
        87: "Blood Money (Ad-Diyat)",
        88: "Apostates",
        89: "(Statements made under) Coercion",
        90: "Tricks",
        91: "Interpretation of Dreams",
        92: "Afflictions and the End of the World",
        93: "Judgments (Ahkaam)",
        94: "Wishes",
        95: "Accepting Information Given by a Truthful Person",
        96: "Holding Fast to the Qur'an and Sunnah",
        97: "Oneness, Uniqueness of Allah (Tawheed)",
      },
    ),
    HadithColecao(
      id: "muslim",
      nome: "Sahih Muslim",
      secoes: {
        0: "Introduction",
        1: "The Book of Faith",
        2: "The Book of Purification",
        3: "The Book of Menstruation",
        4: "The Book of Prayers ",
        5: "The Book of Mosques and Places of Prayer",
        6: "The Book of Prayer - Travellers",
        7: "The Book of Prayer - Friday",
        8: "The Book of Prayer - Two Eids",
        9: "The Book of Prayer - Rain",
        10: "The Book of Prayer - Eclipses",
        11: "The Book of Prayer - Funerals",
        12: "The Book of Zakat",
        13: "The Book of Fasting ",
        14: "The Book of I'tikaf",
        15: "The Book of Pilgrimage",
        16: "The Book of Marriage",
        17: "The Book of Suckling",
        18: "The Book of Divorce ",
        19: "The Book of Invoking Curses",
        20: "The Book of Emancipating Slaves",
        21: "The Book of Transactions",
        22: "The Book of Musaqah",
        23: "The Book of the Rules of Inheritance",
        24: "The Book of Gifts",
        25: "The Book of Wills",
        26: "The Book of Vows",
        27: "The Book of Oaths",
        28: "The Book of Oaths, Muharibin, Qasas (Retaliation), and Diyat (Blood Money)",
        29: "The Book of Legal Punishments",
        30: "The Book of Judicial Decisions",
        31: "The Book of Lost Property",
        32: "The Book of Jihad and Expeditions",
        33: "The Book on Government",
        34: "The Book of Hunting, Slaughter, and what may be Eaten",
        35: "The Book of Sacrifices",
        36: "The Book of Drinks",
        37: "The Book of Clothes and Adornment",
        38: "The Book of Manners and Etiquette",
        39: "The Book of Greetings",
        40: "The Book Concerning the Use of Correct Words",
        41: "The Book of Poetry",
        42: "The Book of Dreams",
        43: "The Book of Virtues",
        44: "The Book of the Merits of the Companions",
        45: "The Book of Virtue, Enjoining Good Manners, and Joining of the Ties of Kinship",
        46: "The Book of Destiny",
        47: "The Book of Knowledge",
        48: "The Book Pertaining to the Remembrance of Allah, Supplication, Repentance and Seeking Forgiveness ",
        49: "The Book of Heart-Melting Traditions",
        50: "The Book of Repentance",
        51: "Characteristics of The Hypocrites And Rulings Concerning Them",
        52: "Characteristics of the Day of Judgment, Paradise, and Hell",
        53: "The Book of Paradise, its Description, its Bounties and its Inhabitants",
        54: "The Book of Tribulations and Portents of the Last Hour",
        55: "The Book of Zuhd and Softening of Hearts ",
        56: "The Book of Commentary on the Qur'an",
      },
    ),
  ];

  static final Map<String, List<Hadith>> _cache = {};

  static Future<List<Hadith>> obterSecao(String colecaoId, int secaoId) async {
    final chave = "$colecaoId-$secaoId";
    if (_cache.containsKey(chave)) return _cache[chave]!;

    final url = Uri.parse(
        "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/eng-$colecaoId/sections/$secaoId.json");

    final resposta = await http.get(url);
    if (resposta.statusCode != 200) {
      throw Exception("Não foi possível carregar os hadiths");
    }

    final json = jsonDecode(resposta.body);
    final hadiths = (json['hadiths'] as List)
        .map((h) => Hadith(
              numero: h['hadithnumber'] as int,
              texto: h['text'] as String,
            ))
        .toList();

    _cache[chave] = hadiths;
    return hadiths;
  }

  static List<HadithConhecido>? _conhecidosCache;

  static Future<List<HadithConhecido>> listarConhecidos() async {
    if (_conhecidosCache != null) return _conhecidosCache!;

    final raw =
        await rootBundle.loadString('assets/quran/hadiths_conhecidos_pt.json');
    final json = jsonDecode(raw);

    _conhecidosCache = (json['itens'] as List)
        .map((i) => HadithConhecido(
              colecaoId: i['colecao'] as String,
              secaoId: i['secao'] as int,
              numero: i['numero'] as int,
              tema: i['tema'] as String,
              arabe: i['arabe'] as String,
              traducaoPt: i['traducaoPt'] as String,
            ))
        .toList();

    return _conhecidosCache!;
  }

  /// Texto inglês correspondente a um [HadithConhecido] — pedido em
  /// direto à mesma API/cache usada pelas colecções completas.
  static Future<String> obterTextoIngles(HadithConhecido h) async {
    final secao = await obterSecao(h.colecaoId, h.secaoId);
    final encontrado = secao.where((x) => x.numero == h.numero);
    return encontrado.isNotEmpty ? encontrado.first.texto : "";
  }
}
