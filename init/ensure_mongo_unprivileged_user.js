// Place this file in `/docker-entrypoint-initdb.d` of the container running the primary mongodb instance
// This will ensure the creation of a non-admin user within the demo replicaset

const members = [
  "infra-dev-001.mongodb.tournabyte.com:27017",
  "infra-dev-002.mongodb.tournabyte.com:27017",
  "infra-dev-003.mongodb.tournabyte.com:27017"
]
const rsName = "infra-dev"

const authDb = "admin"
const unprivilegedUser = fs.readFileSync("/run/secrets/mongodb_app_user", "utf8").trim()
const unprivilegedPass = fs.readFileSync("/run/secrets/mongodb_app_pass", "utf8").trim()
const unprivilegedRoles = [{ role: "readWrite", db: "tournabyte" }]

const run = () => {
  const database = db.getSiblingDB(authDb)
  print(`Checking if user '${unprivilegedUser}' exists in the '${authDb} database'`)
  const user = database.getUser(unprivilegedUser)

  if (user) {
    print(`User '${unprivilegedUser}' already exists. No action needed!`)
  } else {
    print(`User '${unprivilegedUser}' does not exist. Creating user...`)
    try {
      database.createUser({
        user: unprivilegedUser,
        pwd: unprivilegedPass,
        roles: unprivilegedRoles
      })
      print(`User '${unprivilegedUser}' successfully created`)
    } catch (e) {
      print(`Failed to create user '${unprivilegedUser}': ${e}`)
      quit(1)
    }
  }
}
run()
