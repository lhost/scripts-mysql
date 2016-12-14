#!/usr/bin/perl -w

#
# create-history-table.pl -
#
# Developed by Lubomir Host 'rajo' <rajo AT platon.sk>
# Copyright (c) 2009 Platon Technologies Ltd, http://platon.sk
# All rights reserved.
#
# Changelog:
# 2009-02-23 - created
#

# $Id: create-history-table.pl 13346 2010-10-08 21:14:35Z rajo $
# $HeadURL: svn+ssh://svn@svn.platon.sk/home/svn/webhosting/trunk/scripts/mysql/create-history-table.pl $

use Env;
use DBI;
use Data::Dumper;
use Getopt::Long;

use strict;

use vars qw (
	$conf
	$opt_conf_file
	$hostname
	$port
	$socket
	$database
	$user
	$password
	@tables
	$suffix
	@columns_ignore_change %ignore_cols
);

my $rv = GetOptions(
	'configfile|config|conf|c=s'	=> \$opt_conf_file,
	'hostname|host|h=s'	=> \$hostname,
	'port=s'			=> \$port,
	'socket|s=s'		=> \$socket,
	'database|d=s'		=> \$database,
	'user|u=s'			=> \$user,
	'password|p=s'		=> \$password,
	'table|t=s'			=> \@tables,
	'suffix=s'			=> \$suffix,
	'columns-ignore-change=s'	=> \@columns_ignore_change
);

# default values
$port 	||= 3306;
$suffix	||=	'_history';
$opt_conf_file ||= "$ENV{HOME}/.my.cnf";

if (defined($opt_conf_file) and -f $opt_conf_file) {
	open (CONF, "<$opt_conf_file") or die "Can't read MySQL config file '$opt_conf_file': $!";
	while (my $line = <CONF>) {
		if ($line =~ m/(host|port|user|password|socket)\s*=\s*(.*)\s*$/) {
			$conf->{$1} = $2;
		}
	}
	close(CONF);
}

$hostname	||= $conf->{hostname};
$port		||= $conf->{port};
$socket		||= $conf->{socket};
$user		||= $conf->{user};
$password	||= $conf->{password};

foreach (@columns_ignore_change) {
	$ignore_cols{$_} = 1;
}

my $dbh = DBI->connect(
	"dbi:mysql:database=$database" .
	(defined($hostname) ? ";host=$hostname" : '') .
	(defined($port) ? ";port=$port" : '') .
	(defined($socket) ? ";socket=$socket" : ''),
	$user, $password,
	{ RaiseError => 1, AutoCommit => 1 }
) or die $DBI::errstr;

if (scalar(@tables) == 0) {
	print STDERR "No tables specified.\n";
	exit 1;
}

foreach my $t (@tables) {
	my $t_struct = $dbh->selectall_arrayref("/* t_struct " . __FILE__ .':'. __LINE__ . " */
		SELECT * FROM information_schema.COLUMNS
		WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?
		ORDER BY ORDINAL_POSITION
		", { Slice => {} },
		$database, $t
	);
	#print Dumper($t_struct);
	#print "DROP TABLE IF EXISTS `$t$suffix`;\n";
	print "CREATE TABLE IF NOT EXISTS `$t$suffix` SELECT * FROM `$t` WHERE 0;\n";
	my $alt = "ALTER TABLE `$t$suffix`";
	print "$alt ENGINE=InnoDB;\n";
	
	foreach my $st (@$t_struct) {
	}

	# add columns
	print "$alt ADD COLUMN `action` ENUM('UPDATE','INSERT','DELETE') FIRST;\n";
	print "$alt ADD COLUMN `user` VARCHAR(255) FIRST;\n";
	print "$alt ADD COLUMN `mdate` TIMESTAMP FIRST;\n";

	# add indexes
	print "$alt ADD INDEX (`mdate`);\n";
	print "$alt ADD INDEX (`user`);\n";
	print "$alt ADD INDEX (`action`);\n";
	foreach my $idx (@$t_struct) {
		# ignore primary and unique keys
		print "$alt ADD INDEX (`$idx->{COLUMN_NAME}`);\n" if ($idx->{COLUMN_KEY} eq 'MUL');
	}

	# UPDATE trigger
	print "DROP TRIGGER IF EXISTS `update_$t`;\n";
	print "DELIMITER ;;\n";
	print "CREATE DEFINER = CURRENT_USER TRIGGER `update_$t` BEFORE UPDATE ON `$t`
		FOR EACH ROW BEGIN
			IF "
			. join("\n\t\t\t\tOR ", map { my $k = $_; "OLD.`$k` <> NEW.`$k`"; } grep { !exists($ignore_cols{$_}) } map { $_->{COLUMN_NAME} } @$t_struct)
			. "
			THEN INSERT INTO `$t$suffix` SET
			`user` = USER(),
			`action` = 'UPDATE',
	";
	print join(", \n", map { my $k = $_->{COLUMN_NAME}; "`$k` = OLD.`$k`"; } @$t_struct);
	print "; END IF;\n	END;\n";
	print ";;\n";
	print "DELIMITER ;\n";

	# DELETE trigger
	print "DROP TRIGGER IF EXISTS `delete_$t`;\n";
	print "DELIMITER ;;\n";
	print "CREATE DEFINER = CURRENT_USER TRIGGER `delete_$t` BEFORE DELETE ON `$t`
		FOR EACH ROW BEGIN
			INSERT INTO `$t$suffix` SET
			`user` = USER(),
			`action` = 'DELETE',
	";
	print join(", \n", map { my $k = $_->{COLUMN_NAME}; "`$k` = OLD.`$k`"; } @$t_struct);
	print ";\n	END;\n";
	print ";;\n";
	print "DELIMITER ;\n";

	# INSERT trigger
	print "DROP TRIGGER IF EXISTS `insert_$t`;\n";
	print "DELIMITER ;;\n";
	print "CREATE DEFINER = CURRENT_USER TRIGGER `insert_$t` AFTER INSERT ON `$t`
		FOR EACH ROW BEGIN
			INSERT INTO `$t$suffix` SET
			`user` = USER(),
			`action` = 'INSERT',
	";
	print join(", \n", map { my $k = $_->{COLUMN_NAME}; "`$k` = NEW.`$k`"; } @$t_struct);
	print ";\n	END;\n";
	print ";;\n";
	print "DELIMITER ;\n";

}

$dbh->disconnect();

