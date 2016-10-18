#!/usr/bin/env sh

#set -x

# This program is free software published under the terms of the GNU GPL.
#
# Forked: http://picoforge.int-evry.fr/websvn/filedetails.php?repname=curlmyback&path=%2Ftrunk%2Fcurl-backup-phpmyadmin.sh&rev=0&sc=1 
# (C) Institut TELECOM + Olivier Berger <olivier.berger@it-sudparis.eu> 2007-2009
# $Id: curl-backup-phpmyadmin.sh 12 2011-12-12 16:02:44Z berger_o $

# Clean up and add parameter handling by Artem Grebenkin
# <speechkey@gmail.com> http://www.irepository.net
#
# Script now consistenly in bash-style (was broken on my system using /bin/sh)
# Adapted post_params to comply with current phpmyadmin installations
# Added functionality: all compression offered by phpmyadmin, curl option passing
# 2013 Tobias Küchel <devel@zukuul.de>
#
# Script consistently in POSIX shell style (bash style is not portable)
# Adjusted to work with phpMyAdmin 4.6.4
# 2016 Edward Akerboom <edward@infostreams.net>
#
# Optional: This saves dumps of your Database using CURL and connecting to
# phpMyAdmin (via HTTPS), keeping the 10 latest backups by default
#
# Tested on phpMyAdmin 4.6.4, 3.5.1 and 3.4.10.1
#
# For those interested in debugging/adapting this script, the firefox
# add-on LiveHttpHeaders is a very interesting extension to debug HTTP
# transactions and guess what's needed to develop such a CURL-based
# script.
#
# Please adapt these values :

MKTEMP=mktemp
TMP_FOLDER=/tmp
COMPRESSION=none
USE_KEYCHAIN=0
DEBUG=0

## following values will be overwritten by command line arguments
STDOUT=
ONLY_LOGIN=0
DB_TABLES=
ADD_DROP=0
APACHE_USER=
APACHE_PASSWD=
PHPMYADMIN_USER=
PHPMYADMIN_PASSWD=
DATABASE=
REMOTE_HOST=
# End of customisations


## debugging function
decho()
{
    [ $DEBUG -eq 1 ] && echo "$@"
}

usage()
{
   cat << EOF
Arguments: mysql-export.sh [-h|--help] [--stdout] [--tables=<table_name>,<table_name>,...] 
                           [--compression=none|gzip|bzip2|zip] [--add-drop] 
                           [--apache-user=<apache_http_user>] [--apache-password=<apache_http_password>] 
                           [--phpmyadmin-user=<phpmyadmin_user>] [--phpmyadmin-password=<phpmyadmin_password>] 
                           [--database=<database>] [--host=<phpmyadmin_host>] [--use-keychain] 
                           -- [curl_options]
       -h, --help: Print help
       --only-login: Only login, don't actually export anything
       --stdout: Write SQL (gzipped) in stdout
       --tables=<T1>,<T2>,..: Export only particular tables
       --compression: Turn compression off (none) or use gzip, bzip2 (default) or zip
       --add-drop: add DROP TABLE IF EXISTS to every exporting table
       --apache-user=<apache_http_user>: Apache HTTP autorization user
       --apache-password=<apache_http_password>: Apache HTTP autorization password 
       --phpmyadmin-user=<phpmyadmin_user>: PhpMyAdmin user *
       --phpmyadmin-password=<phpmyadmin_password>: PhpMyAdmin password *
       --database=<database>: Database to be exported *
       --host=<phpmyadmin_host>: PhpMyAdmin host *
       --use-keychain: Use Mac OS X keychain to get passwords from.
         In that case --apache-password and --phpmyadmin-password will be used 
         as account name for search in Mac Os X keychain. 

       * You need to set at least those parameters on the command line or in the script

       --  [curl_options] Options may be passed to every curl command (e.g. http_proxy)

 Common uses: mysql-export.sh --tables=hotel_content_provider --add-drop --database=hs --stdout --use-keychain --apache-user=betatester --phpmyadmin-user=hs --apache-password=www.example.com\ \(me\) --phpmyadmin-password=phpmyadmin.example.com --host=https://www.example.com/phpmyadmin | gunzip | mysql -u root -p testtable

  This exports and imports on the fly into local db
EOF
}

