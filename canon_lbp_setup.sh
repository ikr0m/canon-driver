#!/bin/bash

##################################################
#версия 3.2 от 11 августа 2017 года
#http://help.ubuntu.ru/wiki/canon_capt
#http://forum.ubuntu.ru/index.php?topic=189049.0
##################################################

#проверка на суперпользователя
[ $USER != 'root' ] && exec sudo "$0"

#пользователь под которым мы вошли в ситему
LOGIN_USER=$(logname)
[ -z "$LOGIN_USER" ] && LOGIN_USER=$(who | head -1 | awk '{print $1}')

#подгружаем файл содержащий путь до рабочего стола
if [ -f ~/.config/user-dirs.dirs ]; then 
	source ~/.config/user-dirs.dirs
else
	XDG_DESKTOP_DIR="$HOME/Рабочий стол"
fi

#версия драйвера
DRIVER_VERSION='2.71-1'
DRIVER_VERSION_COMMON='3.21-1'

#ссылки на пакеты драйвера
declare -A URL_DRIVER=([amd64_common]='https://drive.google.com/uc?export=download&confirm=no_antivirus&id=0Byemcyi98JRjcXE1YWE0VjVDalE' \
[amd64_capt]='https://drive.google.com/uc?export=download&confirm=no_antivirus&id=0Byemcyi98JRjaWM2QzhVWF9MRGM' \
[i386_common]='https://drive.google.com/uc?export=download&confirm=no_antivirus&id=0Byemcyi98JRjeEs5UG9ZdTNBaXc' \
[i386_capt]='https://drive.google.com/uc?export=download&confirm=no_antivirus&id=0Byemcyi98JRjcWRrQ2dKZ1JyTUU')

#ссылки на утилиту autoshutdowntool
declare -A URL_ASDT=([amd64]='https://drive.google.com/uc?export=download&confirm=no_antivirus&id=0Byemcyi98JRjc0s2YlJVZ0xBckk' \
[i386]='https://drive.google.com/uc?export=download&confirm=no_antivirus&id=0Byemcyi98JRjdzFlWjVnbGpBMFU')

#соостветствие ppd файлов и моделей принтеров
declare -A LASERSHOT=([LBP-810]=1120 [LBP-1120]=1120 [LBP-1210]=1210 \
[LBP2900]=2900 [LBP3000]=3000 [LBP3010]=3050 [LBP3018]=3050 [LBP3050]=3050 \
[LBP3100]=3150 [LBP3108]=3150 [LBP3150]=3150 [LBP3200]=3200 [LBP3210]=3210 \
[LBP3250]=3250 [LBP3300]=3300 [LBP3310]=3310 [LBP3500]=3500 [LBP5000]=5000 \
[LBP5050]=5050 [LBP5100]=5100 [LBP5300]=5300 [LBP6000]=6018 [LBP6018]=6018 \
[LBP6020]=6020 [LBP6020B]=6020 [LBP6200]=6200 [LBP6300n]=6300n [LBP6300]=6300 \
[LBP6310]=6310 [LBP7010C]=7018C [LBP7018C]=7018C [LBP7200C]=7200C [LBP7210C]=7210C \
[LBP9100C]=9100C [LBP9200C]=9200C)

#отсортированные имена принтеров 
NAMESPRINTERS=$(echo "${!LASERSHOT[@]}" | tr ' ' '\n' | sort -n -k1.4)

#список моделей, которые поддерживаются утилитой автоотключения
declare -A ASDT_SUPPORTED_MODELS=([LBP6020]='MTNA002001 MTNA999999' \
[LBP6020B]='MTMA002001 MTMA999999' [LBP6200]='MTPA00001 MTPA99999' \
[LBP6310]='MTLA002001 MTLA999999' [LBP7010C]='MTQA00001 MTQA99999' \
[LBP7018C]='MTRA00001 MTRA99999' [LBP7210C]='MTKA002001 MTKA999999')

#архитектура операционной системы
if [ "$(uname -m)" == 'x86_64' ]; then
  ARCH='amd64'
else
  ARCH='i386'
fi

#определяем систему инициализации
if [[ $(ps -p1 | grep systemd) ]]; then
	INIT_SYSTEM='systemd'
else
	INIT_SYSTEM='upstart'
fi

#делаем рабочим каталог, в котором находится этот скрипт
cd "$(dirname "$0")"

