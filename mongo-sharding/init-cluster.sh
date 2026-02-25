#!/usr/bin/env bash
set -e

echo "Starting containers..."
docker compose up -d

echo "Waiting for MongoDB to start..."
sleep 8

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

echo "Init config server..."
init_rs configSrv1 '{
  _id: "config_server",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv1:27017" }
  ]
}'

echo "Init shard1..."
init_rs shard1-1 '{
  _id: "shard1",
  members: [
    { _id: 0, host: "shard1-1:27017" }
  ]
}'

echo "Init shard2..."
init_rs shard2-1 '{
  _id: "shard2",
  members: [
    { _id: 0, host: "shard2-1:27017" }
  ]
}'

echo "Waiting for PRIMARY election..."
sleep 8

echo "Configuring sharding..."

docker compose exec -T mongos_router1 mongosh --quiet --eval '

try { sh.addShard("shard1/shard1-1:27017") } catch(e) {}
try { sh.addShard("shard2/shard2-1:27017") } catch(e) {}

sh.enableSharding("somedb")

db = db.getSiblingDB("somedb")

try { db.createCollection("helloDoc") } catch(e) {}

try { sh.shardCollection("somedb.helloDoc", { _id: "hashed" }) } catch(e) {}

for (let i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({ age: i, name: "ly" + i })
}

printjson(db.helloDoc.getShardDistribution())
'

echo "Cluster initialized successfully."