curloptions=0
curlopts=""
for arg in "$@"
do
  case $arg in
    --stdout)
      STDOUT=1
      ;;
    --tables*)
      DB_TABLES=$(echo "$arg" | cut -d "=" -f 2 | xargs)
      ;;
    --compression*)
      COMPRESSION=$(echo "$arg" | cut -d "=" -f 2 | xargs)
      ;;
    --add-drop)
      ADD_DROP=1
      ;;
    --apache-user*)
      APACHE_USER=$(echo "$arg" | cut -d "=" -f 2 | xargs)
      ;;
    --apache-password*)
      APACHE_PASSWD=$(echo "$arg" | cut -d "=" -f 2 | xargs)
      ;;
    --phpmyadmin-user*)
      PHPMYADMIN_USER=$(echo "$arg" | cut -d "=" -f 2 | xargs)
      ;;
    --phpmyadmin-password*)
      PHPMYADMIN_PASSWD=$(echo "$arg" | cut -d "=" -f 2 | xargs)
      ;;
    --database*)
      DATABASE=$(echo "$arg" | cut -d "=" -f 2 | xargs)
      ;;
    --host*)
      REMOTE_HOST=$(echo "$arg" | cut -d "=" -f 2 | xargs)
      ;;
    --use-keychain)
      USE_KEYCHAIN=1
      ;;
    --only-login)
      ONLY_LOGIN=1
      ;;
    --)
      curloptions=1
      ;;
    *)
      if [ $curloptions -eq 1 ]; then
        curlopts+=" $arg"
      else
        usage
        exit 0
      fi
      ;;
  esac
done
curlopts="${curlopts} -s -k -L"
decho "Curl options: $curlopts"

# is APACHE auth really necessary?
#[ -z "$APACHE_USER" -o -z "$APACHE_PASSWD" ] && usage && exit 1
#if [ -z "$PHPMYADMIN_USER" -o -z "$PHPMYADMIN_PASSWD" ];
if [ -z "$DATABASE" ] || [ -z "$REMOTE_HOST" ];
then
    usage
    exit 1
fi

## not tested (01.03.13)
if [ $USE_KEYCHAIN -eq 1 ]
then
  APACHE_PASSWD=$(security 2>&1 >/dev/null find-internet-password -gs $APACHE_PASSWD | sed -e 's/password: "\(.*\)"/\1/g')
  PHPMYADMIN_PASSWD=$(security 2>&1 >/dev/null find-internet-password -g -l $PHPMYADMIN_PASSWD | sed -e 's/password: "\(.*\)"/\1/g')
fi

## which mktemp to use
mkdir -p $TMP_FOLDER || exit 1
if [ "$MKTEMP" = "mktemp" ]; then
    result=$(`which mktemp`)
    decho TEMP: $result
fi
if [ "$MKTEMP" = "tempfile" ]; then
    result=$(`which tempfile` -d "$TMP_FOLDER")
    decho TEMP: $result
fi

greater_than_or_equal() {
    python - "$1" "$2" << EOF
import sys
from distutils.version import LooseVersion as LV
if (LV(sys.argv[1]) >= LV(sys.argv[2])):
  sys.exit(0)
else:
  sys.exit(1)
EOF
}

###############################################################
#
# First login and fetch the cookie which will be used later
#
###############################################################

apache_auth_params="--anyauth -u$APACHE_USER:$APACHE_PASSWD"

curl $curlopts -D "$TMP_FOLDER/curl.headers" -c "$TMP_FOLDER/cookies.txt" $apache_auth_params "$REMOTE_HOST/index.php" > "$result"
#    token=$(grep 'token\ =' $result | sed "s/.*token\ =\ '//;s/';$//" )
#    token=$(grep link $result | grep '\?token=' | grep token | sed "s/^.*token=//" | sed "s/&.*//" )

