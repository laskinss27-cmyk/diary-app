// Проверенные кризисные телефонные линии психологической помощи.
//
// ВНИМАНИЕ: каждый номер в этом файле был подтверждён по официальному
// источнику (сайт Минздрава, МЧС, государственный центр психического
// здоровья, официальные сайты региональных служб). Перед добавлением
// нового номера ОБЯЗАТЕЛЬНО проверяй актуальность по первоисточнику —
// неверный номер в этом файле может стоить жизни.
//
// Последняя проверка данных: 2026-04.
// Если ты видишь эту строку и с момента последней проверки прошло
// больше 6 месяцев — номера стоит перепроверить.

import 'cities.dart';

class Helpline {
  /// ISO-код страны: "RU", "BY", "KZ" или "INTL" для международных.
  final String country;

  /// "{COUNTRY}-federal" для общенациональных линий,
  /// иначе — точное название города (как в cities.dart),
  /// либо "fallback" для международных.
  final String region;

  /// Официальное название службы.
  final String name;

  /// Номер в том виде, в котором его набирают (для tel: ссылки).
  final String phone;

  /// Человекочитаемый формат для отображения
  /// (например, "+7 (800) 200-01-22" или "1303 (короткий номер)").
  final String phoneFull;

  /// true, если круглосуточно.
  final bool is24_7;

  /// Часы работы в свободной форме ("круглосуточно", "пн-пт 9:00-18:00").
  final String hours;

  /// Для кого предназначена (например, "взрослые и дети",
  /// "дети и подростки").
  final String target;

  /// Язык общения операторов.
  final String language;

  /// Опциональный номер/контакт WhatsApp (для тех, кому сложно говорить
  /// голосом). Если есть — приложение покажет отдельную кнопку.
  final String? whatsapp;

  /// Примечания: бесплатность, регион покрытия, альтернативы.
  final String notes;

  /// URL источника, где номер подтверждён.
  final String sourceUrl;

  const Helpline({
    required this.country,
    required this.region,
    required this.name,
    required this.phone,
    required this.phoneFull,
    required this.is24_7,
    required this.hours,
    required this.target,
    required this.language,
    required this.notes,
    required this.sourceUrl,
    this.whatsapp,
  });
}

