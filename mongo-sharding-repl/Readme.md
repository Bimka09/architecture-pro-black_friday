Readme

run ./init-cluster.sh 

or 

docker compose up -d
docker compose exec -it configSrv1 mongosh

```js
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv1:27017" },
    { _id: 1, host: "configSrv2:27017" },
    { _id: 2, host: "configSrv3:27017" }
  ]
})
```

docker compose exec -it shard1-1 mongosh

```js
rs.initiate({
  _id: "shard1",
  members: [
    { _id: 0, host: "shard1-1:27017" },
    { _id: 1, host: "shard1-2:27017" },
    { _id: 2, host: "shard1-3:27017" }
  ]
})
```

docker compose exec -it shard2-1 mongosh

```js
rs.initiate({
  _id: "shard2",
  members: [
    { _id: 0, host: "shard2-1:27017" },
    { _id: 1, host: "shard2-2:27017" },
    { _id: 2, host: "shard2-3:27017" }
  ]
})
```

docker compose exec -it shard3-1 mongosh

```js
rs.initiate({
  _id: "shard3",
  members: [
    { _id: 0, host: "shard3-1:27017" },
    { _id: 1, host: "shard3-2:27017" },
    { _id: 2, host: "shard3-3:27017" }
  ]
})
```

docker compose exec -it mongos_router1 mongosh

```js
sh.addShard("shard1/shard1-1:27017,shard1-2:27017,shard1-3:27017")
sh.addShard("shard2/shard2-1:27017,shard2-2:27017,shard2-3:27017")
sh.addShard("shard3/shard3-1:27017,shard3-2:27017,shard3-3:27017")
```

sh.status()

use somedb

db.createCollection("helloDoc")

sh.shardCollection("somedb.helloDoc", { _id: "hashed" })
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
db.helloDoc.getShardDistribution()