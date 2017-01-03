CREATE TABLE `allowed` (
	`id`		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT CHECK(`id` >= 1),
	`enabled`	BOOLEAN NOT NULL DEFAULT 0 CHECK (`enabled` IN (0,1)),
	`address1`	INTEGER NOT NULL DEFAULT 0 CHECK(`address1` <= 255 AND `address1` >= 0),
	`address2`	INTEGER NOT NULL DEFAULT 0 CHECK(`address2` <= 255 AND `address2` >= 0),
	`address3`	INTEGER NOT NULL DEFAULT 0 CHECK(`address3` <= 255 AND `address3` >= 0),
	`address4`	INTEGER NOT NULL DEFAULT 0 CHECK(`address4` <= 255 AND `address4` >= 0)
);

INSERT INTO `allowed`(`enabled`,`address1`,`address2`,`address3`,`address4`) VALUES (1,127,0,0,1);	--default loopback interface