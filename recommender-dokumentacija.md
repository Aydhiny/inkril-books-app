# Inkril — Dokumentacija sistema preporuke

**Student:** Ajdin Mehmedović | **Index:** IB220088  
**Predmet:** Razvoj softvera II — FIT Mostar

---

## 1. Pregled algoritma

Inkril koristi **hibridni sistem preporuke** koji kombinuje dvije tehnike:

| Tehnika | Opis |
|---------|------|
| **Content-based Filtering** | Preporučuje knjige na osnovu žanrova koje korisnik najviše čita |
| **Collaborative Filtering** | Preporučuje knjige koje su sličnim korisnicima bile visoko ocijenjene |

Implementacija: `backend/src/Inkril.Infrastructure/Services/RecommendationService.cs`

---

## 2. Ulazni signali

| Signal | Tabela | Opis |
|--------|--------|------|
| Čitanje po žanru | `ReadingSessions` + `BookGenres` | Ukupno minuta provedenih čitajući knjige određenog žanra |
| Ocjene knjiga | `Reviews` | Ocjene korisnika (1–5) — koriste se za kolaborativno filtriranje |
| Korisnikova biblioteka | `UserBooks` | Knjige koje je korisnik već dodao — isključuju se iz preporuka |

---

## 3. Content-based Filtering

**Cilj:** pronaći knjige u žanrovima koji korisnika najviše interesuju, na osnovu stvarnog vremena čitanja.

### Koraci:

1. Iz `ReadingSessions` zbrojiti ukupne minute čitanja po žanru (join s `BookGenres`)
2. Uzeti **top 5 žanrova** po ukupnim minutama
3. Pronaći knjige koje spadaju u te žanrove, a korisnik ih još nije dodao u biblioteku
4. Svaka preporuka dobija **razlog (Reason)**: `"Because you read [ime žanra]"` — uzima se žanr s najvišom afinitetom koji odgovara toj knjizi

**Fallback:** Ako korisnik nema historiju čitanja, vraćaju se najpopularnije javne knjige po prosječnoj ocjeni s razlogom `"Popular on Inkril"`.

---

## 4. Collaborative Filtering

**Cilj:** pronaći korisnike sa sličnim ukusom i preporučiti knjige koje su oni visoko ocijenili.

### Koraci:

1. Iz `ReadingSessions` + `BookGenres` dohvatiti žanrove koje je trenutni korisnik čitao
2. Pronaći **slične korisnike** — one koji su čitali knjige u istim žanrovima (veći overlap = veća sličnost)
3. Od tih sličnih korisnika uzeti knjige s ocjenom **≥ 4** (iz `Reviews`), rankirane po prosječnoj ocjeni
4. Isključiti knjige koje korisnik već ima u `UserBooks`
5. Svaka preporuka dobija razlog: `"Readers with similar taste enjoyed this"`

---

## 5. Strategija spajanja (merge)

```
contentBased  = top rezultati content-based filtriranja
collaborative = top rezultati collaborative filtriranja

merged = contentBased ++ collaborative (bez duplikata, content-based razlog ima prednost)
         sortirano tako da knjige koje se pojavljuju u OBA skupa dolaze PRVE
         .take(count)
```

**Zašto content-based razlog ima prednost pri preklapanju?**  
Konkretno ime žanra (`"Because you read Science Fiction"`) je informativan za korisnika, dok je generički razlog (`"Readers with similar taste enjoyed this"`) manje specifičan.

---

## 6. Objašnjive preporuke (Explainable Recommendations)

Svaka preporuka vraća `Reason` polje u API odgovoru:

| Izvor | Primjer razloga |
|-------|----------------|
| Content-based | `"Because you read Science Fiction"` |
| Content-based | `"Because you read Fantasy"` |
| Collaborative | `"Readers with similar taste enjoyed this"` |
| Fallback (popularnost) | `"Popular on Inkril"` |

Razlog se prikazuje korisniku ispod svake preporučene knjige u mobilnoj aplikaciji (sekcija "Recommended for You" na Library ekranu).

---

## 7. API

```
GET /api/recommendations?count=10
Authorization: Bearer <token>
```

**Response (primjer jednog elementa):**
```json
{
  "id": "3fa85f64-...",
  "title": "Dune",
  "author": "Frank Herbert",
  "genres": ["Science Fiction"],
  "averageRating": 4.7,
  "reason": "Because you read Science Fiction"
}
```

---

## 8. Ograničenja i moguća unapređenja

| Ograničenje | Moguće unapređenje |
|-------------|-------------------|
| Cosine sličnost se računa implicitno (overlap žanrova) | Eksplicitni cosine similarity na vektorima ocjena |
| Nema vremenske težine (stare sesije imaju isti uticaj) | Decay faktor — novije sesije imaju veću težinu |
| Collaborative filtriranje ignoriše broj recenzija | Bayesian average za stabilizaciju ocjena s malo recenzija |
