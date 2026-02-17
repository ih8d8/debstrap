#! /bin/bash

# prompt
PS1='${debian_chroot:+($debian_chroot)}\[\033[01;31m\]\u\[\033[01;33m\]@\[\033[01;36m\]\h\[\033[01;31m\]:\[\033[01;33m\]\w\[\033[01;35m\]\$ \[\033[00m\]'

# don't put duplicate lines or lines starting with space in the history.
HISTCONTROL=ignoreboth

# for setting history length
HISTSIZE=999999
HISTFILESIZE=999999

# append to the history file, don't overwrite it
shopt -s histappend

# save multi-line commands in history as single line
shopt -s cmdhist

# Allows you to cd into directory merely by typing the directory name.
shopt -s autocd

# autocorrects cd misspellings
shopt -s cdspell

# update the values of LINES and COLUMNS based on window size
shopt -s checkwinsize

# if interactive shell, ignore upper and lowercase when TAB completion
if [[ $- == *i* ]]; then
    bind "set completion-ignore-case on"
fi

# aliases
export LS_OPTIONS='--color=auto'
eval "$(dircolors)"
alias ls='ls $LS_OPTIONS'
alias ll='ls $LS_OPTIONS -l'
alias l='ls $LS_OPTIONS -lA'
alias h='htop'
alias ports='netstat -tupln'
alias vd='vnstat -d'
alias dp='docker ps'
alias ds='docker stats'
alias c='sudo apt autoremove;sudo apt autoclean;sudo apt clean'
alias ipp='curl -s -4 icanhazip.com | xargs -I{} -- curl ipinfo.io/{} && echo'
alias ff='fastfetch'
alias p='ping 8.8.8.8'
alias yn='sudo apt update && sudo apt upgrade -y'
