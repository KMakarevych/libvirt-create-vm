# libvirt-create-vm

Скрипт для швидкого створення віртуальних машин Ubuntu та Oracle Linux на базі libvirt/QEMU з автоматичним налаштуванням через cloud-init.

## Можливості

- Підтримка Ubuntu 24.04 (Noble) та Oracle Linux 7/8/9
- Автоматичне завантаження Cloud Image для обраної ОС
- Налаштування користувача з SSH-ключем та паролем
- Автоматична установка Docker
- Налаштування QEMU Guest Agent для отримання IP-адреси
- Режим знищення VM з видаленням диска
- Генерація випадкового пароля

## Вимоги

- Linux з підтримкою KVM
- libvirt, QEMU, virt-install
- Bridge-інтерфейс `br0` (або змініть у скрипті)
- `whois` (для `mkpasswd`, якщо використовуєте `--genpass`)

```bash
sudo apt install qemu-kvm libvirt-daemon-system virtinst bridge-utils whois
```

## Використання

### Локально (клонування репозиторію)

```bash
# Клонувати репозиторій
git clone https://github.com/KMakarevych/libvirt-create-vm.git
cd libvirt-create-vm

# Зробити скрипт виконуваним
chmod +x script.sh

# Створити Ubuntu VM з назвою "node-01" та користувачем "admin"
./script.sh --vmname node-01 --user admin

# Створити Oracle Linux 9 VM
./script.sh --vmname node-01 --user admin --os-family ol9

# Створити Oracle Linux 8 VM
./script.sh --vmname node-01 --user admin --os-family ol8

# Створити VM з генерацією нового пароля
./script.sh --vmname node-01 --user admin --genpass

# Знищити VM та видалити диск
./script.sh --vmname node-01 --destroy
```

### Віддалено (через curl | bash)

```bash
# Створити VM з параметрами за замовчуванням
curl -fsSL https://raw.githubusercontent.com/KMakarevych/libvirt-create-vm/main/script.sh | bash

# Створити Ubuntu VM з власними параметрами
curl -fsSL https://raw.githubusercontent.com/KMakarevych/libvirt-create-vm/main/script.sh | bash -s -- --vmname node-01 --user admin

# Створити Oracle Linux 9 VM
curl -fsSL https://raw.githubusercontent.com/KMakarevych/libvirt-create-vm/main/script.sh | bash -s -- --vmname node-01 --user admin --os-family ol9

# Створити Oracle Linux 8 VM
curl -fsSL https://raw.githubusercontent.com/KMakarevych/libvirt-create-vm/main/script.sh | bash -s -- --vmname node-01 --user admin --os-family ol8

# Створити VM з генерацією пароля
curl -fsSL https://raw.githubusercontent.com/KMakarevych/libvirt-create-vm/main/script.sh | bash -s -- --vmname node-01 --user admin --genpass

# Знищити VM
curl -fsSL https://raw.githubusercontent.com/KMakarevych/libvirt-create-vm/main/script.sh | bash -s -- --vmname node-01 --destroy
```

## Параметри

| Параметр | Опис | За замовчуванням |
|----------|------|------------------|
| `--vmname NAME` | Назва віртуальної машини | `vm` |
| `--user USERNAME` | Ім'я sudo-користувача у VM | поточний користувач |
| `--os-family FAMILY` | Сімейство ОС: `deb` (Ubuntu 24.04), `ol7`, `ol8`, `ol9` (Oracle Linux) | `deb` |
| `--destroy` | Знищити VM та видалити диск | - |
| `--genpass` | Згенерувати випадковий пароль | - |
| `-h, --help` | Показати довідку | - |

## Конфігурація за замовчуванням

Ці значення можна змінити безпосередньо у скрипті:

| Параметр | Значення |
|----------|----------|
| Диск | 50 GB (RAW) |
| RAM | 8192 MB |
| vCPU | 8 |
| Bridge | br0 |
| ОС | Ubuntu 24.04 (Noble) / Oracle Linux 7, 8, 9 |

## Приклади

```bash
# Створити dev-сервер
./script.sh --vmname dev-server --user developer --genpass

# Створити кілька нод
for i in {1..3}; do
  ./script.sh --vmname node-$i --user admin
done

# Очистити всі ноди
for i in {1..3}; do
  ./script.sh --vmname node-$i --destroy
done
```

## Примітки

- Скрипт автоматично встановлює Docker у VM
- SSH-ключ та хеш пароля захардкоджені у скрипті — замініть їх на свої перед використанням
- Диск зберігається у `/var/lib/libvirt/images/`
- Base image кешується для повторного використання

## Claude Code Skill

Репозиторій містить skill для [Claude Code](https://claude.ai/code), що дозволяє керувати VM через природну мову.

### Що вміє skill

- Створювати та знищувати VM за запитом
- Автоматично керувати SSH-псевдонімами у `~/.ssh/config.d/`
- Показувати IP-адресу та готову SSH-команду після створення

### Встановлення

Скопіюйте skill до свого проєкту (або до `.claude/skills/` у будь-якому робочому каталозі):

```bash
# Клонувати репозиторій
git clone https://github.com/KMakarevych/libvirt-create-vm.git

# Скопіювати skill до свого проєкту
cp -r libvirt-create-vm/.claude/skills/libvirt-vm /your-project/.claude/skills/

# Або використовувати репозиторій напряму як робочий каталог Claude Code
cd libvirt-create-vm
claude
```

### Використання

Після встановлення skill активується автоматично, коли Claude Code визначає намір керувати VM. Можна також викликати явно:

```
/libvirt-vm
```

**Приклади запитів:**

```
Створи VM node-01 з користувачем admin
Знищ VM node-01
Покажи список VM
```

Claude Code виконає скрипт, дочекається IP-адреси та оновить SSH-конфіг автоматично.

## Ліцензія

MIT