PMA_VERSION=$(grep -o 'PMA_VERSION.*,' "$result" | cut -d '"' -f 2 | xargs)
export_script="export.php"


IS_PMA_4=0
greater_than_or_equal $PMA_VERSION 4.0
if [ $? -eq 0 ]; then
  IS_PMA_4=1
  token=$(grep link "$result" | grep -o '[^a-zA-Z]token\=[0-9a-fA-F]*' | cut -d "=" -f 2 | head -n 1) # works for 4.6.4
else
  token=$(grep link "$result" | grep '\?token=' | grep token | sed "s/^.*token=//" | sed "s/&.*//" ) # from previous code
fi

cookie=$(cat "$TMP_FOLDER/cookies.txt" | cut  -f 6-7 | grep phpMyAdmin | cut -f 2)

entry_params="-d \"phpMyAdmin=$cookie&pma_username=$PHPMYADMIN_USER&pma_password=$PHPMYADMIN_PASSWD&server=1&lang=en-utf-8&convcharset=utf-8&collation_connection=utf8_general_ci&token=$token&input_go=Go\""
decho Apache login: $apache_auth_params
decho PhpMyadmin login: $entry_params
decho Token: $token
decho Cookie: $cookie
## Try to log in with PhpMyAdmin username and password showing errors if it fails
curl $curlopts -S -D "$TMP_FOLDER/curl.headers" -b "$TMP_FOLDER/cookies.txt" -c "$TMP_FOLDER/cookies.txt" $apache_auth_params $entry_params "$REMOTE_HOST/index.php" > "$result"
## did it fail?
if [ $? -ne 0 ]; then
    echo "Curl Error on : curl $opts" >&2
    exit 1
fi
## Was the http-request unsuccessful?
grep -q "HTTP/1.1 200 OK" "$TMP_FOLDER/curl.headers"
if [ $? -ne 0 ]; then
    echo "Error : couldn't login to phpMyadmin on $REMOTE_HOST/index.php" >&2
    grep "HTTP/1.1 " "$TMP_FOLDER/curl.headers" >&2
    exit 1
fi

has_login=$(cat "$result" | grep login_form | wc -l | xargs)
if [ $has_login -gt 0 ]; then
  # Could not login
  echo "Error: couldn't login to phpMyadmin on $REMOTE_HOST/index.php" >&2
  exit 1
fi

if [ $ONLY_LOGIN -eq 1 ]; then
  # Did login
  exit 0
fi



if [ $IS_PMA_4 -eq 1 ]; then
  token=$(grep link "$result" | grep -o '[^a-zA-Z]token\=[0-9a-fA-F]*' | cut -d "=" -f 2 | head -n 1) # works for 4.6.4
else
  token=$(grep link "$result" | grep '\?token=' | grep token | sed "s/^.*token=//" | sed "s/&.*//" ) # from previous code
fi

## prepare the post-parameters
post_params="token=${token}"
## later: post_params="${post_params}&export_type=server"
post_params="${post_params}&export_method=quick"
post_params="${post_params}&quick_or_custom=custom"
## later: post_params="${post_params}&db_select%5B%5D=$DATABASE"
post_params="${post_params}&output_format=sendit"
## later: post_params="${post_params}&filename_template=%40SERVER%40" 
post_params="${post_params}&remember_template=on"
if [ $IS_PMA_4 -eq 1 ]; then
  post_params="${post_params}&charset=utf-8"
else
  post_params="${post_params}&charset_of_file=utf-8"
