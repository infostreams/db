# Introduction 

With DB you can very easily save, restore, and archive snapshots of your database from the command line. It 
supports connecting to different database servers (for example a local development server and a staging or 
production server) and allows you to load a database dump from one environment into another environment. 

> For now, this is for MySQL only, but it could be extended to be used with other database systems as well.

## Table of Contents
- [Introduction](#introduction)
- [Examples](#examples)
- [Installation](#installation)
  * [Additional configuration / different port or socket](#additional-configuration--different-port-or-socket)
- [Available commands](#available-commands)
  * [db init](#db-init)
  * [db save](#db-save)
  * [db load](#db-load)
  * [db remove](#db-remove)
  * [db server](#db-server)
    + [db server add](#db-server-add)
    + [db server remove](#db-server-remove)
    + [db server list](#db-server-list)
  * [db export](#db-export)
  * [db import](#db-import)
  * [db nuke](#db-nuke)
  * [db log](#db-log)
  * [db show](#db-show)
  * [db structure](#db-structure)
  * [db change](#db-change)
    + [db change charset](#db-change-charset)
    + [db change wordpress](#db-change-wordpress)
  * [db test](#db-test)

## Examples 

```shell 
$ db save localhost "snapshot before running migrations" 

> [localhost] 
> Successfully made snapshot of database - hash f4f0c1d3fac74166c12a3708cdaa5d804dcd4b970c6e2789ccb23303 
``` 

This will save a copy of your database to the repository. 

> By default, this repository lives in the ```.db``` folder in your project root. In this repository are gzipped database 
> dumps. Whether or not you want to commit the contents of that folder to ```git``` or another VCS is up to you. If you
> do, make sure to exclude your database credentials by adding something like ```.db/*/config/credentials.cnf``` 
> (untested!) to your ```.gitignore```.

Imagine the following scenario: after creating the local snapshot, you run a database migration. However, the migration
breaks your database and deletes some stuff that you didn't want to delete. Usually, if you run a migration, there is 
also a way to undo that migration - but alas, that won't return your deleted data. No problem. To restore your database 
to the state it was in before you started the migration, simply run: 

```shell 
$ db load localhost f4f0c1d3fac74166c12a3708cdaa5d804dcd4b970c6e2789ccb23303 

> [localhost] Loaded snapshot f4f0c1d3fac74166c12a3708cdaa5d804dcd4b970c6e2789ccb23303 
``` 

This will load the snapshot you made before you ran the migration. It's like the migration never happened. 

There are many other things ```db``` can do, for example pulling down a database from the staging environment to 
your localhost: 

```shell 
$ db save staging "Snapshot intended for development" 

> [staging] 
> Successfully made snapshot of database - hash 1577b2173c672eb824d5b43e989f15448f2bfca43b5b1144e6977479 

$ db load localhost 1577b2173c672eb824d5b43e989f15448f2bfca43b5b1144e6977479 

> [localhost] Loaded snapshot 1577b2173c672eb824d5b43e989f15448f2bfca43b5b1144e6977479 

``` 

Here you first make a snapshot of the database on the **staging** server, which you then load into your **localhost** 
database. This works most reliably if your staging and your development server are on the same database version.

See the full [list of available commands](#available-commands) to get a complete overview of ```db```'s capabilities. 

## Installation 

### MacOS
On MacOS, you can install ```db``` with the [HomeBrew package manager](https://brew.sh/):

```shell
$ brew install db-vcs
```

### Linux / others
On other operating systems, you can install ```db``` by cloning the repository:

```shell
$ git clone https://www.github.com/infostreams/db
```

and then creating a symlink to the main ```db``` script from a directory that is in your path, e.g.:

```shell
$ cd db/ # change to the directory you cloned the github repository in
$ ln -s db /usr/local/bin/ # create the symlink
```

You can see if it works by running

```shell
$ db
```

If all is well you should see the following friendly error message:

```shell
fatal: Not a db repository (or any of the parent directories). Please run 'db init'.
```

So, to really get started, go to a directory where you have a project that uses a database, and type 
[```db init```](#db-init). This will start the process of setting up your database connection details, after which 
the following commands will be available to you.

### Additional configuration / different port or socket

You can provide additional configuration for the MySQL connection by providing them in 
[the options file](https://dev.mysql.com/doc/refman/5.7/en/option-files.html) that can be found at 
```.db/<alias>/config/credentials.cnf```. Here you can provide a different port number or you can specify a socket
to connect through, for example

```ini
[client]
user = root
password =
host = 127.0.0.1
port = 3307
```

to connect to a MySQL database on a port 3307 instead of the standard 3306, or

```ini
[client]
user = root
password =
socket = /var/run/mysqld/mysql.sock
```

to connect to MySQL through a socket file located at ```/var/run/mysqld/mysql.sock```.

## Available commands 

```db``` has commands to import external SQL files into your database ([```db import```](#db-import)), to export a 
dump from the repository to a file ([```db export```](#db-export)), to make minor changes to your database (such as 
changing the encoding, with [```db change```](#db-change)), to clean out your database entirely ([```db nuke```](#db-nuke)), 
or to show the table structure of a particular dump ([```db structure```](#db-structure)). Very high on the wish 
list is a way to display a "diff" between two dumps, but that's not so easy and hasn't been implemented yet. 

### Full list 

The full list of available commands is as follows 

* [init](#db-init) 
* [save](#db-save) 
* [load](#db-load) 
* [remove](#db-remove) 
* [server](#db-server) 
* [export](#db-export) 
* [import](#db-import) 
* [log](#db-log) 
* [nuke](#db-nuke) 
* [show](#db-show) 
* [structure](#db-structure) 
* [change](#db-change) 
* [test](#db-test) 

### db init 

Creates a new DB repository in the current directory. Starts an interactive session that allows you to specify the 
connection details. 

#### Syntax 
```shell 
$ db init <database-type> 
``` 

If no database-type is provided, you will be asked to specify it in the interactive session. At the moment, only mysql 
is supported. The extension points for other database systems are already in place and could (theoretically) be added
relatively easily. 

Below you see an example of the questions you might be asked. 

```shell 
$ db init 


> Please provide the database type for this repository 
> Supported types: mysql 
> 
> Database type [mysql]: 
> 
> Please provide the connection details for the database 
> Server alias []: 
> Connection type, e.g. direct, or ssh []: 
> SSH login, e.g. user@hostname.com []: 
> Please provide the database host. For connection types SSH and direct, this is probably 127.0.0.1. 
> Database host [127.0.0.1]: 
> Username [root]: 
> Password []: 
> Database []: 
> 
> Successfully connected to database. Writing config. 
``` 

The password for your connection will be stored in plain text, in a file that only the current user has read-access to 
(file mode 0600). Make sure to not commit this file (```.db/<server alias>/config/credentials.cnf```) to source control!

If you want to add a remote server, you need to have ssh access to it. It is best if you have setup passwordless access,
otherwise it will ask you for your password every time you interact with the remote server. 

### db save 

Saves a snapshot of the database to the repository. 

#### Syntax 

```shell 
$ db save [server alias] [commit message] 
``` 

If you omit the **server alias** it will default to using the oldest server alias, in my case almost always **localhost**. 

Example 

```shell 
$ db save localhost "Hello database" 

> [localhost] 
> Successfully made snapshot of database - hash e82a736789b421e7efd0ee2071bff33945a5fab6be08be6821a3f576 
``` 

If you try to make a snapshot of a database that didn't change, it will not save a new snapshot. 


### db load 

Loads a snapshot from the repository into the database. 

CAVEAT: Any tables that are **not** in the snapshot you are restoring are left untouched. *It only replaces the tables 
that are in the snapshot.* If you want to completely empty your database first, have a look at [db nuke](#db-nuke). 

#### Syntax 

```shell 
$ db load [server alias] [snapshot] [--match MATCH] <table_1> <table_2> <...> <table_n>
```
 
If you omit the **server alias** it will default to using the oldest server alias, in my case almost always **localhost**.

For ```[snapshot]``` you can either provide the full hash (e.g. ```e82a736789b421e7efd0ee2071bff33945a5fab6be08be6821a3f576```)
or you can provide just enough characters to uniquely identify a given dump (e.g. ```e82a736789b4```) 

You can choose to only load one or more specific tables from this snapshot. For example, the following command will only 
restore the ```wp_users``` table to localhost:

```shell
$ db load localhost e82a736789b421e7efd0ee2071bff33945a5fab6be08be6821a3f576 wp_users
```

You can provide more than one table to restore. If you don't provide any tables, it will load all the tables that
are defined in the snapshot.

You can also provide a regular expression to match the table name to restore. For example, to only restore tables
whose name matches the regular expression ```wp_13_.*```, you can run the following command:

```shell
$ db load localhost e82a736789b421e7efd0ee2071bff33945a5fab6be08be6821a3f576 --match "wp_13_.*"
```

### db remove

Removes a snapshot from the repository

#### Syntax

```shell
$ db remove [server alias] [snapshot] 
```

#### Alternative syntax

Instead of typing out ```db remove```, you can also use an abbreviated version, ```db rm```:

```shell
$ db rm [server alias] [snapshot] 
```

### db server


#### db server add

Adds a new database server

##### Syntax


```shell 
$ db server add 
```

Example 

```shell 
$ db server add 


> Please provide the connection details for the database 
> 
> Server alias []: production 
> Connection type, e.g. direct, or ssh []: ssh 
> SSH login, e.g. user@hostname.com []: account@server.com
> Please provide the database host. For connection types SSH and direct, this is probably 127.0.0.1. 
> Database host [127.0.0.1]: 127.0.0.1 
> Username [root]: user 
> Password []: password
> Database []: database
> 
> Successfully connected to database. Writing config. 
``` 

This would have added a new server with the alias **production**, which you can then use to save and load snapshots. 

If you want to add a remote server, you need to have ssh access to it. It is best if you have setup passwordless access,
otherwise it will ask you for your password every time you interact with the remote server. 


#### db server remove

Removes a database server alias and all the snapshots. Does not do affect the actual database server itself.

##### Syntax

```
$ db server remove [server alias]
```

#### db server list

Shows a list of which servers are available

##### Syntax

```shell 
$ db server list 

> localhost 
> staging 
``` 

### db export

Copies a database snapshot from the repository to a local file

#### Syntax

```shell
$ db export [server alias] [snapshot] <path to output .sql file>
```

Example

```shell
$ db export project a604f1d9063e9100fef408119287d8b604542434ea79214713088bc3  ~/Desktop/latest-dump.sql
```

### db import

Tries to load an external database dump into the database. Will not empty out the database first (!) - if you want that,
make sure to run [```db nuke```](#db-nuke) first.

You can import gzip compressed database dumps, as long as the file extension is **.gz**.

#### Syntax

```shell
$ db import [server alias] [<path to .sql or .sql.gz file> | <hash>]
```

Example

```shell
$ db import localhost ~/Desktop/some-dump-from-a-colleague-or-customer.sql
```

### db nuke 

*Deletes all tables in your database* (!!)

#### Syntax 

```shell 
$ db nuke [server alias]
```
 
This will delete all the tables in your database. If you omit the **server alias** it will default to using the oldest 
server alias, in my case almost always **localhost**.

Use with care (obviously).

### db log

Show a list of snapshots in the repository. By default, it will list all snapshots for all servers.


#### Syntax

```shell
$ db log [server alias | all]
```

Example

```shell
$ db log
```

This will list all snapshots in the repository.

```shell
$ db log localhost
```

This will only list the snapshots for the _localhost_ database.

### db show

Displays the contents of a snapshot. Basically echos the contents of the database dump to STDOUT.

#### Syntax

```shell
$ db show [snapshot]
```

You don't need to provide the server alias here, since snapshots have unique names.

Example

```shell
$ db show e9d5240e077b0f180d594d59aac468b4fc844d984eaf6e76363e1c14 | less
```

Displays the contents of the given database dump, and pipes it through ```less``` so you can inspect it.


### db structure

Displays the table structure of a given snapshot: shows all the **CREATE TABLE** statements in the snapshot.
Useful for debugging or inspecting the database.

#### Syntax

```shell
$ db structure [snapshot]
```

You don't need to provide the server alias here, since snapshots have unique names.

Example

```shell
$ db structure c6d7451de16a8ddd0ec240a6d8f7cc376544583433f74bcf9960c6ab | less
```

Displays the table definitions in the provided snapshot, and pipes it through ```less``` for inspection.

### db change

Allows you to make changes to a database. Does not operate on a snapshot but on the actual database itself.

#### db change charset

Changes the character set and collation of the database and its tables.

##### Syntax

```shell
$ db change charset [server alias] [new characterset] [new collation]
```

Example

```shell
$ db change charset localhost utf8mb4 utf8mb4_unicode_ci
```

#### db change wordpress

Runs a naive search and replace on the database to make changes to allow WordPress to run on a different domain name.
Only use this if you cannot use [WP-CLI](https://wp-cli.org/) for some reason.

##### Syntax

```shell
$ db change wordpress [server alias] [new url]
```

Example

```shell
$ db change wordpress localhost "http://www.my-new-domain.com/"
```

### db test

Tries to connect to a given database server. Known to sometimes give false positives.

### Syntax

```shell
$ db test [server alias]
```

Example

```shell
$ db test staging 
```

Tries to connect to the **staging** server.
