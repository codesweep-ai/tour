# Installing tour

`make setup` fetches every codesweep tool at the version this repository pins. Before you run it,
install Go and Node. Steps 5 to 7 also need podman and `/dev/kvm`, on Linux.

Once these are in place, go back to the [README](README.md).

## 1. Go

Install Go 1.27.1:

```bash
curl -LO https://go.dev/dl/go1.27.1.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.27.1.linux-amd64.tar.gz
export PATH="/usr/local/go/bin:$PATH"          # add to ~/.bashrc to persist
go version
```

On macOS, or on another architecture, take the matching download from [go.dev](https://go.dev/dl/).

## 2. Node

Install Node 24.21.0, with npm, from [nodejs.org](https://nodejs.org/en/download). Then
check it:

```bash
node --version
```

## 3. Podman

Steps 5 to 7 need podman 5.0 or later, with the OpenSSH client and git:

```bash
sudo dnf install podman openssh-clients git    # Fedora
sudo apt install podman openssh-client git     # Ubuntu, Debian
podman --version
```

## 4. /dev/kvm for Firecracker

Steps 5 to 7 boot Firecracker virtual machines, which need Linux on x86_64 with KVM. Give your user
access to `/dev/kvm`, then log out and back in:

```bash
sudo usermod -aG kvm "$USER"
```

Firecracker also needs a few host packages, which the
[sandbox installation guide](https://github.com/codesweep-ai/sandbox/blob/main/INSTALL.md#firecracker-packages-linux--kvm-x86_64)
lists.

## 5. Verify the installation

```bash
make setup
scripts/cs cs-sandbox doctor
```

For steps 5 to 7, the `doctor` lines about podman and KVM must say `ok`. A `NO` line names its fix.
