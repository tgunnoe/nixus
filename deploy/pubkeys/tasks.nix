{ pkgs }:
let
  program = pkgs.cmatrix;
in
map (x: "restrict,pty  ${x}") [
"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDLJV7dVWtrSUOV/N3/2lgn3QIjIFVtKBCJE6bQjAWCB tgunnoe@gnu.lv"

]