/// Все проверенные кризисные линии.
const List<Helpline> kHelplines = [
  // ===== Россия — федеральные =====
  Helpline(
    country: 'RU',
    region: 'RU-federal',
    name: 'Детский телефон доверия',
    phone: '88002000122',
    phoneFull: '8-800-2000-122',
    is24_7: true,
    hours: 'круглосуточно',
    target: 'дети, подростки и их родители (принимают также взрослых)',
    language: 'русский',
    notes:
        'Бесплатно по всей России. Анонимно и конфиденциально. С мобильного также доступен короткий номер 124.',
    sourceUrl: 'https://fond-detyam.ru/detskiy-telefon-doveriya/',
  ),
  Helpline(
    country: 'RU',
    region: 'RU-federal',
    name: 'Центр экстренной психологической помощи МЧС России',
    phone: '+74959895050',
    phoneFull: '+7 (495) 989-50-50',
    is24_7: true,
    hours: 'круглосуточно',
    target: 'взрослые и дети',
    language: 'русский',
    notes: 'Работает по всей России. Анонимно и конфиденциально.',
    sourceUrl: 'https://psi.mchs.gov.ru/',
  ),

  // ===== Россия — регионы =====
  Helpline(
    country: 'RU',
    region: 'Москва',
    name: 'Московская служба психологической помощи населению',
    phone: '051',
    phoneFull: '051 (с городского) / +7 (495) 051 (с мобильного)',
    is24_7: true,
    hours: 'круглосуточно',
    target: 'взрослые и подростки',
    language: 'русский',
    notes: 'Для Москвы и Московской области. Бесплатно, анонимно.',
    sourceUrl: 'https://msph.ru/',
  ),

  // ===== Беларусь — федеральные =====
  Helpline(
    country: 'BY',
    region: 'BY-federal',
    name: 'Единая служба экстренной психологической помощи',
    phone: '133',
    phoneFull: '133 (короткий номер)',
    is24_7: true,
    hours: 'круглосуточно',
    target: 'взрослые и дети',
    language: 'русский, белорусский',
    notes:
        'Бесплатно для абонентов Белтелеком, А1, МТС, life:). Работает только внутри Беларуси.',
    sourceUrl:
        'https://minzdrav.gov.by/ru/dlya-belorusskikh-grazhdan/ekstrennaya-psikhologicheskaya-pomoshch.php',
  ),
  Helpline(
    country: 'BY',
    region: 'BY-federal',
    name: 'Республиканская детская телефонная линия',
    phone: '88011001611',
    phoneFull: '8-801-100-16-11',
    is24_7: true,
    hours: 'круглосуточно',
    target: 'дети и подростки',
    language: 'русский, белорусский',
    notes: 'Только для звонков изнутри Беларуси.',
    sourceUrl:
        'https://minzdrav.gov.by/ru/dlya-belorusskikh-grazhdan/ekstrennaya-psikhologicheskaya-pomoshch.php',
  ),

  // ===== Беларусь — регионы =====
  Helpline(
    country: 'BY',
    region: 'Минск',
    name: 'Телефон доверия для взрослых (Минск)',
    phone: '+375173524444',
    phoneFull: '+375 (17) 352-44-44',
    is24_7: true,
    hours: 'круглосуточно',
    target: 'взрослые',
    language: 'русский, белорусский',
    notes: 'Минская городская служба.',
    sourceUrl:
        'https://minzdrav.gov.by/ru/dlya-belorusskikh-grazhdan/ekstrennaya-psikhologicheskaya-pomoshch.php',
  ),
  Helpline(
    country: 'BY',
    region: 'Минск',
    name: 'Телефон доверия для детей и подростков (Минск)',
    phone: '+375172630303',
    phoneFull: '+375 (17) 263-03-03',
    is24_7: true,
    hours: 'круглосуточно',
    target: 'дети и подростки',
    language: 'русский, белорусский',
    notes: 'Минская городская служба.',
    sourceUrl:
        'https://minzdrav.gov.by/ru/dlya-belorusskikh-grazhdan/ekstrennaya-psikhologicheskaya-pomoshch.php',
  ),
  Helpline(
    country: 'BY',
    region: 'Брест',
    name: 'Телефон доверия (Брестская область)',
    phone: '+375162511013',
    phoneFull: '+375 (162) 51-10-13',
    is24_7: true,
    hours: 'круглосуточно',
    target: 'взрослые и дети',
    language: 'русский, белорусский',
    notes: 'Брестская областная служба.',
    sourceUrl:
        'https://minzdrav.gov.by/ru/dlya-belorusskikh-grazhdan/ekstrennaya-psikhologicheskaya-pomoshch.php',
  ),
  Helpline(
    country: 'BY',
    region: 'Витебск',
    name: 'Телефон доверия (Витебская область)',
    phone: '+375212616060',
    phoneFull: '+375 (212) 61-60-60',
    is24_7: true,
    hours: 'круглосуточно',
    target: 'взрослые и дети',
    language: 'русский, белорусский',
    notes: 'Витебская областная служба.',
    sourceUrl:
        'https://minzdrav.gov.by/ru/dlya-belorusskikh-grazhdan/ekstrennaya-psikhologicheskaya-pomoshch.php',
  ),
  Helpline(
    country: 'BY',
    region: 'Гомель',
    name: 'Телефон доверия (Гомельская область)',
    phone: '+375232315161',
    phoneFull: '+375 (232) 31-51-61',
    is24_7: true,
    hours: 'круглосуточно',
    target: 'взрослые и дети',
    language: 'русский, белорусский',
    notes: 'Гомельская областная служба.',
    sourceUrl:
        'https://minzdrav.gov.by/ru/dlya-belorusskikh-grazhdan/ekstrennaya-psikhologicheskaya-pomoshch.php',
  ),
  Helpline(
    country: 'BY',
    region: 'Гродно',
    name: 'Телефон доверия (Гродненская область)',
    phone: '170',
    phoneFull: '170 (короткий номер) / +375 (152) 39-83-31',
    is24_7: true,
    hours: 'круглосуточно',
    target: 'взрослые и дети',
    language: 'русский, белорусский',
    notes: 'Короткий номер только внутри Гродненской области.',
    sourceUrl:
        'https://minzdrav.gov.by/ru/dlya-belorusskikh-grazhdan/ekstrennaya-psikhologicheskaya-pomoshch.php',
  ),
  Helpline(
    country: 'BY',
    region: 'Могилёв',
    name: 'Телефон доверия (Могилёвская область)',
    phone: '+375222711161',
    phoneFull: '+375 (222) 71-11-61',
    is24_7: true,
    hours: 'круглосуточно',
    target: 'взрослые и дети',
    language: 'русский, белорусский',
    notes: 'Могилёвская областная служба.',
    sourceUrl:
        'https://minzdrav.gov.by/ru/dlya-belorusskikh-grazhdan/ekstrennaya-psikhologicheskaya-pomoshch.php',
  ),

  // ===== Казахстан — федеральные =====
  Helpline(
    country: 'KZ',
    region: 'KZ-federal',
    name: 'Национальная линия доверия (Союз кризисных центров Казахстана)',
    phone: '150',
    phoneFull: '150 (короткий номер)',
    is24_7: true,
    hours: 'круглосуточно',
    target:
        'психологическая и правовая помощь в кризисных ситуациях, пострадавшим от насилия, суицидальные мысли',
    language: 'русский, казахский',
    whatsapp: '+77081060810',
    notes:
        'Бесплатно с любого оператора РК. Доступен также WhatsApp: +7 708 106-08-10.',
    sourceUrl: 'https://schitaetsya.kz/crisis-centers',
  ),

  // ===== Казахстан — регионы =====
  Helpline(
    country: 'KZ',
    region: 'Алматы',
    name: 'Телефон доверия Городского центра психического здоровья',
    phone: '1303',
    phoneFull: '1303 (короткий номер)',
    is24_7: true,
    hours: 'круглосуточно',
    target: 'экстренная психологическая помощь, кризисные состояния',
    language: 'русский, казахский',
    notes:
        'ГКП «Городской центр психического здоровья» акимата Алматы. Анонимно.',
    sourceUrl: 'https://cpzalmaty.kz/',
  ),
  Helpline(
    country: 'KZ',
    region: 'Астана',
    name: 'Телефон экстренной психологической помощи (Астана)',
    phone: '+77172547603',
    phoneFull: '+7 (7172) 54-76-03',
    is24_7: true,
    hours: 'круглосуточно',
    target: 'экстренная анонимная психологическая помощь населению',
    language: 'русский, казахский',
    notes:
        'ГКП «Городской центр психического здоровья» акимата Астаны. Кабинет психолога кризисного телефона доверия.',
    sourceUrl:
        'https://www.qpdo.kz/index.php/ru/pages/otdeleniya/ambulatoriya/kabinet-psikhologa-krizisnogo-telefona-doveriya',
  ),

  // ===== Международный fallback =====
  Helpline(
    country: 'INTL',
    region: 'fallback',
    name: 'Find A Helpline — международный каталог',
    phone: '',
    phoneFull: 'findahelpline.com/ru',
    is24_7: false,
    hours: 'зависит от конкретной линии',
    target: 'все категории',
    language: 'многоязычный, включая русский',
    notes:
        'Международный агрегатор проверенных кризисных линий. Позволяет найти службу по стране и теме.',
    sourceUrl: 'https://findahelpline.com/ru',
  ),
];

