# Pingo Doce API Documentation

Base URL: `https://app.pingodoce.pt`

## Authentication

### Headers (Required for authenticated endpoints)

```
Authorization: Bearer {access_token}
Content-Type: application/json; charset=UTF-8
Accept-Language: en-US
User-Agent: okhttp/4.12.0
X-App-Version: v-3.12.4 buildType-release flavor-prod
X-Device-Version: Android-30
X-Screen-Density: 1.3312501
Pdapp-Storeid: {store_id}         # -1 for default
Pdapp-Cardnumber: {ompdCard}
Pdapp-Lcid: {loyaltyId}
Pdapp-Hid: {householdId}
Pdapp-Clubs: ""
```

---

## Endpoints

### 1. Identity & Authentication

#### POST `/api/v2/identity/sms/verifyNumber`

Verify if phone number is registered.

**Query Parameters:**
- `version`: 2

**Request Body:**
```json
{
  "phoneNumber": "+351XXXXXXXXX"
}
```

**Response:**
```json
{
  "status": "PinLocked"  // or other statuses
}
```

---

#### POST `/api/v2/identity/onboarding/login`

Login with credentials.

**Request Body:**
```json
{
  "phoneNumber": "+351XXXXXXXXX",
  "password": "XXXXXX"
}
```

**Response:**
```json
{
  "profile": {
    "userId": "uuid",
    "firstName": "Name",
    "lastName": "Surname",
    "phoneNumber": "+351XXXXXXXXX",
    "email": "email@example.com",
    "emailValidated": true,
    "nif": "XXXXXXXXX",
    "loyaltyId": "XXXXXXXXXXXXXXXX",
    "householdId": "XXXXXXXXXX",
    "customerStatus": "Registered",
    "birthDate": "0001-01-01T00:00:00+00:00",
    "ompdCard": "XXXXXXXXXXXXX",
    "agreedTerms": {
      "type": "TermsPrivacy",
      "version": "3.16"
    }
  },
  "token": {
    "access_token": "eyJ...",
    "expires_in": 3600,
    "refresh_token": "XXXXXXXXX",
    "token_type": "Bearer",
    "scope": "offline_access openid pdapp.change_number pdapp.full_access pdapp.onboarding_access pdapp.sms_access"
  }
}
```

---

#### POST `/connect/revocation`

Revoke/logout token.

---

#### GET `/api/v2/identity/consents/latest`

Get latest terms and conditions versions.

**Response:**
```json
[
  {
    "version": "3.1.2",
    "privacyUrl": "",
    "termsOfUseUrl": "https://app.pingodoce.pt/Policy?...",
    "type": "Club",
    "title": "Termos e Condições Especiais – Clube do Bebé"
  },
  {
    "version": "3.16",
    "privacyUrl": "https://...",
    "termsOfUseUrl": "https://...",
    "type": "TermsPrivacy",
    "title": "Termos e Condições - O Meu Pingo Doce"
  }
]
```

---

### 2. User Profile

#### GET `/api/v2/user/userprofiles`

Get user profile.

**Response:**
```json
{
  "userId": "uuid",
  "firstName": "Name",
  "lastName": "Surname",
  "phoneNumber": "+351XXXXXXXXX",
  "email": "email@example.com",
  "emailValidated": true,
  "nif": "XXXXXXXXX",
  "loyaltyId": "XXXXXXXX",
  "householdId": "XXXXXXXXXX",
  "customerStatus": "Registered",
  "ompdCard": "XXXXXXXXXXXXX",
  "agreedTerms": {
    "type": "TermsPrivacy",
    "version": "3.16"
  },
  "loginFlow": "Pin",
  "hasPassword": true
}
```

---

#### GET `/api/v2/user/userprofiles/store`

Get user's default store with full details.

**Response:**
```json
{
  "id": 17,
  "name": "Porto Santo Praia Dourada",
  "address": "Rua Dr. José Diamantino Lima\n9400-168 - Porto Santo",
  "phone": "+351 291980080",
  "schedules": [
    {
      "dayOfWeek": 0,  // 0=Sunday, 1=Monday, etc.
      "openingTime": "2025-06-01T06:30:00+00:00",
      "closingTime": "2025-06-01T21:00:00+00:00",
      "isOnMaintenance": false
    }
  ],
  "takeAwaySchedules": [],
  "coordinates": {
    "latitude": 33.060359954833984,
    "longitude": -16.332168579101562
  },
  "isDefault": true,
  "specialDays": [
    {
      "date": "2025-04-20",
      "schedule": {
        "openingTime": "2025-04-20T06:30:00+00:00",
        "closingTime": "2025-04-20T13:00:00+00:00"
      }
    }
  ],
  "distance": 0.0,
  "isOnMaintenance": false,
  "searchEnabled": true,
  "services": [
    {"name": "Água Filtrada ECO"},
    {"name": "BemEstar | Corner"},
    {"name": "Encomendas De Talho e Peixaria"},
    {"name": "Restaurante"}
  ],
  "commodities": [
    {"name": "Estacionamento"}
  ],
  "manager": {
    "role": "Gerente",
    "name": "Manager Name"
  }
}
```