function valid_ip() {
    local ip=$1
    local stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        ip=($(echo "$ip" | tr '.' ' '))
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

function check_error() {
	if [ $2 -ne 0 ]; then
		case $1 in
			'WGET') echo "Ошибка при скачивании файла $3"				
				[ -n "$3" ] && [ -f "$3" ] && rm "$3";;
			'PACKAGE') echo "Ошибка при установке пакета $3";;
			*) echo 'Ошибка';;
		esac
		echo 'Нажмите любую клавишу для выхода'
		read -s -n1
		exit 1
	fi
}

function canon_unistall() {
	if [ -f /usr/sbin/ccpdadmin ]; then
		installed_model=$(ccpdadmin | grep LBP | awk '{print $3}')
		if [ -n "$installed_model" ]; then
			echo "Найден принтер $installed_model"
			echo "Завершение captstatusui"
			killall captstatusui 2> /dev/null
			echo 'Остановка демона ccpd'
			service ccpd stop
			echo 'Удаление принтера из файла настройки ccpd демона'
			ccpdadmin -x $installed_model
			echo 'Удаление принтера из CUPS'
			lpadmin -x $installed_model
		fi
	fi
	echo 'Удаление пакетов драйвера'
	dpkg --purge cndrvcups-capt
	dpkg --purge cndrvcups-common
	echo 'Удаление неиспользуемых библиотек и пакетов'
	apt-get -y autoremove
	echo 'Удаление настроек'
	[ -f /etc/init/ccpd-start.conf ] && rm /etc/init/ccpd-start.conf
	[ -f /etc/udev/rules.d/85-canon-capt.rules ] && rm /etc/udev/rules.d/85-canon-capt.rules
	[ -f "${XDG_DESKTOP_DIR}/captstatusui.desktop" ] && rm "${XDG_DESKTOP_DIR}/captstatusui.desktop"
	[ -f /usr/bin/autoshutdowntool ] && rm /usr/bin/autoshutdowntool
	[ $INIT_SYSTEM == 'systemd' ] && update-rc.d -f ccpd remove
	echo 'Удаление завершено'
	echo 'Нажмите любую клавишу для выхода'
	read -s -n1
	return 0
}

function canon_install() {
	echo
	PS3='Выбор принтера. Введите нужную цифру и нажмите Enter: '
	select NAMEPRINTER in $NAMESPRINTERS
	do
		[ -n "$NAMEPRINTER" ] && break
	done
	echo "Выбран принтер: $NAMEPRINTER"
	echo
	PS3='Как принтер подключен к комьютеру? Введите нужную цифру и нажмите Enter: '
	select CONECTION in 'Через разъем порта USB' 'Через разъем локальной сети (LAN, NET)'
	do
		if  [ "$REPLY" == "1" ]; then
			CONECTION="usb"
			while true
			do	
				#ищем подключенное к порту USB устройство
				NODE_DEVICE=$(ls -1t /dev/usb/lp* 2> /dev/null | head -1)
				if [ -n "$NODE_DEVICE" ]; then
					#определяем серийный номер принтера
					PRINTER_SERIAL=$(udevadm info --attribute-walk --name=$NODE_DEVICE | sed '/./{H;$!d;};x;/ATTRS{product}=="Canon CAPT USB \(Device\|Printer\)"/!d;' |  awk -F'==' '/ATTRS{serial}/{print $2}')
					#если серийный номер найден, значит найденное устройство принтер Canon
					[ -n "$PRINTER_SERIAL" ] && break
				fi
				echo -ne "Включите принтер\r"
				sleep 2
			done
			PATH_DEVICE="/dev/canon$NAMEPRINTER"
			break
		elif [ "$REPLY" == "2" ]; then
			CONECTION="lan"
			read -p 'Введите IP-адрес принтера: ' IP_ADDRES
			until valid_ip "$IP_ADDRES"
			do
				echo 'Неверный формат IP-адреса, введите четыре десятичных числа значением'
				echo -n 'от 0 до 255, разделённых точками: '
				read IP_ADDRES
			done
			PATH_DEVICE="net:$IP_ADDRES"
			echo 'Включите принтер и нажмите любую клавишу'
			read -s -n1
			sleep 5
			break
		fi		
	done
	echo 'Установка драйвера'
	COMMON_FILE=cndrvcups-common_${DRIVER_VERSION_COMMON}_${ARCH}.deb
	CAPT_FILE=cndrvcups-capt_${DRIVER_VERSION}_${ARCH}.deb
	if [ ! -f $COMMON_FILE ]; then		
		sudo -u $LOGIN_USER wget -O $COMMON_FILE ${URL_DRIVER[${ARCH}_common]}
		check_error WGET $? $COMMON_FILE
	fi
	if [ ! -f $CAPT_FILE ]; then
		sudo -u $LOGIN_USER wget -O $CAPT_FILE ${URL_DRIVER[${ARCH}_capt]}
		check_error WGET $? $CAPT_FILE
	fi
	apt-get -y update
	apt-get -y install libglade2-0
	check_error PACKAGE $? libglade2-0
	echo 'Установка общего модуля для драйвера CUPS'
	dpkg -i $COMMON_FILE
	check_error PACKAGE $? $COMMON_FILE
	echo 'Установка модуля драйвера принтера CAPT'
	dpkg -i $CAPT_FILE
	check_error PACKAGE $? $CAPT_FILE
	#замена содержимого файла /etc/init.d/ccpd
	echo '#!/bin/bash
# startup script for Canon Printer Daemon for CUPS (ccpd)
### BEGIN INIT INFO
# Provides:          ccpd
# Required-Start:    $local_fs $remote_fs $syslog $network $named
# Should-Start:      $ALL
# Required-Stop:     $syslog $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Description:       Start Canon Printer Daemon for CUPS
### END INIT INFO

DAEMON=/usr/sbin/ccpd
case $1 in
	start)
		start-stop-daemon --start --quiet --oknodo --exec ${DAEMON}
		;;
	stop)
		start-stop-daemon --stop --quiet --oknodo --retry TERM/30/KILL/5 --exec ${DAEMON}
		;;	
	status)
		echo "${DAEMON}:" $(pidof ${DAEMON})
		;;
	restart)
		while true
		do
			start-stop-daemon --stop --quiet --oknodo --retry TERM/30/KILL/5 --exec ${DAEMON}
			start-stop-daemon --start --quiet --oknodo --exec ${DAEMON}
			for (( i = 1 ; i <= 5 ; i++ )) 
			do
				sleep 1
				set -- $(pidof ${DAEMON})
				[ -n "$1" -a -n "$2" ] && exit 0
			done
		done
		;;
	*)
		echo "Usage: ccpd {start|stop|status|restart}"
		exit 1
		;;
