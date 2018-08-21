[root@sd4225 scripts]# cat rastreator.sh
#!/bin/bash

# Este script obtiene un reporte de ficheros y directorios sospechosos por su nombre

# patterns file
dir=`dirname $0`
file="$dir/rastreator-patterns.txt"

# build command
comm="find ."
idx=0
while read pattern
do
    if [ $idx -gt 0 ]; then
        comm="$comm -o"
    fi
    comm="$comm -path \"$pattern\""
    (( idx++ ))
done < $file

# execute command