fi
## later: post_params="${post_params}&compression=none"
post_params="${post_params}&what=sql"
post_params="${post_params}&codegen_structure_or_data=data"
post_params="${post_params}&codegen_format=0"
post_params="${post_params}&csv_separator=%2C"
post_params="${post_params}&csv_enclosed=%22"
post_params="${post_params}&csv_escaped=%22"
post_params="${post_params}&csv_terminated=AUTO"
post_params="${post_params}&csv_null=NULL"
post_params="${post_params}&csv_structure_or_data=data"
post_params="${post_params}&excel_null=NULL"
post_params="${post_params}&excel_edition=win"
post_params="${post_params}&excel_structure_or_data=data"
post_params="${post_params}&htmlword_structure_or_data=structure_and_data"
post_params="${post_params}&htmlword_null=NULL"
post_params="${post_params}&json_structure_or_data=data"
post_params="${post_params}&latex_caption=something"
post_params="${post_params}&latex_structure_or_data=structure_and_data"
post_params="${post_params}&latex_structure_caption=Structure+of+table+%40TABLE%40"
post_params="${post_params}&latex_structure_continued_caption=Structure+of+table+%40TABLE%40+%28continued%29"
post_params="${post_params}&latex_structure_label=tab%3A%40TABLE%40-structure"
post_params="${post_params}&latex_comments=something"
post_params="${post_params}&latex_columns=something"
post_params="${post_params}&latex_data_caption=Content+of+table+%40TABLE%40"
post_params="${post_params}&latex_data_continued_caption=Content+of+table+%40TABLE%40+%28continued%29"
post_params="${post_params}&latex_data_label=tab%3A%40TABLE%40-data"
post_params="${post_params}&latex_null=%5Ctextit%7BNULL%7D"
if [ $IS_PMA_4 -eq 1 ]; then
  post_params="${post_params}&maxsize="
  post_params="${post_params}&mediawiki_caption=something"
  post_params="${post_params}&mediawiki_headers=something"
  post_params="${post_params}&mediawiki_structure_or_data=structure_and_data"
else
  post_params="${post_params}&mediawiki_structure_or_data=data"
fi
post_params="${post_params}&ods_null=NULL"
post_params="${post_params}&ods_structure_or_data=data"
post_params="${post_params}&odt_structure_or_data=structure_and_data"
post_params="${post_params}&odt_comments=something"
post_params="${post_params}&odt_columns=something"
post_params="${post_params}&odt_null=NULL"
post_params="${post_params}&pdf_report_title="
if [ $IS_PMA_4 -eq 1 ]; then
  post_params="${post_params}&pdf_structure_or_data=structure_and_data"
  post_params="${post_params}&phparray_structure_or_data=data"
else
  post_params="${post_params}&pdf_structure_or_data=data"
  post_params="${post_params}&php_array_structure_or_data=data"
fi
post_params="${post_params}&sql_include_comments=something"
post_params="${post_params}&sql_header_comment="
post_params="${post_params}&sql_compatibility=NONE"
post_params="${post_params}&sql_structure_or_data=structure_and_data"
post_params="${post_params}&sql_procedure_function=something"
if [ $IS_PMA_4 -eq 1 ]; then
  post_params="${post_params}&sql_create_table=something"
  post_params="${post_params}&sql_create_trigger=something"
  post_params="${post_params}&sql_create_view=something"
else
  post_params="${post_params}&sql_create_table_statements=something"
  post_params="${post_params}&sql_if_not_exists=something" # not in PMA4
fi
if [ $IS_PMA_4 -eq 1 ]; then
  post_params="${post_params}&structure_or_data_forced=0"
  post_params="${post_params}&template_id="
fi

post_params="${post_params}&sql_auto_increment=something"
post_params="${post_params}&sql_backquotes=something"
post_params="${post_params}&sql_type=INSERT"
post_params="${post_params}&sql_insert_syntax=both"
post_params="${post_params}&sql_max_query_size=50000"
if [ $IS_PMA_4 -eq 1 ]; then
  post_params="${post_params}&sql_hex_for_binary=something"
else
  post_params="${post_params}&sql_hex_for_blob=something"
