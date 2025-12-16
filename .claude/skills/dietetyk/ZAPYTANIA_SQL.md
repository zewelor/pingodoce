# Zapytania SQL - Analiza Dietetyczna

## Podstawowe statystyki

```sql
-- Liczba transakcji i produktów
SELECT
  (SELECT COUNT(*) FROM transactions) as transakcje,
  (SELECT COUNT(*) FROM products) as produkty,
  (SELECT COUNT(*) FROM purchases) as zakupy;

-- Zakres dat
SELECT MIN(transaction_date) as od, MAX(transaction_date) as do FROM transactions;

-- Wydatki miesięczne
SELECT strftime('%Y-%m', transaction_date) as miesiac,
       COUNT(*) as transakcje,
       SUM(total) as wydatki
FROM transactions
GROUP BY strftime('%Y-%m', transaction_date)
ORDER BY miesiac;
```

## Blind Spots - Monitoring

### Małże i skorupiaki
```sql
SELECT p.name, SUM(pu.quantity) as qty, COUNT(*) as zakupy
FROM purchases pu JOIN products p ON pu.product_id = p.id
WHERE LOWER(p.name) LIKE '%mexilh%'
   OR LOWER(p.name) LIKE '%ameij%'
   OR LOWER(p.name) LIKE '%berbig%'
   OR LOWER(p.name) LIKE '%ostra%'
GROUP BY p.id
ORDER BY zakupy DESC;
```

### Zielone liściaste
```sql
SELECT p.name, SUM(pu.quantity) as qty, COUNT(*) as zakupy
FROM purchases pu JOIN products p ON pu.product_id = p.id
WHERE LOWER(p.name) LIKE '%kale%'
   OR LOWER(p.name) LIKE '%espinafr%'
   OR LOWER(p.name) LIKE '%rucula%'
   OR LOWER(p.name) LIKE '%agriao%'
   OR LOWER(p.name) LIKE '%couve%'
GROUP BY p.id
ORDER BY zakupy DESC;
```

### Orzechy i nasiona
```sql
SELECT p.name, SUM(pu.quantity) as qty, COUNT(*) as zakupy
FROM purchases pu JOIN products p ON pu.product_id = p.id
WHERE LOWER(p.name) LIKE '%noz%'
   OR LOWER(p.name) LIKE '%nozes%'
   OR LOWER(p.name) LIKE '%linhac%'
   OR LOWER(p.name) LIKE '%linhaça%'
   OR LOWER(p.name) LIKE '%canhamo%'
   OR LOWER(p.name) LIKE '%chia%'
   OR LOWER(p.name) LIKE '%castanha%'
GROUP BY p.id
ORDER BY zakupy DESC;
```

### Jagody
```sql
SELECT p.name, SUM(pu.quantity) as qty, COUNT(*) as zakupy
FROM purchases pu JOIN products p ON pu.product_id = p.id
WHERE LOWER(p.name) LIKE '%mirtilo%'
   OR LOWER(p.name) LIKE '%framboesa%'
   OR LOWER(p.name) LIKE '%morango%'
   OR LOWER(p.name) LIKE '%amora%'
   OR LOWER(p.name) LIKE '%silvestr%'
GROUP BY p.id
ORDER BY zakupy DESC;
```

### Produkty do żucia
```sql
SELECT p.name, SUM(pu.quantity) as qty, COUNT(*) as zakupy
FROM purchases pu JOIN products p ON pu.product_id = p.id
WHERE LOWER(p.name) LIKE '%pepino%'
   OR LOWER(p.name) LIKE '%aipo%'
   OR LOWER(p.name) LIKE '%raban%'
   OR LOWER(p.name) LIKE '%cenoura%'
   OR LOWER(p.name) LIKE '%pimento%'
   AND LOWER(p.name) NOT LIKE '%pimenta%'
GROUP BY p.id
ORDER BY zakupy DESC;
```

## Walidacja - porównanie okresów

```sql
-- Ostatni miesiąc vs poprzedni
WITH ostatni AS (
  SELECT p.name, SUM(pu.quantity) as qty
  FROM purchases pu JOIN products p ON pu.product_id = p.id
  WHERE pu.purchase_date >= date('now', '-30 days')
  GROUP BY p.id
),
poprzedni AS (
  SELECT p.name, SUM(pu.quantity) as qty
  FROM purchases pu JOIN products p ON pu.product_id = p.id
  WHERE pu.purchase_date >= date('now', '-60 days')
    AND pu.purchase_date < date('now', '-30 days')
  GROUP BY p.id
)
SELECT
  COALESCE(o.name, p.name) as produkt,
  COALESCE(p.qty, 0) as poprzedni_miesiac,
  COALESCE(o.qty, 0) as ostatni_miesiac
FROM ostatni o
FULL OUTER JOIN poprzedni p ON o.name = p.name
ORDER BY ostatni_miesiac DESC;
```

## Produkty problematyczne (refluks)

```sql
SELECT p.name, SUM(pu.quantity) as qty, COUNT(*) as zakupy
FROM purchases pu JOIN products p ON pu.product_id = p.id
WHERE LOWER(p.name) LIKE '%tomate%'
   OR LOWER(p.name) LIKE '%laranja%'
   OR LOWER(p.name) LIKE '%limao%'
   OR LOWER(p.name) LIKE '%piri%'
   OR LOWER(p.name) LIKE '%picant%'
GROUP BY p.id
ORDER BY zakupy DESC;
```

## Top produkty - białko

```sql
SELECT p.name, pn.protein, SUM(pu.quantity) as qty
FROM purchases pu
JOIN products p ON pu.product_id = p.id
LEFT JOIN product_nutritions pn ON pn.product_id = p.id
WHERE pn.protein > 10
GROUP BY p.id
ORDER BY qty DESC
LIMIT 20;
```
