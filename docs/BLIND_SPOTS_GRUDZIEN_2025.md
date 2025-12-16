# Lista Zakupowa & Blind Spots
## Raport: Grudzień 2025 | Walidacja: Styczeń 2026

---

## ZAKUPY PRIORYTETOWE

### KUPUJ REGULARNIE (co tydzień)

| Produkt | Ile | Dlaczego | Status |
|---------|-----|----------|--------|
| **Mexilhões** (małże) | 1-2x/tyg | B12, żelazo heme, cynk, selen | [ ] |
| **Nozes** (orzechy włoskie) | 1 opak | Omega-3 ALA, magnez | [ ] |
| **Couve kale** | 1 opak | Wit. K, wapń, sulforafany | [ ] |
| **Espinafres** | 2 opak | Żelazo, foliany, magnez | [ ] |
| **Linhaça moída** | 1 opak/2tyg | Omega-3 ALA, błonnik | [ ] |

### ZWIĘKSZ (kupujesz za mało)

| Produkt | Teraz | Cel | Po co |
|---------|-------|-----|-------|
| **Pepino świeży** | 1.5 kg/rok | 1 kg/mies | Sytość, żucie |
| **Aipo (seler)** | 1 kg/rok | 0.5 kg/mies | Sytość, żucie |
| **Mirtilos** | 15x/rok | 2x/tyg | Antocyjany, mózg |
| **Sementes cânhamo** | 3x/rok | 1x/mies | Omega-3, białko |
| **Rabanete** | 4x/rok | 2x/mies | Sytość, żucie |

### DODAJ (brakuje całkowicie)

| Produkt | Gdzie | Po co |
|---------|-------|-------|
| **Amêijoas** | Peixaria/mrożonki | Alternatywa dla małży |
| **Castanha do Pará** | Frutos secos | Selen (2-3 szt/dzień max!) |
| **Tempeh** | Chłodnia (Cem Porcento) | Fermentowana soja, probiotyki |
| **Levedura de cerveja** | Bio/naturalna | Wit. B-kompleks bez cukru |

---

## CO ROBISZ DOBRZE (kontynuuj!)

- [x] Tofu bio - 40 szt/rok
- [x] Kefir bio - 51 szt/rok
- [x] Kombucha - 70+ szt/rok
- [x] Hummus - 50+ szt/rok
- [x] Jajka bio - 25+ opak/rok
- [x] Seitan - 22 szt/rok
- [x] Czekolada 85%+ - minimalne cukry
- [x] Suplementacja: Tran + D3

---

## UNIKAJ/OGRANICZ (refluks)

| Produkt | Ryzyko | Twój status |
|---------|--------|-------------|
| Pomidory surowe | Wysokie | ~20 zakupów - monitoruj |
| Cytrusy | Średnie | 2.8 kg - OK jeśli tolerujesz |
| Kawa | Średnie | 13 zakupów - ogranicz przy objawach |
| Czekolada mleczna | Średnie | Brak - super! |
| Ostre (piri-piri) | Wysokie | 2 zakupy - OK |

---

## SUPLEMENTACJA

| Suplement | Status | Dawka |
|-----------|--------|-------|
| Tran (omega-3) | OK | Kontynuuj |
| Witamina D3 | OK | 2000 j.m./dzień |
| B12 | Monitoruj | Zbadaj krew raz/rok |
| Magnez | Rozważ | Jeśli kurcze/zmęczenie |

---

## METRYKI DO WALIDACJI (Styczeń 2026)

### Sprawdź w bazie danych:

```sql
-- Małże
SELECT COUNT(*) FROM purchases pu
JOIN products p ON pu.product_id = p.id
WHERE LOWER(p.name) LIKE '%mexilh%' OR LOWER(p.name) LIKE '%ameij%';

-- Zielone liściaste
SELECT COUNT(*) FROM purchases pu
JOIN products p ON pu.product_id = p.id
WHERE LOWER(p.name) LIKE '%kale%' OR LOWER(p.name) LIKE '%espinafr%';

-- Orzechy włoskie
SELECT COUNT(*) FROM purchases pu
JOIN products p ON pu.product_id = p.id
WHERE LOWER(p.name) LIKE '%noz%' OR LOWER(p.name) LIKE '%nozes%';

-- Jagody
SELECT COUNT(*) FROM purchases pu
JOIN products p ON pu.product_id = p.id
WHERE LOWER(p.name) LIKE '%mirtilo%' OR LOWER(p.name) LIKE '%framboesa%';
```

### Cele na Styczeń 2026:

| Kategoria | Grudzień 2025 | Cel Styczeń |
|-----------|---------------|-------------|
| Małże | 2 zakupy | 6+ zakupów |
| Kale/Espinafres | 6 zakupów | 15+ zakupów |
| Nozes | 3 zakupy | 8+ zakupów |
| Mirtilos | 15 zakupów | 20+ zakupów |
| Pepino świeży | 1.5 kg | 4+ kg |

---

## SZYBKA CHECKLISTA ZAKUPOWA

Wydrukuj i zabierz do sklepu:

```
ZAWSZE (co tydzień):
[ ] Mexilhões lub amêijoas
[ ] Espinafres (świeże lub mrożone)
[ ] Nozes (miolo)
[ ] Mirtilos (świeże lub mrożone)
[ ] Kefir bio

CO 2 TYGODNIE:
[ ] Couve kale
[ ] Linhaça moída
[ ] Pepino świeży
[ ] Aipo

CO MIESIĄC:
[ ] Sementes de cânhamo
[ ] Castanha do Pará (małe opakowanie!)
[ ] Tempeh
[ ] Levedura de cerveja
```

---

*Wygenerowano: 16.12.2025 | Następna walidacja: 16.01.2026*
*Użyj `/dieta` aby sprawdzić postępy*
