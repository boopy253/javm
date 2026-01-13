# JAVM

## Installation

```bash
git clone https://github.com/boopy253/javm.git "$HOME/.javm"
```

## Git Bash

Add to `~/.bashrc` or `~/.bash_profile`

```bash
[[ -f "$HOME/.javm/javm.sh" ]] && source "$HOME/.javm/javm.sh"
```

## Usage

```bash
javm add jdk8  ~/.jdks/jdk8
javm add jdk21 ~/.jdks/jdk21
javm default jdk21      # Set as global default
javm list
java -version
```