esac
exit 0' > /etc/init.d/ccpd
	#установка утилит для управления AppArmor
	apt-get -y install apparmor-utils
	#установка в AppArmor профиля в щадящий режим для cupsd
	aa-complain /usr/sbin/cupsd
	echo 'Перезапуск CUPS'
	service cups restart
	echo 'Установка 32-битных библиотек необходимых для'
	echo '64-разрядной версии драйвера принтера'
	if [ $ARCH == 'amd64' ]; then
		apt-get -y install libatk1.0-0:i386 libcairo2:i386 libgtk2.0-0:i386 libpango1.0-0:i386 libstdc++6:i386 libpopt0:i386 libxml2:i386 libc6:i386
		check_error PACKAGE $?
	fi
	echo 'Установка принтера в CUPS'
	/usr/sbin/lpadmin -p $NAMEPRINTER -P /usr/share/cups/model/CNCUPSLBP${LASERSHOT[$NAMEPRINTER]}CAPTK.ppd -v ccp://localhost:59687 -E
	echo "Установка принтера $NAMEPRINTER, принтером, используемым по умолчанию"
	/usr/sbin/lpadmin -d $NAMEPRINTER
	echo 'Регистрация принтера в файле настройки ccpd демона'
	/usr/sbin/ccpdadmin -p $NAMEPRINTER -o $PATH_DEVICE
	#проверка установки принтера
	installed_printer=$(ccpdadmin | grep $NAMEPRINTER | awk '{print $3}')
	if [ -n "$installed_printer" ]; then
		if [ "$CONECTION" == "usb" ]; then
			echo 'Создание правила для принтера'
			#составлем правило, которое обеспечит альтернативное имя (символическую ссылку) нашему принтеру, чтобы не зависить от меняющихся значений lp0,lp1, ...
			echo 'KERNEL=="lp[0-9]*", SUBSYSTEMS=="usb", ATTRS{serial}=='$PRINTER_SERIAL', SYMLINK+="canon'$NAMEPRINTER'"' > /etc/udev/rules.d/85-canon-capt.rules
			#обновляем правила 
			udevadm control --reload-rules
			#проверка созданного правила
			until [ -e $PATH_DEVICE ]
			do
				echo -ne "Выключите принтер, подождите 2 секунды, затем включите принтер\r"
				sleep 2
			done
		fi
		echo -e "\e[2KЗапуск ccpd"
		service ccpd restart
		#автозагрузка ccpd
		if [ $INIT_SYSTEM == 'systemd' ]; then
			update-rc.d ccpd defaults
		else
			echo 'description "Canon Printer Daemon for CUPS (ccpd)"
