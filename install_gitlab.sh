#!/bin/bash

# Skrypt instalujący GitLab i niezbędne komponenty
# Działa na: Ubuntu 22, Ubuntu 24, Rocky Linux 8/9, AlmaLinux 8/9

set -e

# Funkcja do generowania losowego ciągu znaków
generate_random_password() {
    local LENGTH=$1
    tr -dc 'A-Za-z0-9!@#$%^&*()_+=' </dev/urandom | head -c $LENGTH
}

# Wykrywanie systemu operacyjnego
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=${VERSION_ID%%.*}
else
    echo "Nie można wykryć systemu operacyjnego."
    echo "Obsługiwane systemy to: Ubuntu 22, Ubuntu 24, Rocky Linux 8/9, AlmaLinux 8/9."
    exit 1
fi

# Inicjalizacja zmiennych
GITLAB_ROOT_PASSWORD=$(generate_random_password 16)
EXTERNAL_URL="http://$(hostname -I | awk '{print $1}')"

if [[ "$OS" == "ubuntu" ]]; then
    echo "Instalacja na Ubuntu $VERSION_ID"

    # Sprawdzenie wersji Ubuntu
    if [[ "$VER" != "22" && "$VER" != "24" ]]; then
        echo "Obsługiwane wersje Ubuntu to 22 i 24."
        echo "Twoja wersja to $VERSION_ID."
        exit 1
    fi

    # Aktualizacja systemu
    sudo apt update && sudo apt upgrade -y

    # Instalacja zależności
    sudo apt install -y curl openssh-server ca-certificates tzdata perl

    # Dodanie repozytorium GitLab
    curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash

    # Instalacja GitLab CE (Community Edition) jako wersja bezpłatna
    sudo EXTERNAL_URL="$EXTERNAL_URL" apt install -y gitlab-ce

elif [[ "$OS" == "rocky" || "$OS" == "almalinux" ]]; then
    echo "Instalacja na $PRETTY_NAME"

    # Sprawdzenie wersji Rocky Linux lub AlmaLinux
    if [[ "$VER" != "8" && "$VER" != "9" ]]; then
        echo "Obsługiwane wersje dla $OS to 8 i 9."
        echo "Twoja wersja to $VERSION_ID."
        exit 1
    fi

    # Aktualizacja systemu
    sudo dnf update -y

    # Instalacja zależności
    sudo dnf install -y curl policycoreutils-python-utils openssh-server perl

    # Konfiguracja SSH
    sudo systemctl enable sshd
    sudo systemctl start sshd

    # Otwieranie portów w firewallu
    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --permanent --add-service=https
    sudo firewall-cmd --reload

    # Dodanie repozytorium GitLab
    curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | sudo bash

    # Instalacja GitLab CE (Community Edition) jako wersja bezpłatna
    sudo EXTERNAL_URL="$EXTERNAL_URL" dnf install -y gitlab-ce

else
    echo "Nieobsługiwany system operacyjny: $OS $VERSION_ID"
    echo "Obsługiwane systemy to: Ubuntu 22, Ubuntu 24, Rocky Linux 8/9, AlmaLinux 8/9."
    exit 1
fi

# Ustawienie hasła root dla GitLab
sudo gitlab-rails runner "user = User.where(id: 1).first; user.password = '$GITLAB_ROOT_PASSWORD'; user.password_confirmation = '$GITLAB_ROOT_PASSWORD'; user.save!"

# Restart usług GitLab
sudo gitlab-ctl reconfigure
sudo gitlab-ctl restart

# Wyświetlenie listy loginów i haseł
echo "Instalacja zakończona pomyślnie."
echo "Dane dostępowe:"
echo "GitLab - URL: $EXTERNAL_URL"
echo "GitLab - Użytkownik administracyjny: root"
echo "GitLab - Hasło administratora: $GITLAB_ROOT_PASSWORD"
