#!/bin/bash

#repetir até obter arquivo executável
while true;
do
    directory=$(zenity --file-selection --file-filter="Arquivo executável (exe) | *.exe" --title="Selecione o executável:" --filename="/home/$USERNAME/.wine/drive_c/")
    if [ $? -eq 0 ]
    then
        break;
    else
        $(zenity --question --text="Você tem que selecionar um arquivo executável para continuar. Deseja tentar novamente?")
        case $? in
            0) ;;
            *) exit
               ;;
        esac  
    fi
done

devpath=$(find /sys/class/hidraw ! -path /sys/class/hidraw -name 'hidraw'*)

#http://www.linuxquestions.org/questions/programming-9/reading-lines-to-an-array-and-generate-dynamic-zenity-list-881421/
   
mode="true"
choices=()

#Ler cada arquivo de texto em dp/device/uevent para descobrir o nome do dispositivo
#OBS: Tanto dp como devpath armazenam o caminho da pasta, não só o nome

for dp in ${devpath}
do   
    #Obtem o nome da pasta a partir do caminho armazenado em dp
    foldername=$(basename "$dp")
    #Lê /sys/class/hidraw/hidraw[#]/device/uevent a procura de seu Hid_name           
    devname=$(grep -oP 'HID_NAME=\K.*' $dp/device/uevent)
    #Vetor que atualiza a cada iteração para preencher a lista dispositivos no zenity --radiolist
    choices=("${choices[@]}" "$mode" "$devname")
	mode="false"    
done

#repetir até obter nome do dispositivo
while true;
do
    choice=$(zenity \
	    --list \
	    --radiolist \
	    --text="Dispositivos conectados:" \
	    --column "" \
	    --column "Dispositivos: " \
	    "${choices[@]}")

    if [ $? -eq 0 ]
    then
        break;
    else
        $(zenity --question --text="Você tem que selecionar um dispositivo para continuar. Deseja tentar novamente?")
        case $? in
            0) ;;
            *) exit
               ;;
        esac  
    fi
done

filename=$(basename "$directory")
filename="${filename%%.*} script"

cat > "$filename.sh" << End_Script
#!/bin/bash

#Como fazer o wine detectar dispositivos HID
#https://wiki.winehq.org/Hid

function startApp 
{
    su \$USERNAME
    wine cmd
    wine net start winebus
    #transforma o caminho em linux para wine (como se fosse no windows)
    wine start "c:${directory#*drive_c}"
    exit
}

function devNotFound
{
    \$(zenity --question --text="Dispositivo não foi achado, Deseja repetir procedimento?")
    case \$? in
        0) searchDevice
           ;;
        *) exit
           ;;
    esac        
    
}

function searchDevice 
{
    #Obtem lista de pastas dentro de /sys/class/hidraw excluindo ela mesma
    #A lista de dispositivos HID é variavel,por isso refazoss passos toda vez ao executar o script
    devpath=\$(find /sys/class/hidraw ! -path /sys/class/hidraw -name 'hidraw'*)

    #Ler cada arquivo de texto em dp/device/uevent para descobrir o nome do dispositivo
    #OBS: Tanto dp como devpath armazenam o caminho da pasta não só o nome
    for dp in \${devpath}
    do   
        #Obtem o nome da pasta a partir do caminho armazenado em dp
        foldername=\$(basename "$dp")
        #Lê a terceira linha de /sys/class/hidraw/hidraw[#]/device/uevent 
        #http://stackoverflow.com/questions/7996629/how-do-i-read-the-nth-line-of-a-file-and-print-it-to-a-new-file          
        devicename=\$(sed -n '3{p;q;}' \$dp/device/uevent)
        if [[ "\$devicename" == *"$devname" ]]
        then
            #Dá permissão ao dispositivo hid
            #Só funciona com 777, go+rw fica carregando, mas não funciona (averiguado apenas no dispositivo testado)
            pkexec chmod 777 /dev/\$foldername            
            startApp
            break
        fi
    done
    
    devNotFound
}

searchDevice

exit

End_Script

exit


