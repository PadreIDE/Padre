/** 
*========================================================================<br/>
* A package for handling partner related activities like
* (adding a new partner, updating partner data, removing a
* partner)
* PLDOC Style
*/
CREATE OR REPLACE PACKAGE flyingfish
IS


    /** Checking the partner record whether it exists or not.
    *  @param id The ID of the partner we want to check
    *  @return 1 if the partner exists, -1 if it doesn't.
    * @foo  
    */
    FUNCTION check_partner(
        id IN VARCHAR2
    ) RETURN NUMBER;


END;
/



/* comment - multiline
   more comment
   and again.
*/

-- sqlplus-isms?
&myvar1=first value
&myvar2=second value
WHENEVER OSERROR SHUTDOWN;

-- double dashed comment

-- DML

SELECT * FROM mytable WHERE this = :that;

SELECT abs(this),HexToRaw('dead') FROM mytable WHERE this = ?;

INSERT INTO mytable(that,that) VALUES ( NULL, 10 );

UPDATE mytable SET this = :that;
/** PLDOC comments 
   @thing
*/
REPLACE INTO mytable VALUES (10,"eleven",'singlequoted');

MERGE INTO mytable USING newdata
    ON mytable.foo = newdata.foo
    WHEN MATCHED THEN
        UPDATE SET bar = newdata.bar
    WHEN NOT MATCHED THEN
        INSERT newdata
    ;

-- DDL

CREATE OR REPLACE TRIGGER xyz_trg BEFORE INSERT ON mytable;

CREATE TABLE mytable (
    this        INTEGER,
    that        VARCHAR2(255),
    more        VARCHAR(2),
    other       BLOB,
);

BEGIN

COMMIT

END;
