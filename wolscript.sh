#!/bin/bash

################################################################################
#                                wolscript.sh                                  #
################################################################################
#                                                                              #
# Ce script permet de reveiller une salle en se baseant sur le contenu du      #
# fichier wakeup.csv (par defaut) et sur la technologie Wake on LAN.           #
#                                                                              #
# Installez ce script dans le dossier /wol/ (ou alors changez l'emplacement    #
# dans les paramètres plus bas dans ce fichier.                                #
#                                                                              #
# N'oubliez pas de rendre le script exécutable via la commande :               #
# chmod +x ./wolscript.sh                                                      #
#                                                                              #
# Puis pour le lancer :                                                        #
#  - /wol/wolscript.sh                                                         #
#                                                                              #
# Pour installer wakeonlan :                                                   #
#  - apt-get install wakeonlan (pour Debian/Ubuntu)                            #
#  ou via wget (plus à jour et compatible avec les autres distribution) :      #
#  https://raw.githubusercontent.com/jpoliv/wakeonlan/master/wakeonlan         #
# (Vous devez mettre l'exécutable dans le même répertoire que le script)       #
#                                                                              #
# Pour les dépendances du script PHP :                                         #
#  - apt-get install php5 php-mysql mysql-client                               #
#                                                                              #
# Le script peut reconnaitre automatiquement les adresses MAC separée soit     #
# par un double-points, soit par un tiret (celui sera transformé en            #
# double-points pour le traitement via wakeonlan).                             #
#                                                                              #
# Les fichiers des salles (.wol) sont stockés dans le dossier ./script/, ils   #
# contiennent toutes les adresses MAC des machines de la salle.	               #
# Ce script peut générer ces fichiers .wol, il peut afficher les horaires      #
# des salles, convertir une adresse IP en adresse MAC et peut allumer toutes   #
# les salles si besoin est.                                                    #
#                                                                              #
# Il faut aussi aller ajouter ce script dans /etc/crontab pour l'exécuter      #
# automatiquement :                                                            #
#  Ex : */10 *  * * *   root cd /wol && ./wolscript.sh --auto -f wakeup.csv    #
#                                                                              #
# Ou alors via la commande : crontab -e                                        #
#  Ex : */10 *  * * *   cd /wol && ./wolscript.sh --auto -f wakeup.csv         #
#                                                                              #
# Qui permet d'executer le script automatiquement (parametre: --auto)          #
# toutes les dix minutes avec les heures indiquées dans le fichier             #
# wakeup.csv (paramètres: -f wakeup.csv)                                       #
#                                                                              #
# Si vous voulez créer la commande "wolscript", alors :                        #
#  - ln -s /wol/wolscript.sh /usr/bin/wolscript                                #
#                                                                              #
# La commande exit permet de quitter la plupart des menus, veuillez ne donc    #
# pas nommer vos fichiers avec ce nom !                                        #
#                                                                              #
# Pour voir les logs en temps réel : tail -f /var/log/wolscript.log            #
#                                                                              #
# Pour fonctionner, le script à besoin d'un fichier contenant le nom des       #
# salles à réveiller (le même nom que dans les fichiers scripts des salles     #
# dans le dossier script), et l'heure de la journée en minutes à laquelle les  #
# ordinateurs de la salle doivent être réveillés (séparé par un ;).            #
#                                                                              #
# Exemple de ligne dans le fichier CSV :                                       #
#  A105;600       (Les odinateurs de la salle A105 seront allumés à 10h)       #
#                                                                              #
# Pour cet exemple, il faut que le fichier A105.wol contenant uniquement les   #
# adresses MAC de la salle soit dans le dossier ./script/                      #
#                                                                              #
#                                                                              #
#                                                                              #
#               Par Andy Esnard - Décembre 2017 (rev 1.1.1)                    #
#                                                                              #
################################################################################



                     ####################################
                     #  Quelques variables modifiables  #
