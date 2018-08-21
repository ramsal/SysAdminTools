[root@sd4225 scripts]# cat backups.sh
#!/bin/bash

####  FUNCIONES

function hazbackup(){
#       echo "action=backup&ftp_ip=$srvbackup&ftp_password=$ftppass&ftp_path=$ruta&ftp_port=21&ftp_username=$ftpuser&owner=admin&type=admin&value=multiple&when=now&where=ftp&who=all"
#       echo "action=backup&ftp_ip=$srvbackup&ftp_password=$ftppass&ftp_path=$ruta&ftp_port=21&ftp_username=$ftpuser&owner=admin&select=admin&type=reseller&value=multiple&when=now&where=ftp&who=except" >> /usr/local/directadmin/data/task.queue
        echo "action=backup&ftp%5Fip=$srvbackup&ftp%5Fpassword=$ftppass&ftp%5Fpath=$ruta&ftp%5Fport=%32%31&ftp%5Fusername=$ftpuser&owner=admin&type=admin&value=multiple&when=now&where=ftp&who=all" >> /usr/local/directadmin/data/task.queue
}


####  FUNCIONES
##DEFINIR srvbackup, ftpuser y ftpass

ruta=""
dia=`date +%d`
diasem=`date +%u`
srvbackup="FTP_SERVIDOR"                #definir
ftpuser="FTP_USER"                      #definir
ftppass=$( echo "FTP_PASS"|SHA1 )     #definir

if [ $dia == "01" ] || [ $dia == "15" ];then
        case $dia in
                01 )
                        ruta="$ruta/mensual/"
                        ;;
                15 )
                        ruta="$ruta/quincenal/"
                        ;;
        esac
else
        if [ `expr $diasem % 2` == "1" ];then
                ruta="$ruta/dimp/"
        else
                ruta="$ruta/dpar/"
        fi
fi
hazbackup

exit 0