---

#### GET `/api/v2/user/stores`

Get all user's saved/favorite stores.

**Response:** Array of store objects (same structure as above)

---

#### GET `/api/v2/user/notifications`

Get notification preferences.

**Response:**
```json
{
  "sms": false,
  "email": false,
  "personalized": false,
  "clubs": false,
  "shoppingList": false,
  "takeaway": false,
  "flyers": false,
  "pubOnline": false
}
```

---

### 3. Transactions History

#### GET `/api/v2/user/transactionsHistory`

Get paginated transaction list.

**Query Parameters:**
- `pageNumber`: 1 (starts from 1)
- `pageSize`: 20 (default)

**Response:**
```json
[
  {
    "transactionId": "2025052600130040007000158057",
    "storeId": 13,
    "storeName": "Super Porto Santo",
    "totalItems": 15,
    "totalDiscount": 0.0,
    "total": 34.37,
    "transactionDate": "2025-05-26T00:00:00+01:00"
  }
]
```

---

#### GET `/api/v2/user/transactionsHistory/details`

Get full transaction details with products.

**Query Parameters:**
- `id`: Transaction ID (string)

**Response:**
```json
{
  "transactionId": 158057,
  "transactionNumber": "2025052600130040007000158057",
  "storeName": "Super Porto Santo",
  "totalItems": 15,
  "totalDiscount": 0.0,
  "total": 34.37,
  "products": [
    {
      "purchasePrice": "2,60",
      "purchaseQuantity": "4",
      "elasticID": "17_846908",
      "productInternalCode": 846908,
      "measureUnitCode": "UN",
      "categoryId": 11,
      "name": "Iogurte Skyr Natural Pingo Doce 150 g",
      "storePrice": "2,60",
      "thumb": "https://app.pingodoce.pt/images/products/thumbnail/846908_UN.png",
      "image": "https://app.pingodoce.pt/images/products/fullsize/846908_UN.png",
      "hasLowerPrice": false,
      "brand": {
        "id": 117,
        "ownBrand": false,
        "name": "GO ACTIVE",
        "logo": ""
      },
      "discountSortOrder": 10000,
      "bestPromotion": {
        "id": 50012652,
        "price": "63,99",
        "shortLabel": "20%",
        "groupClass": "",
        "groupLxPy": "",
        "endDate": "2025-12-26T23:59:59+00:00",
        "lxPySpecial": false,
        "badgeUrl": "https://app.pingodoce.pt/images/promotionBadges/save20-typeA.webp",
        "shortBadgeUrl": "https://app.pingodoce.pt/images/promotionBadges/save20-typeA.webp",
        "showDisclaimer": false,
        "title": "Promoção",
        "description": "Promoção disponível para todos os clientes do Pingo Doce",
        "terms": "20,00%",
        "finalPriceType": "Promo"
      },
      "terms": "20,00%",
      "isNew": false
    }
  ],
  "transactionDate": "2025-05-26T00:00:00+01:00",
  "dateCreated": "2025-05-26T00:00:00+01:00",
  "benefitsLabel": [],
  "idOperator": "0040",
  "idPos": "004",
  "storeId": "13"
}
```

### Product Object Fields

| Field | Type | Description |
|-------|------|-------------|
| `purchasePrice` | string | Price paid (European format "X,XX") |
| `purchaseQuantity` | string | Quantity purchased |
| `elasticID` | string | ElasticSearch ID "{storeId}_{productCode}" |
| `productInternalCode` | int | Internal product code |
| `measureUnitCode` | string | Unit: UN (unit), KG (kilogram), CX (box) |
| `categoryId` | int | Category ID (see Categories below) |
| `name` | string | Product name |
| `storePrice` | string | Regular store price |
| `thumb` | string | Thumbnail image URL (optional) |
| `image` | string | Full-size image URL (optional) |
| `hasLowerPrice` | bool | If product has lower price elsewhere |
| `brand` | object | Brand info |
| `brand.id` | int | Brand ID |
| `brand.ownBrand` | bool | Is Pingo Doce own brand |
| `brand.name` | string | Brand name |
| `brand.logo` | string | Brand logo URL |
| `discountSortOrder` | int | Sort order for discounts |
| `bestPromotion` | object | Active promotion (if any) |
| `terms` | string | Promotion terms |
| `isNew` | bool | Is new product |