################################################################################
#                                                                              #
# Emplacement du fichier de log                                                #
fichierlog="/var/log/wolscript.log"                                            #
#                                                                              #
# Combien de minutes doit-on allumer les machines à l'avance ?                 #
delai=15                                                                       #
#                                                                              #
# Emplacement du script !                                                      #
emplacement="/wol/"                                                            #
#                                                                              #
# Fichier CSV par défaut :                                                     #
csvdefaut="wakeup.csv"                                                         #
#                                                                              #
# Commande qui régénère les horaires :                                         #
commande_externe="php ./php/wakeup.php > /dev/null"                            #
#                                                                              #
# Lancement de la génération des horaires automatisée                          #
externe_automatique="false"                                                    #
#                                                                              #
# true = Réveil de toutes les salles qu'importe l'heure (avec --auto !)        #
forcerreveiltotal="false"                                                      #
#                                                                              #
# Répéter la commande wakeonlan (au minimum 1 !)                               #
repetition=3                                                                   #
#                                                                              #
# Decommentez pour debugger                                                    #
#set -ax                                                                       #
#                                                                              #
################################################################################



# Variables globales
tabsalle[0]=
tabhoraire[0]=

cd "$emplacement"

# Permet de séparer chaque exécution du script dans le fichier de log pour une meilleure lisibilité
echo "===============================================================================" >> $fichierlog
echo "===============================================================================" >> $fichierlog

# On test la présence de la commande wakeonlan
wakeonlan > /dev/null 2>&1

# Si la commande n'est pas installée via apt-get
if [ $(echo $?) -gt 0 ]
then
	./wakeonlan > /dev/null 2>&1
	
	# Si la commande n'est pas installée via wget
	if [ $(echo $?) -gt 0 ]
	then
		# La commande n'est pas présente sur le systeme
		logger "[ERROR] Arret du script : wakeonlan non présent !"
		clear

		echo -e "La commande wakeonlan n'est pas présente ou n'est pas exécutable !\n"
		echo "Veuillez l'installer soit par les dépots (pour Debian/Ubuntu) :"
		echo " => apt-get install wakeonlan"
		echo "Soit en téléchargeant le script via wget :"
		echo " => wget https://raw.githubusercontent.com/jpoliv/wakeonlan/master/wakeonlan"

		echo -e "\nL'exécutable doit être dans le meme répertoire que ce script."
		echo -e "\nchmod +x ./wakeonlan pour rendre le script exécutable."
		echo -en "\nAppuyez sur Entrée pour continuer... "
		read

		clear
		exit
	else
		logger "[INFO] Utilisation de l'exécutable ./wakeonlan"

		# Installee via wget
		wol=./wakeonlan
	fi
else
	logger "[INFO] Utilisation de la commande wakeonlan"
	
	# Installée via apt-get
	wol=wakeonlan
fi

# On assure que le script sera exécuté au moins une fois
if [ "$repetition" -lt 1 ]
then
	repetition=1
fi

# Inscrit des informations dans le fichier de log
logger () {
	# La date et l'heure actuelle
	datelog=$(date +"%x %X")

	echo '['$datelog'] '$1'' >> $fichierlog
}

# Charge le fichier CSV des horaires
charger_csv () {
	if  [ -z "$1" ]
	then
		# Si aucun fichier n'a ete indiqué à la fonction, alore on charge le fichier par defaut
		fichier_csv=$csvdefaut
	else
		fichier_csv="$1"
	fi

	logger "[INFO] Lecture du fichier $fichier_csv..."

	# Si le fichier CSV existe
	if [ -f "$fichier_csv" ]
	then
		i=0

		# On lit le fichier CSV
		while IFS=';' read salle horaire null
		do
			# On calcule l'heure lisible a partir du total de minute
			heure=$(echo $(($horaire/60)))
			minute=$(echo $(($horaire%60)))

			# Si les minutes sont en dessous de 10, on rajoute un zéro devant
			if [ $minute -lt 10 ]
			then
				minute="0"$minute
			fi

			# Et on log l'heure dans le fichier de log
			logger "[DEBUG] $salle a "$heure"h$minute ($horaire min)"

			# On remplie les variables globales du contenu du fichier CSV
			tabsalle[i]=$salle
			tabhoraire[i]=$horaire

			# Et on incrémente
			i=$(($i + 1))
		done < "$fichier_csv"

		# Si il est vide
		if [ $i -eq 0 ]
		then
			logger "[WARNING] le fichier $fichier est vide !"
		else
			logger "[INFO] Chargement du fichier $fichier réussi !"
			logger "[INFO] $i salle(s) trouvée(s)."
		fi
	else
		logger "[ERROR] Arret du script : Fichier inexistant !"

		# On renvoie une erreur
		exit 1
	fi
}

