#!/bin/bash
#
# Copyright (C) 2008-2015 by Robert Cotrone & Dan Landon
#
# This file is part of the Powerdown package for unRAID.
#
# Powerdown is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Powerdown is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Powerdown.  If not, see <http://www.gnu.org/licenses/>.
#

config() {
  NEW="$1"
  OLD="`dirname $NEW`/`basename $NEW .new`"
  # If there's no config file by that name, mv it over:
  if [ ! -r $OLD ]; then
    mv $NEW $OLD
  elif [ "`cat $OLD | md5sum`" = "`cat $NEW | md5sum`" ]; then
    # toss the redundant copy
    rm $NEW
  fi
  # Otherwise, we leave the .new copy for the admin to consider...
}

[ ${DEBUG:=0} -gt 0 ] && set -x -v 

#for i in config.new 
#do # config etc/$i; 
#done

POWERDOWNHOME=/boot/config/plugins/powerdown/rc.unRAID.d/
SD_RCFILE=/etc/rc.d/rc.local_shutdown
RCFILE=/etc/rc.d/rc.unRAID
RC_DIR=/etc/rc.d/rc.unRAID.d/
PLUGIN_DIR=/usr/local/emhttp/plugins/powerdown/event

[ ! -d "${POWERDOWNHOME}" ] && mkdir -p ${POWERDOWNHOME}
[ ! -d "${RC_DIR}" ] && mkdir -p ${RC_DIR}

# copy the K scripts from the flash
find ${POWERDOWNHOME} -type f -name 'K[0-9][0-9]*' | sort | while read script
do  if [ -x ${script} ] ; then
       fromdos < ${script} > ${RC_DIR}${script##*/}
       chmod +x ${RC_DIR}${script##*/}
    fi
done

# copy the S scripts from the flash
find ${POWERDOWNHOME} -type f -name 'S[0-9][0-9]*' | sort | while read script
do  if [ -x ${script} ] ; then
       fromdos < ${script} > ${RC_DIR}${script##*/}
       chmod +x ${RC_DIR}${script##*/}
    fi
done

# copy the KSV scripts from the flash
find ${POWERDOWNHOME} -type f -name 'KSV[0-9][0-9]*' | sort | while read script
do  if [ -x ${script} ] ; then
       fromdos < ${script} > ${RC_DIR}${script##*/}
       chmod +x ${RC_DIR}${script##*/}
    fi
done

# remove any *.bak files
find ${RC_DIR} \( -name '*.bak' -o -name '*.BAK' \) -delete

mkdir -p ${PLUGIN_DIR}

echo "/etc/rc.d/rc.unRAID start" > ${PLUGIN_DIR}/started
chmod 0770 ${PLUGIN_DIR}/started

echo "/etc/rc.d/rc.unRAID kill_svcs" > ${PLUGIN_DIR}/stopping_svcs
chmod 0770 ${PLUGIN_DIR}/stopping_svcs

echo "/etc/rc.d/rc.unRAID kill" > ${PLUGIN_DIR}/unmounting_disks
chmod 0770 ${PLUGIN_DIR}/unmounting_disks

if ! grep ${RCFILE} ${SD_RCFILE} >/dev/null 2>&1
   then echo -e "\n\n[ -x ${RCFILE} ] && ${RCFILE} stop\n" >> ${SD_RCFILE}
fi

[ ! -x ${SD_RCFILE} ] && chmod u+x ${SD_RCFILE}


if [ ! -z "${CTRLALTDEL}" ];then 
   sed --in-place=.bak -e 's/shutdown .*/powerdown/g' /etc/inittab
   /sbin/telinit q
fi

if [ ! -z "${START}" ];then 
   ${RCFILE} start
fi

if [ ! -z "${SYSLOG}" ];then 
   ${RCFILE} syslog
fi

if [ ! -z "${STATUS}" ];then 
   ${RCFILE} status
fi

if [ ! -z "${HDPARM}" ];then 
   sed --in-place=.bak -e "s/HDPARM=.*/HDPARM=${HDPARM}/g" ${RCFILE}
fi

if [ ! -z "${SMARTCTL}" ];then 
   sed --in-place=.bak -e "s/SMARTCTL=.*/SMARTCTL=${SMARTCTL}/g" ${RCFILE}
fi

if [ ! -z "${LOGDIR}" ];then 
   sed --in-place=.bak -e "s/LOGDIR=.*/LOGDIR=${LOGDIR}/g" ${RCFILE}
fi

if [ ! -z "${LOGSAVE}" ];then 
   sed --in-place=.bak -e "s/LOGSAVE=.*/LOGSAVE=${LOGSAVE}/g" ${RCFILE}
fi

if [ ! -z "${RCDIR}" ];then
   sed --in-place=.bak -e "s/RCDIR=.*/RCDIR=${RCCDIR}/g" ${RCFILE}
fi

if [ ! -z "${LOGROTATE}" ];then 
   if ! grep ${RCFILE} /etc/logrotate.conf > /dev/null 2>&1
    then IFS="
"
	   while read LINE
	   do echo "${LINE}"
		  if [ "${LINE}" = "/var/log/syslog {" ]
			 then echo "    prerotate"
				  echo "       ${RCFILE} syslog"
				  echo "    endscript"
				  echo "    compress"
		  fi
		done < /etc/logrotate.conf    > /etc/logrotate.conf.tmp
		cat < /etc/logrotate.conf.tmp > /etc/logrotate.conf
		rm -f /etc/logrotate.conf.tmp
   fi
fi

# set the default power button press to /sbin/powerdown and
# be sure the correct powerdown script is used
# Save the unraid powerdown script.
[ -f /usr/local/sbin/powerdown ] && mv /usr/local/sbin/powerdown /usr/local/sbin/unraid_powerdown
cp /sbin/powerdown /usr/local/sbin/powerdown 2>/dev/null
sed -i -e "s/event=.*/event=button power.*/" /etc/acpi/events/default
sed -i -e "s/\/etc\/acpi\/acpi_handler.sh %e/\/sbin\/powerdown/" /etc/acpi/events/default
sed -i -e "s/init 0/powerdown/" /etc/acpi/acpi_handler.sh   
sysctl -w kernel.poweroff_cmd=/sbin/powerdown
