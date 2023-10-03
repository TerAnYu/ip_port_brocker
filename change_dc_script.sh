#!/bin/bash

# This comment and code TerAnYu, selectable license under the GPL2.0 or later
# or CC-SA 4.0 (CreativeCommons Share Alike) or # later. (c) 2008. All rights
# reserved. No warranty of any kind. You have been warned.
# http://www.gnu.org/licenses/gpl-2.0.txt
# https://creativecommons.org/licenses/by-sa/4.0/

# https://unix.stackexchange.com/questions/217284/not-all-shell-scripts-working-with-crontab
set PATH=/usr/sbin:/sbin:/usr/bin:/bin
source "$(dirname $0)/change_dc_conf.sh"

# создание TEMPFS для локфайла
if [ ! -d "${tmpdir}" ]; then
    echo "Путь ${tmpdir} не существует, создаю."
    mkdir ${tmpdir}
    chmod 777 ${tmpdir}
    mount -t tmpfs -o size=5M tmpfs ${tmpdir}
fi

######################################
# https://devidiom.blog/2015/12/03/simple-bash-server-check-script/
controllers=("$contr1" "$contr2" "$contr3" "$contr4")
# проверка доступности порта
for controller in "${controllers[@]}"; do
    if `nc -z -w 5 "${controller}" "${CPORT}"`; then
        eths="${controller}"
        echo "Доступен адрес: ${controller}"
        break
    fi
done

if [ -z "$eths" ]; then
    echo "Всё пропало! Все контроллеры недоступны!"
    rm -f "${tmpdir}"/*.lpta
    exit 0
fi
######################################

# Создаём файл при переключении и если этот файл соответствует установленному адресу, то ничего не делаем, иначе переключаем на новый адрес и блокируем его
if [ -f "${tmpdir}/${eths}.lpta" ]; then
    echo "Адрес ${eths} уже указан"
    echo ----------
else
    rm -f ${tmpdir}/*.lpta
    echo "Указываем адрес ${eths}"
    "${biniptables}" -t nat -v -L OUTPUT -n --line-number | tac | grep -w "${comment}" | awk '{system("'"${biniptables}"' -t nat -D OUTPUT " $1)}'
    "${biniptables}" -t nat -A OUTPUT -m addrtype --src-type LOCAL --dst-type LOCAL -p tcp -m multiport --dport ${PORTSS} -j DNAT --to-destination ${eths} -m comment --comment "${comment}"
    "${biniptables}" -t nat -A OUTPUT -m addrtype --src-type LOCAL --dst-type LOCAL -p udp -m multiport --dport ${PORTSS} -j DNAT --to-destination ${eths} -m comment --comment "${comment}"

    touch ${tmpdir}/${eths}.lpta
fi

# Проверяем на наличие маскарада, если есть, то ничего не делаем, если нет, удаляем если есть и прописываем снова
if [ -n "`"${biniptables}" -t nat -v -L POSTROUTING -n --line-number | grep -w ${comment}`" ]
then
    echo
else
# https://serverfault.com/questions/247623/iptables-redirect-local-connections-to-remote-system-port
# (which works only in kernels >= 3.6)
# https://superuser.com/questions/661772/iptables-redirect-to-localhost
    "${binsysctl}" -w net.ipv4.conf.all.route_localnet=1
    "${binsysctl}" -w net.ipv4.ip_forward=1
    "${biniptables}" -t nat -v -L POSTROUTING -n --line-number | tac | grep -w "${comment}" | awk '{system("'"${biniptables}"' -t nat -D OUTPUT " $1)}'
    "${biniptables}" -t nat -A POSTROUTING -m addrtype --src-type LOCAL --dst-type UNICAST -j MASQUERADE -m comment --comment "${comment}"
    echo ----------
fi

exit 0