### Category IDs

| ID | Category |
|----|----------|
| -1 | Unknown/Misc |
| 1 | Frutas e Vegetais |
| 4 | Padaria e Pastelaria |
| 5 | Pastelaria |
| 6 | Charcutaria |
| 7 | Queijos |
| 8 | Vegetais/Saladas |
| 9 | Congelados |
| 10 | Laticínios |
| 11 | Iogurtes |
| 12 | Garrafeira |
| 13 | Bebidas |
| 14 | Água |
| 15 | Mercearia |
| 16 | Higiene |
| 17 | Saúde |
| 18 | Limpeza Casa |
| 20 | Casa/Bazar |

---

### 4. Card & Benefits

#### GET `/api/v2/user/cardassociations/card`

Get card info.

**Response:**
```json
{
  "cardNumber": "2446104951158",
  "cardType": "PoupaMais",
  "status": "APPROVED",
  "poupaMaisStatus": "OwnerNoRequests",
  "hasRequests": false
}
```

---

#### POST `/api/v2/user/cardassociations/benefits`

Get active coupons/benefits.

**Request Body:**
```json
{
  "chosenStoreId": 17,
  "ompdCard": "XXXXXXXXXXXXX"
}
```

**Response:**
```json
{
  "benefits": [
    {
      "id": "278779",
      "startDate": "2025-05-27T00:00:00+01:00",
      "endDate": "2025-06-02T23:59:59+01:00",
      "description": "Bolacha Belga Limão Pingo Doce 80g",
      "prefix": "N26",
      "imageUrl": "https://app.pingodoce.pt/images/benefitTypes/...",
      "sortOrder": 7000,
      "state": "ToBeActivated",
      "type": "Virtual",
      "isFromPartner": false,
      "extraInfo": [...],
      "title": "N26",
      "isNew": true,
      "isExpiring": false,
      "ean": 0,
      "moreInfo": "..."
    }
  ]
}
```

---

#### POST `/api/v2/user/cardassociations/fuelbenefits`

Get fuel discount benefits.

**Request Body:**
```json
{
  "pmCard": "XXXXXXXXXXXXX"
}
```

**Response:**
```json
{
  "fuelBenefits": 24.0,
  "fuelBenefitsPts": 6,
  "fuelBenefitsToBeExpired": 10.0,
  "fuelBenefitsToBeExpiredDate": "2025-05-31T00:00:00+01:00"
}
```

---

#### POST `/api/v2/user/cardassociations/savings`

Get total savings.

**Request Body:**
```json
{
  "pmCard": "XXXXXXXXXXXXX"
}
```

**Response:**
```json
{
  "totalSaved": 162.93
}
```

---

#### GET `/api/v2/user/cardassociations/accumulator/steps`

Get accumulator steps/progress.

**Response:**
```json
{
  "steps": []
}
```

---

### 5. Shopping Lists

#### GET `/api/v2/user/shoppinglists/count`

Get number of shopping lists.

**Response:** `1` (integer)

---

#### GET `/api/v2/user/shoppinglists/activeList`

Get active shopping list.

**Response:**
```json
{
  "id": "uuid",
  "clientId": "uuid",
  "userId": "uuid",
  "name": "Nova Lista",
  "isActive": true,
  "products": [],
  "sharedWith": [
    {
      "id": "uuid",
      "canWrite": true,
      "isActive": true,
      "isOwner": true,
      "number": "+35196*****25",
      "name": "Name",
      "imageUrl": "/api/card/{loyaltyId}/photo",
      "storeId": 17,
      "dateCreated": "2024-01-28T17:01:04+00:00",
      "dateUpdated": "2025-05-29T19:59:32+00:00"
    }
  ],
  "clubs": "",
  "dateCreated": "2024-01-28T17:01:03+00:00",
  "dateUpdated": "2025-05-07T08:25:48+00:00"
}
```

---

#### PUT `/api/v2/user/shoppinglists`

Update shopping list.

**Request Body:**
```json
{
  "fullResponse": true,
  "shoppinglist": {
    "id": "uuid",
    "clientId": "uuid",
    "userId": "uuid",
    "name": "Lista Name",
    "description": "",
    "isActive": true,
    "products": [],
    "sharedWith": [...]
  }
}
```

---

### 6. Catalog & Flyers

#### POST `/api/v2/catalog/search/flyers`

