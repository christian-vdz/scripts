
Apache website managing script
===========

Bash script to manage Apache website configuration easily.
The script allows vHost creation, deletion and listing.
The script uses Let's Encrypt to provide SSL certificates on the websites.

## Requirements ##

- Apache2, PHP, etc.
- Certbot
- pwgen

## Installation ##

1. Download script
```bash
$ wget -O website-manager https://raw.githubusercontent.com/christian-vdz/scripts/main/apache-website-manager/website-manager.sh
```
3. Apply permission to execute:
```
$ chmod +x /path/to/website-manager.sh
```
3. Optional: if you want to use the script globally, then you need to copy the file to your /usr/bin directory
```bash
$ sudo cp /path/to/website-manager.sh /usr/bin/website-manager
```

### For Global Shortcut ###

```bash
$ cd /usr/bin
$ wget -O website-manager https://raw.githubusercontent.com/christian-vdz/scripts/main/apache-website-manager/website-manager.sh
$ chmod +x website-manager
```

## Usage ##

Basic command line syntax:
```bash
# sh /path/to/website-manager [OPTIONS]
```

With script installed on /usr/bin
```bash
# website-manager [OPTIONS]
```

### Options ###

```
-c / -create     <domain>        create website
-r / -remove     <domain>        remove website
-d / -database   <dbname>        create or delete database with website
-u / -user       <username>      create or delete user with website
-s / -secure                     request SSL certificate from Let's Encrypt
-l / -list                       list active websites
-h / -help                       display this help message\n
```

### Examples ###

Create a website:
```bash
website-manager -c newsite.dev
```
Create secure website & SFTP user:
```bash
website-manager -c jack.dev -u jack -s
```
Create website with database & user:
```bash
website-manager -c jack.dev -d jacksdatabase -u jack -s
```

Delete website:
```bash
website-manager -r oldsite.dev
```
Delete site, database & user
```bash
website-manager -r jack.dev -d jacksdatabase -u jack
```
