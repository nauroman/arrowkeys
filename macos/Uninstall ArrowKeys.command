#!/bin/bash
set -euo pipefail
support='/Library/Application Support/ArrowKeys'
if [[ $# == 0 ]]; then
  echo 'Remove ArrowKeys and its rules for this account? Other Karabiner rules and the shared keyboard driver will stay installed.'
  read -r -p 'Type yes to continue: ' answer
  [[ "$answer" == yes ]] || exit 0
elif [[ "$1" != --yes ]]; then
  exit 2
fi
/bin/bash "$support/Enable ArrowKeys.command" --remove-rule
sudo /bin/rm -f "$support/arrowkeys.json" "$support/configure.js" "$support/Enable ArrowKeys.command" "$support/LICENSE" '/Applications/Uninstall ArrowKeys.command'
sudo /bin/rmdir "$support" 2>/dev/null || true
sudo /usr/sbin/pkgutil --forget com.nauroman.arrowkeys.profile
echo 'ArrowKeys removed. To remove Karabiner and its driver too, use its Settings → Uninstall.'