/// Возвращает список кризисных линий для указанного пользователем
/// города. Приоритет:
///   1. Линии, точно совпадающие с городом (могут быть несколько — например,
///      в Минске есть отдельные для взрослых и детей).
///   2. Федеральные линии страны этого города.
///   3. Международный fallback.
///
/// Если город пустой или неизвестен (не в cities.dart) — показываем
/// федеральные России (как основной аудитории) + международный fallback.
/// Пользователь в любом случае не остаётся без помощи.
List<Helpline> getHelplinesForUserCity(String userCity) {
  final result = <Helpline>[];
  final trimmed = userCity.trim();

  if (trimmed.isEmpty) {
    // Нет города — даём федеральные России + международный.
    result.addAll(kHelplines.where((h) => h.region == 'RU-federal'));
    result.addAll(kHelplines.where((h) => h.country == 'INTL'));
    return result;
  }

  final matched = findCityByName(trimmed);
  if (matched == null) {
    // Город введён вручную и не сматчился со списком.
    // Показываем федеральные России + международный.
    // (Если когда-то появится язык-детект по кириллице — можно умнее.)
    result.addAll(kHelplines.where((h) => h.region == 'RU-federal'));
    result.addAll(kHelplines.where((h) => h.country == 'INTL'));
    return result;
  }

  // 1. Точное совпадение по городу
  result.addAll(kHelplines.where((h) => h.region == matched.name));

  // 2. Федеральные той же страны
  final federalRegion = '${matched.country}-federal';
  result.addAll(kHelplines.where((h) => h.region == federalRegion));

  // 3. Международный fallback всегда в конце
  result.addAll(kHelplines.where((h) => h.country == 'INTL'));

  return result;
}
