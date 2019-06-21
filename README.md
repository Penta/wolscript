# wolscript
Script Shell permettant de gérer et de réveiller des groupements d'ordinateurs en toute facilité. 

Ce script permet de reveiller une salle en se baseant sur le contenu du fichier wakeup.csv (par defaut) et sur la technologie Wake on LAN.

Installez ce script dans le dossier /wol/ (ou alors changez l'emplacement dans les paramètres plus bas dans ce fichier.

N'oubliez pas de rendre le script exécutable via la commande :
    chmod +x ./wolscript.sh

Puis pour le lancer :
    /wol/wolscript.sh

Pour installer wakeonlan :
    apt-get install wakeonlan (pour Debian/Ubuntu)
Ou via wget (plus à jour et compatible avec les autres distribution) :
    wget https://raw.githubusercontent.com/jpoliv/wakeonlan/master/wakeonlan
(Vous devez mettre l'exécutable dans le même répertoire que le script)

Le script peut reconnaitre automatiquement les adresses MAC separée soit par un double-points, soit par un tiret (celui sera transformé en double-points pour le traitement via wakeonlan).

Les fichiers des salles (.wol) sont stockés dans le dossier ./script/, ils contiennent toutes les adresses MAC des machines de la salle.
Ce script peut générer ces fichiers .wol, il peut afficher les horaires des salles, convertir une adresse IP en adresse MAC et peut allumer toutes les salles si besoin est.

Il faut aussi aller ajouter ce script dans /etc/crontab pour l'exécuter automatiquement :                                               
 Ex : */10 *  * * *   root cd /wol && ./wolscript.sh --auto -f wakeup.csv

Ou alors via la commande : crontab -e
 Ex : */10 *  * * *   cd /wol && ./wolscript.sh --auto -f wakeup.csv
 
Qui permet d'executer le script automatiquement (parametre: --auto)
toutes les dix minutes avec les heures indiquées dans le fichier
wakeup.csv (paramètres: -f wakeup.csv)

Si vous voulez créer la commande "wolscript", alors :
    ln -s /wol/wolscript.sh /usr/bin/wolscript

La commande exit permet de quitter la plupart des menus, veuillez donc ne pas nommer vos fichiers avec ce nom !

Pour voir les logs en temps réel :
    tail -f /var/log/wolscript.log

Pour fonctionner, le script à besoin d'un fichier contenant le nom des salles à réveiller (le même nom que dans les fichiers scripts des salles dans le dossier script), et l'heure de la journée en minutes à laquelle les ordinateurs de la salle doivent être réveillés (séparé par un ;).

Exemple de ligne dans le fichier CSV :
    A105;600       (Les odinateurs de la salle A105 seront allumés à 10h)
    B304;700

Pour cet exemple, il faut que le fichier A105.wol contenant uniquement les adresses MAC de la salle soit dans le dossier ./script/       

### Par Andy Esnard - Décembre 2017