# Menu principal pendant un lancement manuel
menu () {
	while true
	do
		clear

		# On affiche le menu
		echo "-------------------------------------------------------------------------------"
		echo " Menu Principal                                                         (1.1.1)"
		echo "-------------------------------------------------------------------------------"
		echo "0............ Sortir"
		echo "1............ Réveiller une salle"
		echo "2............ Voir les horaires de réveil des salles"
		echo "3............ Créer un nouveau script de salle"
		echo "4............ Voir les logs (44 : Les voir en temps réel)"
		echo "5............ Générer les horaires"
		echo "6............ Convertir une adresse IP en adresse MAC"
		echo "-------------------------------------------------------------------------------"
		echo "-------------------------------------------------------------------------------"

		# Et son prompt
		echo -ne "\nTapez votre choix : "

		# On recupère le choix de l'utilisateur
		read rep

		# Et on le compare a ceux proposes
		case "$rep" in
			0 | "exit") logger "[INFO] Fermeture du mode manuel..."; exit 0 ;;
			
			1) reveiller ;;
			2) afficher ;;
			3) nouveau ;;

			4)  clear; less $fichierlog ;;
			44) clear; tail -f $fichierlog ;;

			5) logger "[INFO] Relance manuelle de la commande des horaires"; $commande_externe ;;
			6) conversion ;;
		esac

	done
}

