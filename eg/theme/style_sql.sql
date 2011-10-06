/* comment - multiline
   more comment
   and again.
*/

-- double dashed comment

-- DML

SELECT * FROM mytable WHERE this = :that;

SELECT abs(this) FROM mytable WHERE this = ?;

INSERT INTO mytable(that,that) VALUES ( NULL, 10 );

UPDATE mytable SET this = :that;

REPLACE INTO mytable VALUES (10,"eleven",'singlequoted');

-- DDL

CREATE OR REPLACE TRIGGER xyz_trg BEFORE INSERT ON mytable;

CREATE TABLE mytable (
    this        INTEGER,
    that        VARCHAR(255),
    other       BLOB,
);

BEGIN

COMMIT

END;
