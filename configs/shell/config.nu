# ALIE Nushell Configuration
$env.config = {
  show_banner: false
  edit_mode: emacs
  shell_integration: true
  history: {
    max_size: 10000
    sync_on_enter: true
    file_format: "plaintext"
  }
  completions: {
    algorithm: "fuzzy"
    case_sensitive: false
    quick: true
    partial: true
    external: {
      enable: true
      max_results: 100
      completer: null
    }
  }
  filesize: {
    metric: true
    format: "auto"
  }
  table: {
    mode: rounded
    index_mode: always
    show_empty: true
    padding: { left: 1, right: 1 }
    trim: {
      methodology: wrapping
      wrapping_try_keep_words: true
      truncating_suffix: "..."
    }
    header_on_separator: false
  }
  prompt: "# "
  menus: []
}

# Useful aliases for common commands
alias ll = ls -l
alias la = ls -a
alias lla = ls -la
alias .. = cd ..
alias ... = cd ../..
alias grep = grep --color=auto
alias df = df -h
alias free = free -h
alias ps = ps aux
alias top = htop

# Add local bin to PATH
$env.PATH = ($env.PATH | split row (char esep) | prepend $"($env.HOME)/.local/bin")

# Set default editor
$env.EDITOR = "nano"
$env.VISUAL = "nano"

# Custom prompt with colors
$env.PROMPT_COMMAND = {|| $"($env.USERNAME)@($env.HOSTNAME):($env.PWD | path basename)# " }
$env.PROMPT_COMMAND_RIGHT = {|| "" }

# Enable starship prompt if available
if (which starship | is-not-empty) {
  starship init nu | save ~/.cache/starship.nu
  source ~/.cache/starship.nu
}