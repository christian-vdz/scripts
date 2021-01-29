#!/bin/bash
### Setting variables and default parameters
webDir='/var/www/'
email='email@domain.tld'
websiteList='/var/www/websiteList.txt'
sitesAvailable='/etc/apache2/sites-available/'
apacheUser=$(ps -ef | egrep '(httpd|apache2|apache)' | grep -v root | head -n1 | awk '{print $1}')

# Some functions
function showHelp() {
    echo -e "
Script by Christian VDZ (https://twitter.com/christianvdz)
Usage: website-manager [OPTIONS]\n
Options:
    -c / -create     <domain>        create website
    -r / -remove     <domain>        remove website
    -d / -database   <dbname>        create or delete database with website
    -u / -user       <username>      create or delete user with website
    -s / -secure                     request SSL certificate from Let's Encrypt
    -l / -list                       list active websites
    -h / -help                       display this help message\n
Exemples:
  Create a website:
    website-manager -c newsite.dev
  Create secure website & SFTP user:
    website-manager -c jack.dev -u jack -s
  Create website with database & user:
    website-manager -c jack.dev -d jacksdatabase -u jack -s\n
  Delete website:
    website-manager -r oldsite.dev
  Delete site and SFTP user:
    website-manager -r jack.dev -u jack\n"
    if [ -n "$1" ]; then 
        echo -e $1
    fi
}
function listWebsites() {
    showHelp
    echo -e $"- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -\nSite list :"
    if [ -r $websiteList ]; then
        cat $websiteList
    fi
    echo -e "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    exit 0
}
function ifStringStartWithDash() {
    if [[ $1 = -* ]]; then
        showHelp "Please provide $2.\n"
        exit 0
    fi
}
function ifInvalidDomain() {
    domainRegex='^[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]\.[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$'
    if ! [[ $1 =~ $domainRegex ]]; then
        showHelp "Domain $1 is not valid.\nPlease provide a correct domain name.\n"
        exit 0
    fi
}
function ifWebsiteExists() {
    sitesAvailabledomain=$sitesAvailable$1.conf
    if [ -e $sitesAvailabledomain ]; then
        return 1
    else
        return 0
    fi
}
function showFinishMessage() {
    echo -e $"- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -\nComplete! $2\n- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    if [ "$1" == "creation" ]; then
        echo -e $"Host:      $domain\nPort:      22\nUser:      $username"
        if [ "$newuser" == '1' ]; then
            echo -e $"Password:  $passwd"
        fi
        if [ -n "$dbname" ]; then
            echo -e "\nDatabase:  $dbname\nDB user:   $dbuser\nPassword:  $passwd"
        fi
        echo -e "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    fi
}
# Exit if user isn't root
if [ "$(whoami)" != 'root' ]; then
    showHelp "You have no permission to run $0 as non-root user. Use sudo\n"
    exit 1
fi

clear
if [ -z "$1" ] ||[ "$1" == "--help" ]; then
    showHelp
    exit 0
fi

# Parse options to the 'website-manager' command
while getopts ":hlc:r:" opt; do
    case ${opt} in
        h) showHelp
            exit 0 ;;
        l) listWebsites ;;
        c)  
            domain="$2"
            ifStringStartWithDash $domain "a domain name"
            ifInvalidDomain $domain
            ifWebsiteExists $domain
            if [[ $? -eq 1 ]]; then
                showHelp "Website $domain already exists.\n"
                exit 1
            fi
            #  Getting suboptions
            while getopts ":su:d:" opt; do
                case ${opt} in
                    s) ssl="y" ;;
                    d) ifStringStartWithDash $OPTARG "a database name"
                        dbname="$OPTARG" ;;
                    u) ifStringStartWithDash $OPTARG "an username" 
                        username="$OPTARG" ;;
                    \?) showHelp "Option -$OPTARG not recognized.\n" 1>&2
                        exit 1 ;;
                    : ) showHelp "Option -$OPTARG requires an argument.\n" 1>&2
                        exit 1 ;;
                esac
            done
            showHelp
            # Setting vars for website creation
            rootDir=$webDir$domain
            webRootDir=$rootDir/htdocs
            webLogDir=$rootDir/logs
            passwd=$(pwgen -s 15 1)
            # Check if website directory exists
            if ! [ -d $rootDir ]; then
                ### Create the directory
                mkdir -p $rootDir $webRootDir $webLogDir
                # Setting permissions on directory
                chmod 750 $rootDir $webRootDir $webLogDir
                chmod g+s $rootDir $webRootDir $webLogDir

                ### Write file in the new domain directory
                if ! echo "<html><meta charset="utf-8">Welcome to $domain.</html>" > $webRootDir/index.html
                then
                    echo $"ERROR: Not able to write in file $webRootDir/index.html. Please check permissions\n"
                    exit 1
                fi
                echo "<?php echo phpinfo(); ?>" > $webRootDir/phpinfo.php
            fi
            ### Create virtual host file
            echo -e $"- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -\nCreating website $domain\n"
            if ! echo "
            <VirtualHost *:80>
                ServerAdmin $email
                ServerName $domain
                ServerAlias $domain
                DocumentRoot $webRootDir/
                <Directory />
                    AllowOverride All
                </Directory>
                <Directory $webRootDir>
                    Options Indexes FollowSymLinks MultiViews
                    AllowOverride all
                    Require all granted
                </Directory>
                LogLevel error
                ErrorLog $webLogDir/$domain-error.log
                CustomLog $webLogDir/$domain-access.log combined
            </VirtualHost>" > $sitesAvailabledomain
            then
                echo -e $"There is an ERROR creating $domain file\n"
                exit 1
            else
                echo -e $"Creating new vHost at $sitesAvailabledomain\n"
            fi
            # Add domain in /etc/hosts
            if ! echo "127.0.0.1	$domain" >> /etc/hosts
            then
                echo $"ERROR: Not able to write in /etc/hosts\n"
                exit 1
            else
                echo -e $"Adding $domain to /etc/hosts\n"
            fi

            ### Enable website and restart Apache
            a2ensite $domain &>/dev/null
            systemctl reload apache2
            
            if [ "$ssl" == "y" ]; then
                ### Requesting SSL certificate from Let's Encrypt
                certbot --apache --redirect -n -d $domain
            fi
            
            if [ -n "$dbname" ]; then
                if [ -n "$username" ]; then
                    dbuser=dbu-$username
                else
                    dbuser="dbu-${domain//./}"
                fi
                # Creating database and user
                Q1="CREATE DATABASE IF NOT EXISTS $dbname;"
                Q2="GRANT ALL ON $dbname.* TO '$dbuser'@'localhost' IDENTIFIED BY '$passwd';"
                Q3="FLUSH PRIVILEGES;"
                SQL="${Q1}${Q2}${Q3}"
                echo -e $"Creating database $dbname with user $dbuser\n"
                mysql -u root -e "$SQL"
            fi

            if [ -n "$username" ]; then
                ### Setting directory owner to new user
                if [ "$username" != "" ]; then
                    if id "$username" &>/dev/null; then
                        newuser=0
                        echo -e $"User $username already exists\n"
                    else
                        echo -e $"Creating user $username\n"
                        useradd -m -d $rootDir $username &>/dev/null
                        echo -e "$passwd\n$passwd" | passwd $username &>/dev/null
                        newuser='1'
                    fi
                    chown -R $username:$apacheUser $rootDir
                fi
            else
                ### Setting directory owner to active user
                username=$(whoami)
                if [ "$username" == "root" ]; then
                    chown -R $apacheUser:$apacheUser $rootDir
                else
                    chown -R $username:$username $rootDir
                fi
            fi
                        
            # Adding website and information to website list file
            echo -e "$domain owned by $username $rootDir | $(date +"%d/%m/%Y %T")" >> $websiteList
            if [ -n $dbname ]; then 
                echo -e "$domain has database $dbname owner by $dbuser" >> $websiteList
            fi
            showFinishMessage "creation" "You now have a new host : http://$domain"
            exit 0
        ;;
        r)
            domain="$2"
            rootDir=$webDir$domain
            ifStringStartWithDash $domain "domain name"
            ifInvalidDomain $domain
            ifWebsiteExists $domain
            if [[ $? -eq 0 ]]; then
                showHelp "Website $domain does not exists.\n"
                exit 1
            fi
            #  Getting suboptions
            while getopts ":u:d:" opt; do
                case ${opt} in
                    u) ifStringStartWithDash $OPTARG "an username"
                        username="$OPTARG" ;;
                    d) ifStringStartWithDash $OPTARG "a database name"
                        dbname="$OPTARG" ;;
                    \?) showHelp "Option -$OPTARG not recognized.\n" 1>&2
                        exit 1 ;;
                    : ) showHelp "Option -$OPTARG requires an argument.\n" 1>&2
                        exit 1 ;;
                esac
            done
            showHelp
            echo -e $"- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -\nRemoving website $domain\n"
            ### Delete domain in /etc/hosts and in the website list
            newhost=${domain//./\\.}
            sed -i "/$newhost/d" /etc/hosts
            sed -i "/$newhost/d" $websiteList
            
            ### Disable and delete virtual host files
            a2dissite $domain &>/dev/null
            rm $sitesAvailabledomain
            if [ -e $sitesAvailable/$domain-le-ssl.conf ]; then
                rm -rf $sitesAvailable/$domain-le-ssl.conf /etc/letsencrypt/live/$domain /etc/letsencrypt/renewal/$domain /etc/letsencrypt/archive/$domain
                a2dissite $domain-le-ssl &>/dev/null
            fi
            echo -e $"Disabling site $domain\n"
            ### Restart Apache
            systemctl reload apache2

            ### Check if directory exists
            if [ -d $rootDir ]; then
                read -p "Remove website directory ? (y/n) " deldir

                if [ "$deldir" == 'y' -o "$deldir" == 'Y' ]; then
                    ### Removing directory
                    rm -rf $rootDir
                    echo -e $"\nRemoving $domain's directory\n"
                else
                    echo -e $"\nWebsite directory conserved\n"
                fi
            else
                echo -e $"\nWebsite directory not found. Ignored\n"
            fi

            if [ -n "$dbname" ]; then
                if [ -n "$username" ]; then
                    dbuser=dbu-$username
                else
                    dbuser="dbu-${domain//./}"
                fi
                read -p "Delete database and user account ? (y/n) " deldb
                if [ "$deldb" == 'y' -o "$deldb" == 'Y' ]; then
                    # Removing database and user
                    Q1="DROP DATABASE IF EXISTS $dbname;"
                    Q2="DROP USER IF EXISTS '$dbuser'@'localhost';"
                    SQL="${Q1}${Q2}"
                    mysql -u root -e "$SQL"
                    echo -e $"\nRemoving database $dbname and user $dbuser\n"
                fi
            fi

            if [ -n "$username" ]; then
                # If owner isn't root, check if owner account exists
                if ! [ "$username" == "root" ]; then
                    if id "$username" &>/dev/null; then
                        read -p "Delete user account ? (y/n) " deluser
                        if [ "$deluser" == 'y' -o "$deluser" == 'Y' ]; then
                            # Delete owners user account
                            userdel $username
                            echo -e $"\nDeleting user account\n"
                        fi
                    fi
                fi
            showFinishMessage "deletion" "You just removed website : $domain"
            fi
            exit 0
        ;;
        \?) showHelp "Option -$OPTARG not recognized.\n" 1>&2
            exit 1 ;;
        : ) showHelp "Option -$OPTARG requires an argument.\n" 1>&2
            exit 1 ;;
    esac
done
showHelp