Get active flyers/promotions.

**Request Body:**
```json
{
  "storeId": 17
}
```

**Response:**
```json
[
  {
    "id": 2848,
    "title": "Poupe Esta Semana",
    "image": "https://app.pingodoce.pt/images/flyers/...",
    "pdfUrl": "https://folhetos.pingodoce.pt/2025/...",
    "dateStart": "2025-05-27T00:00:00+01:00",
    "dateEnd": "2025-06-02T23:00:00+01:00",
    "description": "27 de Maio a 02 de Junho",
    "promotionId": 0,
    "promotionIds": [50011602],
    "clubs": [],
    "storeGroupId": 217,
    "allStores": false,
    "categories": [
      {
        "id": 0,
        "title": "Destaque",
        "primaryColor": "#707070",
        "secondaryColor": "#ebebeb",
        "count": 23
      }
    ]
  }
]
```

---

#### GET `/api/v2/catalog/recommendations/myflyer`

Get personalized flyer recommendations.

**Query Parameters:**
- `storeId`: Store ID

**Response:**
```json
{
  "dateStart": "2025-05-27T00:00:00+01:00",
  "dateEnd": "2025-06-02T23:59:59+01:00"
}
```

---

### 7. Gamification

#### GET `/api/v2/user/gamification/list`

Get active games/campaigns.

**Query Parameters:**
- `storeId`: Store ID

**Response:**
```json
[
  {
    "type": "ShakerGold2",
    "gameKey": "ShakerGoldSummer2025",
    "dateStart": "2025-05-05T16:00:00+00:00",
    "dateEnd": "2025-06-20T17:00:00+00:00",
    "dateEndOfRegistration": "2025-06-16T22:59:00+00:00",
    "sortOrder": 50
  },
  {
    "type": "Stamps",
    "gameKey": "FreeMeals25Mad",
    "dateStart": "2025-02-11T00:00:00+00:00",
    "dateEnd": "2025-06-30T22:59:00+00:00",
    "sortOrder": 0
  },
  {
    "type": "PoupaShaker",
    "gameKey": "PoupaShaker",
    "dateStart": "2025-01-07T00:00:00+00:00",
    "dateEnd": "2026-01-07T00:00:00+00:00",
    "sortOrder": 0
  }
]
```

---

#### GET `/api/v2/user/gamification/settings`

Get gamification visual settings (stamps, themes, banners).

---

#### GET `/api/v2/user/gamification/poupashaker/status`

Get PoupaShaker game status.

**Response:**
```json
{
  "bannerStatus": "available"
}
```

---

#### GET `/api/v2/user/gamification/shakergold/status/{gameKey}`

Get ShakerGold game status.

**Query Parameters:**
- `storeId`: Store ID
- `skipCache`: false

**Response:**
```json
{
  "bannerStatus": "unregistered"
}
```

---

### 8. Other

#### GET `/api/v2/user/themes`

Get UI themes for gamification.

---

#### GET `/api/v2/user/clubs/codes`

Get user's club memberships.

**Response:** `[]` (array of club codes)

---

#### GET `/api/v2/user/communicationBanners`

Get promotional banners.

**Query Parameters:**
- `storeId`: Store ID

---

#### PUT `/api/v2/user/pushnotifications/devicepushregistration`

Register device for push notifications.

**Request Body:**
```json
{
  "platform": "ANDROID",
  "handle": "firebase_token",
  "egoiEvents": []
}
```

---

## Image URLs

### Product Images

- **Full size:** `https://app.pingodoce.pt/images/products/fullsize/{productCode}_{unit}.{ext}`
- **Thumbnail:** `https://app.pingodoce.pt/images/products/thumbnail/{productCode}_{unit}.{ext}`

Formats: `.webp`, `.png`, `.jpg`
Units: `UN`, `KGM`, `CX`

### Brand Logos

- `https://app.pingodoce.pt/images/brands/{uuid}.png`

### Promotion Badges

- `https://app.pingodoce.pt/images/promotionBadges/{name}.webp`

---

## Notes

1. **Price format:** European format with comma as decimal separator ("2,60" = 2.60 EUR)
2. **Dates:** ISO 8601 format with timezone
3. **Authentication:** JWT Bearer token, expires in 3600 seconds
4. **Store-specific:** Many endpoints require `storeId` for localized data
5. **Missing data:** Some products don't have images (fresh produce, weighed items)
6. **Nutrition data:** Available via `/catalog/search/products` endpoint in `description` field (HTML format) for Pingo Doce branded products

---

### 9. Product Catalog Search (DISCOVERED!)

#### POST `/api/v2/catalog/search/products`

