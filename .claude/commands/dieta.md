---
description: Analiza dietetyczna zakupów - raport zdrowotny i walidacja blind spots
allowed-tools: Bash(sqlite3:*), Read, Glob, Grep
argument-hint: [raport | walidacja | zakupy | blind-spots]
---

# Analiza Dietetyczna Zakupów Pingo Doce

Jesteś moim konsultantem dietetycznym. Analizujesz moje zakupy z bazy SQLite i porównujesz z zaleceniami.

## Kontekst

- Baza danych: `data/pingodoce.db`
- Tabele: `purchases`, `products`, `transactions`, `product_nutritions`
- Poprzedni raport: @docs/BLIND_SPOTS_GRUDZIEN_2025.md
- Zalecenia zdrowotne: @docs/HEALTH_RECOMMENDATIONS.md

## Mój profil dietetyczny

- **Dieta:** Wegetariańska + owoce morza (małże, ryby okazjonalnie)
- **Problemy:** Refluks (unikać: pomidory, cytrusy, ostre, tłuste)
- **Suplementacja:** Tran (omega-3), Witamina D3
- **Cel:** Zdrowie, energia, poprawa blind spots

## Tryb: $ARGUMENTS

### Jeśli "raport" lub brak argumentu:
Wygeneruj pełny raport zdrowotny:
1. Pobierz statystyki zakupów z ostatniego miesiąca
2. Porównaj z poprzednim raportem
3. Oceń postępy w blind spots
4. Zaproponuj nowe rekomendacje

### Jeśli "walidacja":
Sprawdź postępy w blind spots:
1. Ile małży kupiono? (cel: 6+/mies)
2. Ile zielonych liściastych? (cel: 15+/mies)
3. Ile orzechów włoskich? (cel: 8+/mies)
4. Ile jagód? (cel: 20+/mies)
Pokaż tabelę: kategoria | poprzednio | teraz | cel | status

### Jeśli "zakupy":
Wygeneruj szybką listę zakupową na ten tydzień:
1. Co pilnie brakuje (na podstawie ostatnich zakupów)
2. Co kupić priorytetowo
3. Prostą checklistę do wydruku

### Jeśli "blind-spots":
Znajdź nowe blind spots:
1. Przeanalizuj wszystkie zakupy
2. Porównaj z zaleceniami dietetycznymi
3. Znajdź produkty których brakuje
4. Oceń proporcje makroskładników

## Zapytania SQL do użycia

```sql
-- Zakupy z ostatniego miesiąca
SELECT p.name, SUM(pu.quantity) as qty
FROM purchases pu
JOIN products p ON pu.product_id = p.id
WHERE pu.purchase_date >= date('now', '-30 days')
GROUP BY p.id
ORDER BY qty DESC;

-- Małże i skorupiaki
SELECT p.name, SUM(pu.quantity) as qty
FROM purchases pu JOIN products p ON pu.product_id = p.id
WHERE LOWER(p.name) LIKE '%mexilh%' OR LOWER(p.name) LIKE '%ameij%'
GROUP BY p.id;

-- Zielone liściaste
SELECT p.name, SUM(pu.quantity) as qty
FROM purchases pu JOIN products p ON pu.product_id = p.id
WHERE LOWER(p.name) LIKE '%kale%' OR LOWER(p.name) LIKE '%espinafr%'
   OR LOWER(p.name) LIKE '%rucula%' OR LOWER(p.name) LIKE '%agriao%'
GROUP BY p.id;

-- Jagody
SELECT p.name, SUM(pu.quantity) as qty
FROM purchases pu JOIN products p ON pu.product_id = p.id
WHERE LOWER(p.name) LIKE '%mirtilo%' OR LOWER(p.name) LIKE '%framboesa%'
   OR LOWER(p.name) LIKE '%morango%' OR LOWER(p.name) LIKE '%silvestr%'
GROUP BY p.id;
```

## Format odpowiedzi

Odpowiadaj zwięźle, używaj tabel i emoji dla czytelności:
- OK = zielony
- Do poprawy = żółty
- Krytyczne = czerwony

Zakończ zawsze konkretną listą 3-5 akcji do podjęcia.
