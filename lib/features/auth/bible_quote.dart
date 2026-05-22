class BibleQuote {
  final String text;
  final String reference;

  const BibleQuote({
    required this.text,
    required this.reference,
  });
}

const List<BibleQuote> bibleQuotes = [
  BibleQuote(
    text: "Dove sono due o tre riuniti nel mio nome, io sono in mezzo a loro.",
    reference: "Matteo 18,20",
  ),
  BibleQuote(
    text: "Io sono con voi tutti i giorni, fino alla fine del mondo.",
    reference: "Matteo 28,20",
  ),
  BibleQuote(
    text: "Lasciate che i bambini vengano a me.",
    reference: "Marco 10,14",
  ),
  BibleQuote(
    text: "Tutto posso in colui che mi dà forza.",
    reference: "Filippesi 4,13",
  ),
  BibleQuote(
    text: "La gioia del Signore è la vostra forza.",
    reference: "Neemia 8,10",
  ),
];