fi
post_params="${post_params}&sql_utc_time=something"
post_params="${post_params}&texytext_structure_or_data=structure_and_data"
post_params="${post_params}&texytext_null=NULL"
post_params="${post_params}&yaml_structure_or_data=data"

if [ $ADD_DROP -eq 1 ];  then
    post_params="${post_params}&sql_drop_table=something"
fi    

target="$(echo "$REMOTE_HOST" | sed 's@^http[s]://@@;s@/.*@@')_${DATABASE}_$(date  +%Y%m%d%H%M).sql"
#target="$(echo $REMOTE_HOST | sed 's@^http[s]://@@;s@/.*@@')_${DATABASE}.sql"

post_params="${post_params}&compression=$COMPRESSION"
case $COMPRESSION in 
    gzip)
  target="${target}.gz" ;;
    bzip2)
  target="${target}.bz2" ;;
    zip)
  target="${target}.zip" ;;
    none)
  ;;
    *)
  target="${target}err.compression" ;;
esac

decho Database: $DATABASE
if [  -n "$DB_TABLES" ] ; then
  DB_TABLES=${DB_TABLES/=/table_select%5B%5D=} # to be converted to POSIX strict shell
  DB_TABLES=${DB_TABLES//,/&table_select%5B%5D=}  # to be converted to POSIX strict shell
  DB_TABLES=${DB_TABLES:8}  # to be converted to POSIX strict shell
  decho Tables: $DB_TABLES

  post_params="${post_params}&db=$DATABASE"
  post_params="${post_params}&export_type=database"
  post_params="${post_params}&$DB_TABLES"
  post_params="${post_params}&"
  post_params+=$(echo "$DB_TABLES" | sed -e 's/table_select/table_structure/g')
  post_params="${post_params}&"
  post_params+=$(echo "$DB_TABLES" | sed -e 's/table_select/table_data/g')

  post_params="${post_params}&filename_template=%40DATABASE%40"

  post_params="${post_params}&xml_structure_or_data=data"
  post_params="${post_params}&xml_export_functions=something"
  if [ $IS_PMA_4 -eq 1 ]; then
    post_params="${post_params}&xml_export_events=something"
  fi
  post_params="${post_params}&xml_export_procedures=something"
  post_params="${post_params}&xml_export_tables=something"
  post_params="${post_params}&xml_export_triggers=something"
  post_params="${post_params}&xml_export_views=something"
  post_params="${post_params}&xml_export_contents=something"
else
  post_params="${post_params}&export_type=server"
  post_params="${post_params}&db_select%5B%5D=$DATABASE"
  post_params="${post_params}&filename_template=%40SERVER%40"
fi

## the important curl command, either output to stdout additionally
if [ -n "$STDOUT" ] ; then
  curl $curlopts -g -S -D "$TMP_FOLDER/curl.headers" -b "$TMP_FOLDER/cookies.txt" -c "$TMP_FOLDER/cookies.txt" $apache_auth_params -d "$post_params" "$REMOTE_HOST/$export_script"
else
decho " Exportcommand: curl $opts"
  curl $curlopts -g -S -O -D "$TMP_FOLDER/curl.headers" -b "$TMP_FOLDER/cookies.txt" -c "$TMP_FOLDER/cookies.txt" $apache_auth_params -d "$post_params" "$REMOTE_HOST/$export_script"

        ##  check if there was an attachement
  grep -q "Content-Disposition: attachment" "$TMP_FOLDER/curl.headers"
  if [ $? -eq 0 ] ; then
      mv "$export_script" "$target"
      echo "Saved: $target"
  else
      echo "Error: No attachment. Something went wrong. See $export_script"
      exit 1
  fi
fi

# remove the old backups and keep the 10 younger ones.
#ls -1 backup_mysql_*${database}_*.gz | sort -u | head -n-10 | xargs -r rm -v
rm -f "$result"
rm -f "$TMP_FOLDER/curl.headers"
rm -f "$TMP_FOLDER/cookies.txt"
