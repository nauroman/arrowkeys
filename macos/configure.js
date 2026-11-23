// Invoked by macOS osascript. Send the merged profile to stdout.
ObjC.import('Foundation')

function readJSON(path) {
  const string = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null)
  if (!string || string.isNil()) throw new Error('Cannot read ' + path)
  return JSON.parse(ObjC.unwrap(string))
}

function run([configPath, assetPath, mode]) {
  const config = readJSON(configPath)
  const rule = readJSON(assetPath).rules[0]
  if (mode === '--remove-rule') {
    let changed = false
    for (const profile of config.profiles) {
      const section = profile.complex_modifications
      if (!section || !Array.isArray(section.rules)) continue
      const retained = section.rules.filter(item => item.description !== rule.description)
      if (retained.length !== section.rules.length) {
        section.rules = retained
        changed = true
      }
    }
    return changed ? JSON.stringify(config, null, 2) : 'unchanged'
  }
  const selected = config.profiles.filter(profile => profile.selected === true)
  if (selected.length !== 1) throw new Error('Select a profile in Karabiner-Elements first.')
  const profile = selected[0]
  if (profile.complex_modifications === undefined) profile.complex_modifications = {}
  const section = profile.complex_modifications
  if (section.rules === undefined) section.rules = []
  if (!Array.isArray(section.rules)) throw new Error('Unrecognized profile rules.')
  const matches = section.rules.filter(item => item.description === rule.description)
  if (matches.length === 1 && JSON.stringify(matches[0]) === JSON.stringify(rule)) return 'unchanged'
  section.rules = [rule].concat(section.rules.filter(item => item.description !== rule.description))
  return JSON.stringify(config, null, 2)
}
