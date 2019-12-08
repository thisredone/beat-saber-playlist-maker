
Object.assign global,
  log: console.log.bind(console)

  after: (ms) -> new Promise (resolve) -> setTimeout(resolve, ms)
