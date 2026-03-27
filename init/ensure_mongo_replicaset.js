// Place this file in `/docker-entrypoint-initdb.d` of the container running the primary mongodb instance
// This will ensure the creation of the demo replicaset for application transaction purposes

const members = [
  "infra-dev-001.mongodb.tournabyte.com:27017",
  "infra-dev-002.mongodb.tournabyte.com:27017",
  "infra-dev-003.mongodb.tournabyte.com:27017"
]
const rsName = "infra-dev"
const primary = members[0]

const rsConfig = {
  _id: rsName,
  members: [
    { _id: 0, host: members[0] },
    { _id: 1, host: members[1] },
    { _id: 2, host: members[2] },
  ]
}

print("Waiting for replica set members to be ready...")
const run = () => {
  print("Checking the replica set status...")
  let status;
  try {
    status = rs.status()
  } catch (e) {
    status = null
  }

  if (status && status.ok === 1) {
    print("Replica set already initialized. Skipping initialization!")
  } else {
    print("Initializing replica set...")
    try {
      rs.initiate(rsConfig)
    } catch (e) {
      print(`Failed to initiate replica set: ${e}`)
      quit(1)
    }
    print(rs.status())
  }
}
run()
