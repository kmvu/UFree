# Source from emulator scripts. Puts a working JDK on PATH.
# macOS ships /usr/bin/java as a stub — `command -v java` is not enough.

_java_ok() {
  command -v java >/dev/null 2>&1 && java -version >/dev/null 2>&1
}

if ! _java_ok; then
  _java_root="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
  if [[ -z "${JAVA_HOME:-}" || ! -x "${JAVA_HOME}/bin/java" ]]; then
    if compgen -G "$_java_root/.jdk/jdk-*/Contents/Home" > /dev/null; then
      JAVA_HOME="$(echo "$_java_root"/.jdk/jdk-*/Contents/Home | awk '{print $1}')"
    elif compgen -G "$_java_root/.jdk/jdk-*" > /dev/null; then
      JAVA_HOME="$(echo "$_java_root"/.jdk/jdk-* | awk '{print $1}')"
    elif [[ -x /usr/libexec/java_home ]]; then
      JAVA_HOME="$(/usr/libexec/java_home -v 21 2>/dev/null || /usr/libexec/java_home 2>/dev/null || true)"
    fi
  fi
  if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/java" ]]; then
    export JAVA_HOME
    export PATH="$JAVA_HOME/bin:$PATH"
  fi
  unset _java_root
fi

if ! _java_ok; then
  cat >&2 <<'EOF'
Firebase emulators need Java 21+. macOS /usr/bin/java is a stub and does not count.

Install one of:
  brew install --cask temurin@21
  # or place a JDK under .jdk/ (gitignored)

Then re-run the same script.
EOF
  exit 1
fi