# Fonction qui permet de convertir une IP en adresse MAC
conversion () {
	clear

	adresse=
	ip=

	while true
	do
		echo -n "Adresse IP (ou nom de domaine) à convertir : "
		read adresse
		
		if [ ! -z "$adresse" ]
		then
			if [ ! "$adresse" = "exit" ]
			then
				echo -en "\nPing en cours"
				ping -c 2 "$adresse" > /dev/null
				echo -n "."
				ping -c 2 "$adresse" > /dev/null
				echo -n "."
				ping -c 2 "$adresse" > /dev/null
				echo -n "."
				ping -c 2 "$adresse" > /dev/null

				ip=$(nslookup $adresse | grep "Address" | sed '1d' | head -n 1 | sed -e 's/Address: //' | sed '/^$/d')

				if [ ! -z "$ip" ]
				then
					echo -en "\n\nAdresse IP : $ip"
					mac=$(arp -a | grep "$ip)" | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')
				else
					mac=$(arp -a | grep "$adresse)" | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')
				fi

				if [ -z "$mac" ]
				then
					echo -e "\n\nImpossible de convertir cette adresse IP ou ce nom de domaine !"
				else
					echo -e "\n\nAdresse MAC : $mac"
				fi
				
				echo -en "\nAppuyez sur Entrée pour continuer... "
				read
				
				break
			else
				break
			fi
		else
			adresse=
		fi
	done
}

# Fonction qui permet de réveiller une salle via un fichier .wol
reveiller () {
	logger "[INFO] Ouverture du réveil manuel des salles"

	clear

	total=0
	rep=
	confirme=non

	echo -e "Voici les salles disponibles :\n"

	# On recupère chaque nom de fichier dans une ligne de notre tableau liste, et on évite les espaces
	liste=( $(ls -ap ./script | grep -v "/$" | sed -e 's/ /[SPACE]/g') )

	# Nombre de fichier dans la liste
	nb=$(echo ${#liste[*]})

	i=0

	while [ $i -lt $nb ]
	do
		# On affiche à l'utilisateur le nom des salles, et le nombre de machine
		salle=$(echo "${liste[i]}" | sed -e 's/.wol//' | sed -e 's/\[SPACE\]/ /g')
		echo -e " $(($i+1))) $salle ("$(cat "./script/$salle.wol" | egrep -v '^(#|$)' | wc -l)" postes)"
		total=$(($total + $(cat "./script/$salle.wol" | egrep -v '^(#|$)' | wc -l)))

		# On incrémente
		i=$(($i + 1))
	done

	echo -e "\n *) /!\ Toutes les salles ($total postes) /!\ \n"
	echo "Tapez exit pour quitter."

	while [ -z "$rep" ]
	do
		echo -en "\nQuel numéro de salle voulez vous réveiller ? "
		read rep

		if [ ! -z "$rep" ]
		then
			if [ "$rep" = "*" ]
			then
				while true
				do
					echo -n "Voulez-vous vraiment réveiller toutes les machines ? [oui/NON] "
					read confirme

					if [ -z "$confirme" ]
					then
						confirme=non
					fi

					if [ $confirme = "oui" ]
					then
						break
					elif [ $confirme = "non" ]
					then
						rep=
						break
					fi
				done
			elif [ "$rep" = "exit" ]
			then
				menu
				exit
			else
				# On récupère la salle par rapport au numéro
				rep=$(($rep - 1))
				salle=$(echo "${liste[$rep]}" | sed -e 's/\[SPACE\]/ /g')
				rep=$(($rep + 1))

				# Si la valeur rentree par l'utilisateur n'existe pas
				if [ ! -f ./script/"$salle" ]
				then
					echo "La salle numéro $rep n'existe pas ou son script n'a pas été créé !"
					logger "[WARNING] Impossible de lancer : ./script/$salle (n° $rep) !"

					# L'utilisateur ne quittera pas la boucle
					rep=
				fi
			fi
		fi
	done

	if [ $confirme = "oui" ]
	then
		logger "[INFO] Réveil de toutes les salles en cours..."
		echo -e "\nRetour de la commande :"

		rm -f ./tmp.wol

		# On crée le fichier temporaire contenant toutes les adresses MAC
		cat ./script/* > ./tmp.wol

		i=0
		
		# On exécute le script
		while [ $i -lt $repetition ]
		do
			# On affiche le résultat qu'une fois à l'écran
			if [ $i -lt 1 ]
			then
				$wol -f ./tmp.wol
			else
				$wol -f ./tmp.wol > /dev/null 2>&1
			fi
			
			i=$(($i + 1))
		done

		if [ $repetition -gt 1 ]
		then
			echo -e "\n(Les paquets ont été envoyés $repetition fois)"
		fi
		
		# On supprime le fichier temporaire
		rm -f ./tmp.wol

		echo -e "\nRéveil de toutes les salles effectués !"
		echo -n "Appuyez sur Entrée pour revenir au menu principal... "
		read
	else
		logger "[INFO] Réveil de la salle "$(echo "$salle" | sed -e 's/.wol//')" en cours..."
		echo -e "\nRetour de la commande :"

		i=0
		
		# On execute le script
		while [ $i -lt $repetition ]
		do
			# On affiche le résultat qu'une fois à l'écran
			if [ $i -lt 1 ]
			then
				$wol -f ./script/"$salle"
			else
				$wol -f ./script/"$salle" > /dev/null 2>&1
			fi
			
			i=$(($i + 1))
		done
		
		if [ $repetition -gt 1 ]
		then
			echo -e "\n(Les paquets ont été envoyés $repetition fois)"
		fi

		echo -e "\nRéveil de la salle "$(echo "$salle" | sed -e 's/.wol//')" effectué !"
		echo -n "Appuyez sur Entrée pour revenir au menu principal... "
		read
	fi
}

# Fonction pour afficher l'heure de démarrage automatique des salles
afficher () {
	clear

	fichier=

	echo -e "\nVous vous situez actuellement dans : $(pwd)\n"

	# On demande a l'utilisateur le fichier CSV à lire
	while [ -z "$fichier" ]
	do
		echo -n "Quel fichier .csv voulez-vous ouvrir ? [$csvdefaut] "
		read -e fichier

		# Si l'utilisateur veut sortir de ce menu
		if [ "$fichier" = "exit" ]
		then
			menu
			exit
		fi
		
		if [ -z "$fichier" ]
		then
			fichier="$csvdefaut"
		fi

		# Si le fichier renseigné par l'utilisateur est vide
		if [ ! -f "$fichier" ]
		then
			echo "Le fichier $fichier n'existe pas !"
			fichier=
		fi
	done

	logger "[INFO] Affichage des horaires du fichier $fichier"

	clear

	# On charge le fichier .csv dans les variables globales via la fonction
	charger_csv "$fichier"

	# On calcule le nombre de salle
	nb=$(cat "$fichier" | wc -l);

	i=0

	if [ $nb -gt 0 ]
	then
		# On affiche ce nombre à l'utilisateur
		echo -e "Il y a $nb salle(s) dans le fichier $fichier :\n"

		while [ $i -lt $nb ]
		do
			# On calcule l'heure lisible à partir du total des minutes
			heure=$(echo $((${tabhoraire[$i]}/60)))
			minute=$(echo $((${tabhoraire[$i]}%60)))

			# Si les minutes sont en dessous de 10, on rajoute un zéro devant
			if [ $minute -lt 10 ]
			then
				minute="0"$minute
			fi

			# Et on l'affiche à l'utilisateur
			echo -ne "\tSalle: ${tabsalle[$i]} -> "$heure"h$minute\n"

			i=$(($i + 1))
		done

		# On fait une ligne vide pour une meilleure lisibilité.
		if [ $i -gt 0 ]
		then
			echo ""
		fi
	else
		echo -e "Le fichier d'horaire est vide ! Aucun réveil de prevu.\n"
	fi

	# Et on laisse le temps à l'utilisateur de lire ce qu'il y a à l'écran
	echo -n "Appuyez sur Entrée pour continuer... "
	read null
}

# Fonction pour créer de nouveau script de salle
nouveau () {
	fichier=
	rep=

	clear

	while [ -z "$fichier" ]
	do
		echo -n "Quel nom voulez-vous donner au fichier (le nom dans le .csv) ? "
		read fichier
		
		# Si l'utilisateur veut quitter ce menu
		if [ "$fichier" = "exit" ]
		then
			menu
			exit
		fi

		# Si le fichier renseigne par l'utilisateur existe déjà
		if [ -f "script/$fichier.wol" ]
		then
			while true
			do
				echo -n "Le fichier existe déjà, voulez-vous l'écraser ? [oui/NON] "
				read rep
				
				# Si l'utilisateur veut quitter ce menu
				if [ "$rep" = "exit" ]
				then
					menu
					exit
				fi

				if [ -z "$rep" ]
				then
					rep=non
				fi

				# On récupère la réponse en minuscule
				rep=$(echo $rep | tr [A-Z] [a-z])

				if [ "$rep" = "non" ]
				then
					# L'utilisateur reste dans la boucle (mais quitte celle de cette question), et doit préciser un nouveau nom
					fichier=
					break
				elif [ "$rep" = "oui" ]
				then
					break
				fi
			done
		fi
	done

	while true
	do
		rep=

		while true
		do
			echo -ne "\nVoulez-vous ouvrir nano pour copier le texte à filtrer contenant les adresses MAC, ou renseigner une URL de fichier ? [NANO/url] ? "
			read rep
			
			# Si l'utilisateur veut quitter ce menu
			if [ "$rep" = "exit" ]
			then
				menu
				exit
			fi

			# Si la reponse est vide, alors celle par defaut (nano) sera prit en compte
			if [ -z "$rep" ]
			then 
				rep=nano
			fi

			# On recupère la réponse en minuscule
			rep=$(echo $rep | tr [A-Z] [a-z])

			if [ "$rep" = "nano" ]
			then
				break
			elif [ "$rep" = "url" ]
			then
				break
			fi
		done

		# On supprime un ancien fichier temporaire si jamais il existe
		rm -f "$fichier.tmp" >> /dev/null

		if [ "$rep" = "nano" ]
		then
			echo -e "\nNano va s'ouvrir, copiez le contenu d'un fichier contenant les adresses MAC, elles-y seront automatiquement extraites.\nVous pouvez aussi directement inscrire les adresses MAC.\n\nN'oubliez pas de faire Ctrl+O pour enregistrer !\n"
			echo -n "Appuyez sur Entrée pour continuer... "
			read

			# On ouvre nano sur le fichier temporaire qui va nous servir pour le filtrage
			nano "$fichier.tmp"
		else
			echo -e "Vous vous situez actuellement dans : $(pwd)\n"

			while true
			do
				echo -n "Quel est l'URL du fichier ? "

				# L'option -e permet d'accepter l'auto-completion (tabulation)
				read -e url
				
				# Si l'utilisateur veut quitter ce menu
				if [ "$url" = "exit" ]
				then
					menu
					exit
				fi

				# Si le fichier precisé n'existe pas
				if [ ! -f "$url" ]
				then
					echo "Le fichier $url n'existe pas !"
				else
					# On copie le fichier precisé en tant que fichier temporaire
					cp "$url" "./$fichier.tmp"
					break
				fi
			done
		fi

		# Variable servant savoir si le fichier est vide ou pas
		vide=true

		# On transforme tout les tirets point des double-points (pour récuperer les adresses MAC avec tirets)
		sed -i 's/\-/:/g' "$fichier.tmp"

		# On compte le nombre de ligne du fichier
		ligne=$(cat "$fichier".tmp | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}' | wc -l)

		# Si il y au moins une ligne
		if [ $ligne -gt 0 ]
		then
			clear

			echo -e "Voici le contenu filtré du fichier : \n"

			# On affiche les adresses MAC qui sont dans le fichier
			cat "$fichier".tmp | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}'

			rep=

			while true
			do
				echo -en "\nCela vous semble correct ? [OUI/non] "
				read rep
				
				# Si l'utilisateur veut quitter ce menu
				if [ "$rep" = "exit" ]
				then
					menu
					exit
				fi

				if [ -z "$rep" ]
				then
					rep=oui
				fi

				# On récupère la réponse en minuscule
				rep=$(echo $rep | tr [A-Z] [a-z])

				if [ "$rep" = "non" ]
				then
					# L'utilisateur va devoir repréciser une URL ou reremplir nano
					break
				elif [ "$rep" = "oui" ]
				then
					# Le fichier va etre écrit.
					vide=false
					break
				fi

				echo -n "Valeur incorrecte !"
			done
		else
			rm -f "$fichier.tmp"

			echo -e "\nErreur, aucune adresse MAC trouvée dans ce fichier !"
			echo "Appuyez sur la touche Entrée pour continuer... "
			read
		fi

		# Si le fichier n'est pas vide, on quitte cette boucle
		if [ $vide = false ]
		then
			break
		fi
	done

	logger "[INFO] Création du fichier de script : $fichier.wol"

	# On écrit le fichier dans le dossier script
	cat "$fichier".tmp | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}' > script/"$fichier.wol"

	# On supprime le fichier temporaire
	rm -f "$fichier.tmp" >> /dev/null

	echo -en "\nEcriture du script terminée !\nAppuyer sur Entrée pour retourner au menu... "
	read
}

logger "[INFO] Démarrage du script..."
logger "[INFO] Exécution dans : $(pwd)"

# Si le dossier des scripts n'existe pas (Premiere utilisation du script)
if [ ! -x ./script ]
then
	logger "[INFO] Création du dossier ./script"
	mkdir ./script
fi

if [ ! -z $1 ]
then
	# Si c'est un lancement automatique du script
	if [ $1 = '--auto' ]
	then
		logger "[INFO] Exécution automatique du script"
		
		if [ "$externe_automatique" = "true" ]
		then
			logger "[INFO] Régéneration des horaires automatique"

			$commande_externe 2>&1
			
			if [ $(echo $?) -gt 0 ]
			then
				logger "[WARNING] Une erreur s'est produite durant la régéneration"
			fi
		fi

		# On fait appel a la fonction pour charger le fichier CSV
		if [ ! -z ${2:-f} ] && [ ${2:-f} = "-f" ]
		then
			if [ ! -z "$3" ]
			then
				if [ -f "$3" ]
				then
					# On charge le fichier CSV donné en paramètre du script via la fonction
					charger_csv "$3"
				else
					logger "[WARNING] Fichier $3 inexistant ! Chargement du fichier par défaut..."

					# On charge le fichier par défaut du script
					charger_csv ""
				fi
			else
				logger "[WARNING] Paramètre incorrect, chargement du fichier par défaut..."

				charger_csv ""
			fi
		else
			charger_csv ""
		fi

		# On vérifie que les deux tableaux obtenus sont de la même taille, sinon on arrête tout
		if [ ${#tabsalle[*]} -eq ${#tabhoraire[*]} ]
		then
			nb=$(echo ${#tabsalle[*]});
		else
			logger "[ERROR] Arrêt du script : Incohérence dans le tableau"
			exit
		fi

		i=0
		j=0

		# On calcul le temps actuel en minute
		tempsminute=$(($(($(date +"%-k") * 60)) + $(date +%-M)))

		# Si on a active l'option pour réveiller quoi qu'il se passe toute les salles
		if [ $forcerreveiltotal = "true" ]
		then
			tempsminute=0
			delai=3600
		fi

		resultat[0]=""

		logger "[INFO] Minutes actuelles : $tempsminute (marge de "$delai"min)"	

		# On regarde si il y a des salles a réveiller
		while [ $i -lt $nb ]
		do
			if [ $(($tempsminute + $delai)) -ge ${tabhoraire[$i]} ] && [ $tempsminute -le ${tabhoraire[$i]} ]
			then
				# On récupère les salles à réveiller
				resultat[j]=${tabsalle[$i]}
				j=$(($j + 1))
			fi

			i=$(($i + 1))
		done

		logger "[INFO] $j salle(s) à réveiller"

		# Si il y a des salles à réveiller
		if [ $j -gt 0 ]
		then
			# On les logs
			logger "[INFO] Salle(s) à réveiller : ${resultat[*]}"

			i=0
			err=0

			# Et on les réveille
			while [ $i -lt $j ]
			do
				logger "[INFO] Exécution de $wol -f script/${resultat[i]}.wol ..."

				# Si le fichier existe
				if [ -f script/"${resultat[i]}.wol" ]
				then
					i=0
					
					while [ $i -lt $repetition ]
					do
						# On affiche le résultat qu'une fois dans les logs
						if [ $i -lt 1 ]
						then
							$wol -f "script/${resultat[i]}.wol" 2> /dev/null | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}' | sed -e "s/^/[$(echo $(date +"%x %X")| sed "s/\//\\\\\//g")] [DEBUG] Reveil de /g" >> $fichierlog
						else
							$wol -f "script/${resultat[i]}.wol" > /dev/null 2>&1
						fi
						
						i=$(($i + 1))
					done
					
					if [ $repetition -gt 1 ]
					then
						logger "[INFO] Les paquets ont ete envoyés $repetition fois"
					fi
				
					if [ ! $? -eq 0 ]
					then
						logger "[WARNING] Une erreur s'est produite durant l'exécution !"
						err=$(($err + 1))
					fi
				else
					logger "[WARNING] le fichier ${resultat[i]}.wol n'existe pas !"
					err=$(($err + 1))
				fi

				i=$(($i + 1))
			done

			if [ -z $err ]
			then
				logger "[INFO] Exécution(s) terminée(s) avec succès !"
			else
				logger "[WARNING] Exécution(s) terminée(s) avec erreur(s) !"
			fi

			logger "[WARNING] $(($j - $err))/$j commandes effectuées avec succès !"

			# Fin du script automatique
			logger "[INFO] Arrêt du script : Script terminé"
		else
			logger "[INFO] Arrêt du script : Rien à faire"
		fi
	else
		# Si il y a un probleme d'argument
		logger "[ERROR] Arrêt du script : Mauvais arguments"

		echo -e "Arguments invalides !\n"
		echo "Vous pouvez utilisez les arguments tel que :"
		echo " --auto :              Pour un lancement de script automatisé"
		echo " --auto -f <fichier> : Pour specifier un fichier .csv"
		echo ""
		echo "Vous pouvez aller modifier l'entête du script pour modifier"
		echo "quelques paramètres suplémentaires (dans le cadre dédié)."
	fi
else
	# Exécution en manuel, avec une UI
	logger "[INFO] Exécution manuelle du script"

	# On appelle la fonction menu
	menu

	logger "[INFO] Arrêt du script : Script terminé"
	exit
fi

## Fin du script
