
Object.assign global,
  log: console.log.bind(console)

  after: (ms) -> new Promise (resolve) -> setTimeout(resolve, ms)


Array::last = ->
  @[@length - 1]
