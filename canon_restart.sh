#!/bin/bash

[ $USER != 'root' ] && exec sudo "$0"

LOGIN_USER=$(logname)
[ -z "$LOGIN_USER" ] && LOGIN_USER=$(who | head -1 | awk '{print $1}')

echo 'Остановка captstatusui'
killall captstatusui 2> /dev/null
echo 'Остановка ccpd'
service ccpd stop
echo 'Перезапуск cups и ccpd'
service cups restart
echo 'Запуск captstatusui'
while true
do
	sleep 1
	set -- $(pidof /usr/sbin/ccpd)
	if [ -n "$1" -a -n "$2" ]; then
		sudo -u $LOGIN_USER nohup captstatusui -P $(ccpdadmin | grep LBP | awk '{print $3}') > /dev/null 2>&1 &
		sleep 2
		break
	fi
done
echo
echo 'Если принтер не будет печатать, перегрузите компьютер'
echo 'Нажмите любую клавишу для выхода'
echo -ne "Автоматический выход через    секунд(у,ы)\e[14D"
sec=30
while [ $sec -ne 0 ]
do
	len=$(( ${#sec} + 1 ))
	echo -ne "$sec \e[${len}D"
	sec=$(( $sec - 1 ))
	read -s -n1 -t1 && break
done
