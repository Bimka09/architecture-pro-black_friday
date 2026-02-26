#!/usr/bin/env bash
set -e

echo "Starting containers..."
docker compose up -d

echo "Waiting for Mongo containers to be ready..."
sleep 10

init_rs () {
  SERVICE=$1
  CONFIG=$2

  echo "Initializing replica set on $SERVICE..."

  docker compose exec -T $SERVICE mongosh --quiet --eval "
    try {
      rs.status()
    } catch(e) {
      rs.initiate($CONFIG)
    }
  "
}

echo "Init config server replica set..."
init_rs configSrv1 '{
  _id: "config_server",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv1:27017" },
    { _id: 1, host: "configSrv2:27017" },
    { _id: 2, host: "configSrv3:27017" }
  ]
}'

echo "Init shard1..."
init_rs shard1-1 '{
  _id: "shard1",
  members: [
    { _id: 0, host: "shard1-1:27017" },
    { _id: 1, host: "shard1-2:27017" },
    { _id: 2, host: "shard1-3:27017" }
  ]
}'

echo "Init shard2..."
init_rs shard2-1 '{
  _id: "shard2",
  members: [
    { _id: 0, host: "shard2-1:27017" },
    { _id: 1, host: "shard2-2:27017" },
    { _id: 2, host: "shard2-3:27017" }
  ]
}'

echo "Init shard3..."
init_rs shard3-1 '{
  _id: "shard3",
  members: [
    { _id: 0, host: "shard3-1:27017" },
    { _id: 1, host: "shard3-2:27017" },
    { _id: 2, host: "shard3-3:27017" }
  ]
}'

echo "Waiting for replica sets to elect PRIMARY..."
sleep 15

echo "Adding shards to mongos..."

docker compose exec -T mongos_router1 mongosh --quiet --eval '
try { sh.addShard("shard1/shard1-1:27017,shard1-2:27017,shard1-3:27017") } catch(e) {}
try { sh.addShard("shard2/shard2-1:27017,shard2-2:27017,shard2-3:27017") } catch(e) {}
try { sh.addShard("shard3/shard3-1:27017,shard3-2:27017,shard3-3:27017") } catch(e) {}

sh.enableSharding("somedb")

db = db.getSiblingDB("somedb")
db.createCollection("helloDoc")

sh.shardCollection("somedb.helloDoc", { _id: "hashed" })

for (let i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({ age: i, name: "ly" + i })
}

printjson(db.helloDoc.getShardDistribution())
'

echo "Mongo cluster initialized successfully."