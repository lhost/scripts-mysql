# scripts-mysql

## create-history-table.pl
This script helps you to create MySQL triggers, which store changed records from one DB table into another \*\_history table. Inserted, changed and deleted records are archived.

I have used this script to create archive for my DNS records. [PowerDNS]() use MySQL as storage backend for DNS records. Basic schema is [here](https://github.com/PowerDNS/pdns/blob/master/modules/gmysqlbackend/schema.mysql.sql).

Example:
```bash
# for PowerDNS
create-history-table.pl --database pdns --table domains | mysql pdns
create-history-table.pl --database pdns --table records | mysql pdns
create-history-table.pl --database pdns --table supermasters | mysql pdns
create-history-table.pl --database pdns --table comments | mysql pdns
create-history-table.pl --database pdns --table domainmetadata | mysql pdns
create-history-table.pl --database pdns --table cryptokeys | mysql pdns
create-history-table.pl --database pdns --table tsigkeys | mysql pdns


# for poweradmin
create-history-table.pl --database pdns --table migrations | mysql pdns
create-history-table.pl --database pdns --table perm_items | mysql pdns
create-history-table.pl --database pdns --table perm_templ | mysql pdns
create-history-table.pl --database pdns --table perm_templ_items | mysql pdns
create-history-table.pl --database pdns --table records_zone_templ | mysql pdns
create-history-table.pl --database pdns --table users | mysql pdns
create-history-table.pl --database pdns --table zones | mysql pdns
create-history-table.pl --database pdns --table zone_templ | mysql pdns
create-history-table.pl --database pdns --table zone_templ_records | mysql pdns
```

Using this sript 16 \*\_history tables and 48 triggers has been created. Example:

```sql
create-history-table.pl --database pdns --table records                  
CREATE TABLE IF NOT EXISTS `records_history` SELECT * FROM `records` WHERE 0;
ALTER TABLE `records_history` ENGINE=InnoDB;
ALTER TABLE `records_history` ADD COLUMN `action` ENUM('UPDATE','INSERT','DELETE') FIRST;
ALTER TABLE `records_history` ADD COLUMN `user` VARCHAR(255) FIRST;
ALTER TABLE `records_history` ADD COLUMN `mdate` TIMESTAMP FIRST;
ALTER TABLE `records_history` ADD INDEX (`mdate`);
ALTER TABLE `records_history` ADD INDEX (`user`);
ALTER TABLE `records_history` ADD INDEX (`action`);
ALTER TABLE `records_history` ADD INDEX (`domain_id`);
ALTER TABLE `records_history` ADD INDEX (`name`);
DROP TRIGGER IF EXISTS `update_records`;
DELIMITER ;;
CREATE DEFINER = CURRENT_USER TRIGGER `update_records` BEFORE UPDATE ON `records`
                FOR EACH ROW BEGIN
                        IF OLD.`id` <> NEW.`id`
                                OR OLD.`domain_id` <> NEW.`domain_id`
                                OR OLD.`name` <> NEW.`name`
                                OR OLD.`type` <> NEW.`type`
                                OR OLD.`content` <> NEW.`content`
                                OR OLD.`ttl` <> NEW.`ttl`
                                OR OLD.`prio` <> NEW.`prio`
                                OR OLD.`change_date` <> NEW.`change_date`
                                OR OLD.`disabled` <> NEW.`disabled`
                                OR OLD.`ordername` <> NEW.`ordername`
                                OR OLD.`auth` <> NEW.`auth`
                        THEN INSERT INTO `records_history` SET
                        `user` = USER(),
                        `action` = 'UPDATE',
        `id` = OLD.`id`,
`domain_id` = OLD.`domain_id`,
`name` = OLD.`name`,
`type` = OLD.`type`,
`content` = OLD.`content`,
`ttl` = OLD.`ttl`,
`prio` = OLD.`prio`,
`change_date` = OLD.`change_date`,
`disabled` = OLD.`disabled`,
`ordername` = OLD.`ordername`,
`auth` = OLD.`auth`; END IF;
        END;
;;
DELIMITER ;

DROP TRIGGER IF EXISTS `delete_records`;
DELIMITER ;;
CREATE DEFINER = CURRENT_USER TRIGGER `delete_records` BEFORE DELETE ON `records`
                FOR EACH ROW BEGIN
                        INSERT INTO `records_history` SET
                        `user` = USER(),
                        `action` = 'DELETE',
        `id` = OLD.`id`,
`domain_id` = OLD.`domain_id`,
`name` = OLD.`name`,
`type` = OLD.`type`,
`content` = OLD.`content`,
`ttl` = OLD.`ttl`,
`prio` = OLD.`prio`,
`change_date` = OLD.`change_date`,
`disabled` = OLD.`disabled`,
`ordername` = OLD.`ordername`,
`auth` = OLD.`auth`;
        END;
;;
DELIMITER ;

DROP TRIGGER IF EXISTS `insert_records`;
DELIMITER ;;
CREATE DEFINER = CURRENT_USER TRIGGER `insert_records` AFTER INSERT ON `records`
                FOR EACH ROW BEGIN
                        INSERT INTO `records_history` SET
                        `user` = USER(),
                        `action` = 'INSERT',
        `id` = NEW.`id`,
`domain_id` = NEW.`domain_id`,
`name` = NEW.`name`,
`type` = NEW.`type`,
`content` = NEW.`content`,
`ttl` = NEW.`ttl`,
`prio` = NEW.`prio`,
`change_date` = NEW.`change_date`,
`disabled` = NEW.`disabled`,
`ordername` = NEW.`ordername`,
`auth` = NEW.`auth`;
        END;
;;
DELIMITER ;

```