author "LinuxMania <customer@linuxmania.jp>"
start on (started cups and runlevel [2345])
stop on runlevel [016]
expect fork
respawn
exec /usr/sbin/ccpd start' > /etc/init/ccpd-start.conf	
		fi
		#создаем кнопку запуска captstatusui на рабочем столе
		echo '#!/usr/bin/env xdg-open
[Desktop Entry]
Version=1.0
Name=captstatusui
GenericName=Status monitor for Canon CAPT Printer
Exec=captstatusui -P '$NAMEPRINTER'
Terminal=false
Type=Application
Icon=/usr/share/icons/Humanity/devices/48/printer.svg' > "${XDG_DESKTOP_DIR}/captstatusui.desktop"
		chmod 775 "${XDG_DESKTOP_DIR}/captstatusui.desktop"
		chown $LOGIN_USER:$LOGIN_USER "${XDG_DESKTOP_DIR}/captstatusui.desktop"
		#установка утилиты автоотключения для поддерживаемых моделей принтеров
		if [[ "${!ASDT_SUPPORTED_MODELS[@]}" =~ "$NAMEPRINTER" ]]; then
			SERIALRANGE=(${ASDT_SUPPORTED_MODELS[$NAMEPRINTER]})
			SERIALMIN=${SERIALRANGE[0]}
			SERIALMAX=${SERIALRANGE[1]}	
			if [[ ${#PRINTER_SERIAL} -eq ${#SERIALMIN} && $PRINTER_SERIAL > $SERIALMIN && $PRINTER_SERIAL < $SERIALMAX || $PRINTER_SERIAL == $SERIALMIN || $PRINTER_SERIAL == $SERIALMAX ]]; then
				echo "Установка утилиты autoshutdowntool"
				ASDT_FILE=autoshutdowntool_1.00-1_${ARCH}_deb.tar.gz
				if [ ! -f $ASDT_FILE ]; then		
					wget -O $ASDT_FILE ${URL_ASDT[$ARCH]}
					check_error WGET $? $ASDT_FILE
				fi
				tar --gzip --extract --file=$ASDT_FILE --totals --directory=/usr/bin
			fi
		fi	
		#запуск  captstatusui
		if [[ -n "$DISPLAY" ]] ; then
			sudo -u $LOGIN_USER nohup captstatusui -P $NAMEPRINTER > /dev/null 2>&1 &
			sleep 5
		fi
		echo 'Установка завершена. Нажмите любую клавишу для выхода'
		read -s -n1
		exit 0
	else
		echo "Принтер $NAMEPRINTER не установлен"
		echo 'Нажмите любую клавишу для выхода'
	 	read -s -n1
		exit 1
	fi
}

function canon_update() {
	if [ -f /usr/sbin/ccpdadmin ]; then
		NAMEPRINTER=$(ccpdadmin | grep LBP | awk '{print $3}')
		if [ -n "$NAMEPRINTER" ]; then
			echo "Найден принтер $NAMEPRINTER"
			SETUP_DRIVER_VERSION=$(dpkg -l | grep cndrvcups-capt | awk '{print $3}')
			echo "Установленная версия драйвера: $SETUP_DRIVER_VERSION"
			echo "Верcия драйвера, которая будет установлена: $DRIVER_VERSION"			
			dpkg --compare-versions $DRIVER_VERSION lt $SETUP_DRIVER_VERSION
			if [ $? -eq 0 ]; then
				echo 'Версия устанавливаемого драйвера меньше версии уже установленного.
Обновление не будет продолжено. Нажмите любую клавишу для выхода'
				read -s -n1
				exit 1
			fi
			echo "Завершение captstatusui"
			killall captstatusui 2> /dev/null
			echo 'Остановка демона ccpd'
			service ccpd stop
			echo 'Удаление принтера из CUPS'
			lpadmin -x $NAMEPRINTER
			#обновление драйвера...'
			COMMON_FILE=cndrvcups-common_${DRIVER_VERSION_COMMON}_${ARCH}.deb
			CAPT_FILE=cndrvcups-capt_${DRIVER_VERSION}_${ARCH}.deb
			if [ ! -f $COMMON_FILE ]; then		
				sudo -u $LOGIN_USER wget -O $COMMON_FILE ${URL_DRIVER[${ARCH}_common]}
				check_error WGET $? $COMMON_FILE
			fi
			if [ ! -f $CAPT_FILE ]; then
				sudo -u $LOGIN_USER wget -O $CAPT_FILE ${URL_DRIVER[${ARCH}_capt]}
				check_error WGET $? $CAPT_FILE
			fi
			echo 'Обновление общего модуля для драйвера CUPS'
			dpkg -i $COMMON_FILE
			check_error PACKAGE $? $COMMON_FILE
			echo 'Обновление модуля драйвера принтера CAPT'
			dpkg -i $CAPT_FILE
			check_error PACKAGE $? $CAPT_FILE
			echo 'Перезапуск CUPS'
			service cups restart
			echo 'Устанавка принтера в CUPS'
			/usr/sbin/lpadmin -p $NAMEPRINTER -P /usr/share/cups/model/CNCUPSLBP${LASERSHOT[$NAMEPRINTER]}CAPTK.ppd -v ccp://localhost:59687 -E
			echo "Установка принтера $NAMEPRINTER, принтером, используемым по умолчанию"
			/usr/sbin/lpadmin -d $NAMEPRINTER
			if [[ -n "$DISPLAY" ]] ; then			
				echo 'Запуск captstatusui'
				while true
				do
					sleep 1
					set -- $(pidof /usr/sbin/ccpd)
					if [ -n "$1" -a -n "$2" ]; then
						sudo -u $LOGIN_USER nohup captstatusui -P $NAMEPRINTER > /dev/null 2>&1 &
						sleep 5
						break
					fi
				done
			fi
			echo "Драйвер обновлен. Нажмите любую клавишу для выхода"
	 		read -s -n1
			exit 0
		fi
	fi
	echo "Принтеры из серии Canon LBP не установлены"
	echo 'Нажмите любую клавишу для выхода'
	read -s -n1
	exit 1
}

function canon_help {
	clear
	echo 'Замечания по установке
Если вы уже делали какие-либо действия по установке принтера этой серии, 
в текущей системе, то перед началом установки, следует отменить эти действия.
При отсутствии пакетов драйвера они автоматически скачиваются из интернета 
в папку скрипта. Принтеры LBP-810, LBP-1210 подключайте через разъем порта USB
Для обновления драйвера сначала удаляете старую версию через скрипт, затем 
устанавливаете новую также через скрипт.
Замечания по проблемам печати
Если принтер перестает печатать, запускаете captstatusui через кнопку запуска 
на рабочем столе или в терминале командой: captstatusui -P <имя_принтера>
В окне captstatusui отображается сообщение о текущем состояние принтера, если
возникает ошибка, выводится её описание. Здесь можно попробывать нажать кнопку 
"Resume Job" для продолжение печати или кнопку "Cancel Job" для отмены задания. 
Если это не помогает, тогда запускаете скрипт canon_restart.sh

команда настройки принтера: cngplp
дополнительные настройки, команда: captstatusui -P <имя_принтера>
настройка автоотключения (не для всех моделей): autoshutdowntool
Замечания и ошибки пишите на почту coden@mail.ru или 
на форум http://forum.ubuntu.ru/index.php?topic=189049.0
Для логирования процесса установки запускайте скрипт так:
logsave log.txt ./canon_lbp_setup.sh
'
}

clear
echo 'Установка драйвера Linux CAPT Printer Driver v'${DRIVER_VERSION}' для принтеров Canon LBP
на Ubuntu 12.04, 12.10, 13.04, 13.10, 14.04, 14.10, 15.04, 15.10, 16.04 32-битной и 64-битной архитектуры
Поддерживаемые принтеры:'
echo "$NAMESPRINTERS" | sed ':a; /$/N; s/\n/, /; ta' | fold -s

PS3='Выбор действия. Введите нужную цифру и нажмите Enter: '
select opt in 'Установка' 'Удаление' 'Справка' 'Выход'
do
	if [ "$opt" == 'Установка' ]; then
		canon_install
		break
	elif [ "$opt" == 'Удаление' ]; then
		canon_unistall
		break
#	elif [ "$opt" == 'Обновление' ]; then
#		canon_update
#		break	
	elif [ "$opt" == 'Справка' ]; then
		canon_help
	elif [ "$opt" == 'Выход' ]; then
		break
	fi
done
