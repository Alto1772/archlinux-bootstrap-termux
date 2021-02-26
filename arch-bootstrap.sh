#!/data/data/com.termux/files/usr/bin/sh

set -u
umask 022

REPONAME=Alto1772/archlinux-bootstrap-termux
ROOTFS="${ROOTFS:-arch-rootfs}"
PACMAN_STATIC="https://github.com/${REPONAME}/raw/main/pacman-static"
CACHEDIR="${CACHEDIR:-${HOME}/.cache/pacman-pkg}"

[ -e "$ROOTFS" ] && echo "$ROOTFS" exists, please remove it... && exit 1

mkdir -p "${ROOTFS}/var/lib/pacman"
mkdir -p "${ROOTFS}/var/cache/pacman/pkg"
mkdir -p "$CACHEDIR"

set -e
pkg install proot

[ ! -e pacman-static ] && wget -O pacman-static "$PACMAN_STATIC"

[ ! -e pacman.conf ] && cat > pacman.conf << 'CONF'
# temporary pacman.conf file for
# bootstrapping filesystem and pacman

[options]
Architecture = auto
CheckSpace

# core first
[core]
SigLevel = Never
Server = http://mirror.archlinuxarm.org/$arch/core
CONF

[ ! -e resolv.conf ] && cat > resolv.conf << 'CONF'
# google public dns
nameserver 8.8.8.8
nameserver 8.8.4.4
CONF

unset LD_PRELOAD
proot --link2symlink -0 \
    -b resolv.conf:/etc/resolv.conf \
    -b /proc/self/mounts:/etc/mtab \
    ./pacman-static --config pacman.conf --cachedir "$CACHEDIR" \
    --root "$ROOTFS" -Sy --noconfirm --asdeps filesystem

cp resolv.conf "${ROOTFS}/etc/resolv.conf"
proot --link2symlink -0 -r "$ROOTFS" \
    -b /dev -b /proc -b /sys \
    -b /system -b /apex -b /data/data/com.termux/files \
    -b "$CACHEDIR":/var/cache/pacman/pkg \
    env PATH=/bin:/usr/bin:/sbin:/usr/sbin:$PREFIX/bin \
    ./pacman-static --config pacman.conf -Sy --noconfirm --asdeps pacman gawk

cat > startarch << SHELL
#!/data/data/com.termux/files/usr/bin/sh
unset LD_PRELOAD
ROOTFS="$ROOTFS"

BINDS="/dev/ /sys/ /proc/ /sdcard /storage /data/data/com.termux/files /apex /system $CACHEDIR:/var/cache/pacman/pkg \${BINDS}"
ADDFLAGS="--link2symlink -0 --kill-on-exit -w /root"

N=-i
if [ "\$1" = -n ]; then
    unset N
    shift
fi

if [ "\$1" ]; then
    exec proot -r "\$ROOTFS" \$ADDFLAGS \\
	    \$(for i in \$BINDS; do echo -b "\$i"; done) \\
        /usr/bin/env \$N HOME=/root TERM="\$TERM" LANG=\$LANG PATH=/bin:/usr/bin:/sbin:/usr/sbin "\$@"
else
    exec proot -r "\$ROOTFS" \$ADDFLAGS \\
    	\$(for i in \$BINDS; do echo -b "\$i"; done) \\
	    /usr/bin/env \$N HOME=/root TERM="\$TERM" LANG=\$LANG PATH=/bin:/usr/bin:/sbin:/usr/sbin \
    	/bin/bash --login
fi
SHELL

chmod +x startarch

./startarch pacman-key --init
./startarch pacman-key --populate archlinuxarm

./startarch pacman -Sy --noconfirm base

rm -f pacman.conf resolv.conf