**Full product catalog search with nutrition data, ingredients, and barcode lookup.**

**Request Body:**
```json
{
  "storeId": 17,
  "page": 1,
  "size": 20,
  "text": "leite",        // Text search (optional)
  "barcode": "5601009970537",  // EAN lookup (optional)
  "categoryId": 11        // Category filter (optional)
}
```

**Key Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `storeId` | int | **Required.** Store ID |
| `page` | int | **Required for results.** Page number (starts at 1) |
| `size` | int | **Required for results.** Results per page |
| `text` | string | Text search query |
| `barcode` | string | EAN/barcode lookup |
| `categoryId` | int | Filter by category |

**Response:**
```json
{
  "totalHits": 518,
  "documents": [
    {
      "elasticID": "17_748126",
      "ean": "5601009970537",
      "productInternalCode": 748126,
      "measureUnitCode": "UN",
      "categoryId": 15,
      "name": "Doce de Morango Pingo Doce 355 g",
      "storePrice": "1,39",
      "thumb": "https://app.pingodoce.pt/images/products/thumbnail/748126_UN.webp",
      "image": "https://app.pingodoce.pt/images/products/fullsize/748126_UN.webp",
      "hasLowerPrice": false,
      "brand": {
        "id": 1,
        "ownBrand": true,
        "name": "Pingo Doce",
        "logo": "https://app.pingodoce.pt/images/brands/..."
      },
      "discountSortOrder": 10000,
      "score": 30.47,
      "matchedQueries": [],
      "description": "<html>...<b>Informações Nutricionais</b>...Ingredientes...</html>",
      "bestPromotion": { ... },
      "badges": [ ... ],
      "isNew": false
    }
  ]
}
```

**Product Document Fields:**
| Field | Type | Description |
|-------|------|-------------|
| `elasticID` | string | ElasticSearch ID "{storeId}_{code}" |
| `ean` | string | **EAN/Barcode** |
| `productInternalCode` | int | Internal product code |
| `measureUnitCode` | string | UN, KG, CX, Emb |
| `categoryId` | int | Category ID |
| `name` | string | Product name |
| `storePrice` | string | Price (European format) |
| `thumb` | string | Thumbnail URL |
| `image` | string | Full image URL |
| `brand` | object | Brand info with `ownBrand` flag |
| `description` | string | **HTML with nutrition & ingredients** |
| `score` | float | Search relevance score |
| `bestPromotion` | object | Active promotion details |
| `badges` | array | Visual badges |
| `isNew` | bool | New product flag |
| `extraBadge` | string | Special badge URL |
| `extraBadgeTitle` | string | Badge title (e.g., "Preço Garantido") |

**Description Field (HTML) Contains:**
- Marketing description
- **Informações Nutricionais** (per 100g):
  - Energia (kJ / kcal)
  - Lípidos (saturados)
  - Hidratos de carbono (açúcares)
  - Fibras
  - Proteínas
  - Sal
- **Ingredientes** list

**Example - Text Search:**
```json
{"storeId": 17, "page": 1, "size": 20, "text": "iogurte"}
```

**Example - Barcode Lookup:**
```json
{"storeId": 17, "page": 1, "size": 1, "barcode": "5601009970537"}
```

**Example - Category Browse:**
```json
{"storeId": 17, "page": 1, "size": 50, "categoryId": 11}
```

**Note:** Without `page` and `size`, returns `totalHits: 0` even if products exist.

---

## Summary of Discovered Endpoints

| Status | Endpoint | Description |
|--------|----------|-------------|
| ✅ Implemented | `POST /login` | Authentication |
| ✅ Implemented | `GET /transactionsHistory` | Transaction list |
| ✅ Implemented | `GET /transactionsHistory/details` | Transaction details |
| 🆕 Discovered | `POST /catalog/search/products` | **Product search with nutrition!** |
| 🆕 Discovered | `GET /user/userprofiles` | User profile |
| 🆕 Discovered | `GET /user/stores` | User's stores |
| 🆕 Discovered | `POST /cardassociations/benefits` | Active coupons |
| 🆕 Discovered | `POST /cardassociations/fuelbenefits` | Fuel discounts |
| 🆕 Discovered | `POST /cardassociations/savings` | Total savings |
| 🆕 Discovered | `POST /catalog/search/flyers` | Promotional flyers |
| 🆕 Discovered | `GET /shoppinglists/activeList` | Shopping list |
| 🆕 Discovered | `GET /gamification/list` | Active campaigns |

## Not Yet Discovered

Based on app functionality, these may exist:
- Recipe search/details
- Order history (online orders)
- Store search by location (public)
