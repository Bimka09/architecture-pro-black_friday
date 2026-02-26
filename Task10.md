## Задание 10.1

Для удобства неоходимо выделить отдельные коллекции
orders -> orders_active; orders_completed
products -> products; stock
| **Коллекция** | **Осн. операции** | **Критичность доступности** | **Критичность согласованности** | **Комментарий** |
|--|--|--|--|--|
|orders_active |1) Создание заказа; <br>2) Изменение статуса; <br>3) Получение по order_id|Высокая|Высокая|Требуется атомарность при оформлении заказа, которую Cassandra не может |
|orders_completed|1) Перевод из active; <br>2) Получение истории заказов пользователя; <br>3) Аналитические выборки;|Высокая|Средняя|Данные иммутабельны после завершения заказа. Cassandra подходит|
|products|1) Получение карточки товара; <br>2) Поиск по категории и цене | Высокая | Средняя | Высокая нагрузка на чтение, изменения происходя редко. Cassandra подходит|
|stock|1) Уменьшение остатков; <br>2) Проверка доступности по geozone| Высокая | Высокая |Требуется атомарность. Cassandra не подходит|
|carts|1) Создание; <br>2) Изменение; <br>3) Слияние; <br>2) Удаление по TTL| Высокая | Cредняя |Высокая нагрузка на запись. Допустима временная несогалсованность. Cassandra подходит|

Резюме: создающие нагрузку на запись, участвующие в массовых перемещениях, вынесем в Cassandra. Сущности, требующие атомарности, оставим в MongoDb.

## Задание 10.2

#### Orders_completed

```cql
CREATE TABLE orders_completed_by_id (
    order_id uuid,
    user_id uuid,
    completed_at timestamp,
    total_amount decimal,
    geozone text,
    items list<frozen<order_item>>,
    PRIMARY KEY (order_id)
);
```

```cql
CREATE TABLE orders_completed_by_user (
    user_id uuid,
    bucket text,
    completed_at timestamp,
    order_id uuid,
    total_amount decimal,
    PRIMARY KEY ((user_id, bucket), completed_at, order_id)
) WITH CLUSTERING ORDER BY (completed_at DESC);
```

#### Products

```cql
CREATE TABLE products_by_id (
    product_id uuid,
    name text,
    category text,
    price decimal,
    attributes map<text, text>,
    PRIMARY KEY (product_id)
);
```
```cql
CREATE TABLE products_by_category (
    category text,
    bucket int,
    price decimal,
    product_id uuid,
    name text,
    PRIMARY KEY ((category, bucket), price, product_id)
);
```


#### Carts

```cql
CREATE TABLE carts_by_id (
    cart_id uuid,
    user_id uuid,
    session_id text,
    updated_at timestamp,
    status text,
    items map<uuid, int>,
    PRIMARY KEY (cart_id)
) WITH default_time_to_live = 604800;
```

## Задание 10.3
| **Коллекция** | **Cтратегия** | **Уровень согласованность** | **Обоснование** |
|--|--|--|--|
|orders_completed |Hinted Handoff + Anti-Entropy Repair по расписанию|WRITE: QUORUM, READ: QUORUM| Финансово значимые иммутабельные данные. Требуется гарантия отсутствия потери записи. Hinted Handoff защищает от кратковременного падения ноды, Anti-Entropy Repair устраняет долгосрочные расхождения. QUORUM обеспечивает strong consistency (R+W > RF). |
|products|Hinted Handoff + Anti-Entropy Repair по расписанию|WRITE: QUORUM, READ: ONE| Каталог read-heavy. Допустима временная рассинхронизация, приоритет — минимальная latency чтения. Hinted Handoff защищает от кратковременного падения ноды. Anti-Entropy выполняется реже, чем для заказов.|
|carts|Read Repair|WRITE: QUORUM, READ: QUORUM| Несмотря недолговечность данных, корзина участвует в пользовательской сессии и требует согласованности. Использование QUORUM гарантирует, что добавленный товар будет виден при последующем чтении. Read Repair устраняет расхождения при чтении. |